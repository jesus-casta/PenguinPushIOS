import SwiftUI
import SpriteKit

final class GameModel: ObservableObject {
    @Published private(set) var board: SokobanBoard?
    @Published private(set) var packIndex = 0
    @Published private(set) var levelIndex = 0
    @Published private(set) var furthestLevel = 0
    var unlockedLevel: Int {
        guard !packs.isEmpty else { return 0 }
        let best = packs[0].levels.indices.filter { completed[packs[0].levels[$0].id] != nil }.max().map { $0 + 1 } ?? 0
        return min(packs[0].levels.count - 1, max(furthestLevel, best))
    }
    @Published private(set) var character = 0
    @Published private(set) var theme = "ice"
    @Published private(set) var completed: [String: LevelRecord] = [:]
    @Published var sound = true { didSet { if !sound { audio.pause() }; save() } }
    @Published var volume = 0.35 { didSet { save() } }
    @Published var settingsOpen = false { didSet { stopInput(); scene.inputEnabled = !settingsOpen && !choosingCharacter && active } }
    @Published var choosingCharacter = false { didSet { stopInput(); scene.inputEnabled = !settingsOpen && !choosingCharacter && active } }
    @Published var showVictory = false
    @Published private(set) var error: String?
    @Published private(set) var saveError: String?
    let packs: [LevelPack]
    let scene = PenguinScene()
    private let store: GameStore = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("PenguinPush-UITests.json")
            if ProcessInfo.processInfo.arguments.contains("--reset-ui-testing-save") { try? FileManager.default.removeItem(at: url) }
            return GameStore(url: url)
        }
        #endif
        return GameStore()
    }()
    private let audio = NativeAudio()
    private var pending: [MoveDirection] = []
    private var walkingRoute: [MoveDirection] = []
    private var animating = false
    private var generation = 0
    @Published private(set) var active = true
    var canMove: Bool { active && error == nil && !settingsOpen && !choosingCharacter && board?.won == false }

    init() {
        do {
            guard let url = Bundle.main.url(forResource: "levels", withExtension: "json", subdirectory: "NativeGame") else { throw BoardError.invalidLevel }
            let decoded = try JSONDecoder().decode([LevelPack].self, from: Data(contentsOf: url))
            guard !decoded.isEmpty, decoded.allSatisfy({ !$0.levels.isEmpty }) else { throw BoardError.invalidLevel }
            packs = decoded
        } catch {
            packs = []
            self.error = "No se han podido cargar los niveles incluidos en la aplicación."
        }
        if !packs.isEmpty {
            let nativeSave = store.read()
            let migrated = nativeSave == nil && !ProcessInfo.processInfo.arguments.contains("--ui-testing") && !FileManager.default.fileExists(atPath: store.url.path) ? LegacySaveMigration.read(packs: packs) : nil
            if let saved = nativeSave ?? migrated {
                character = saved.character == 1 ? 1 : 0
                sound = saved.sound; volume = min(1, max(0, saved.volume))
                completed = saved.completed.filter { key, _ in packs[0].levels.contains { $0.id == key } }
                if saved.packID == packs[0].id {
                    levelIndex = min(max(saved.levelIndex, 0), packs[0].levels.count - 1)
                    furthestLevel = min(packs[0].levels.count - 1, max(levelIndex, saved.furthestLevel ?? levelIndex))
                    board = try? SokobanBoard(level: packs[0].levels[levelIndex])
                    _ = board?.restore(saved.session)
                } else {
                    try? store.archivePreviousCampaign()
                    // The adventure rooms extend the original tutorials by three rows above.
                    if saved.packID == "tutorial", let i = packs[0].levels.firstIndex(where: { $0.id == saved.session.levelID }) {
                        levelIndex = i; furthestLevel = i
                        board = try? SokobanBoard(level: packs[0].levels[i])
                        func shifted(_ s: BoardSnapshot) -> BoardSnapshot {
                            var n = s; n.player = GridPoint(x: s.player.x, y: s.player.y + 3)
                            n.boxes = Set(s.boxes.map { GridPoint(x: $0.x, y: $0.y + 3) }); return n
                        }
                        _ = board?.restore(BoardSession(levelID: saved.session.levelID, state: shifted(saved.session.state), history: saved.session.history.map(shifted)))
                    } else { board = try? SokobanBoard(level: packs[0].levels[0]) }
                }
            } else { board = try? SokobanBoard(level: packs[0].levels[0]) }
        }

        if !packs.isEmpty && board == nil { error = "No se ha podido cargar el tablero." }
        scene.model = self
        scene.scaleMode = .resizeFill
        scene.rebuild()
        showVictory = board?.won == true
        if !FileManager.default.fileExists(atPath: store.url.path) { save() }
    }

    func walk(to destination: GridPoint) {
        guard canMove, let board = board else { return }
        pending.removeAll(); walkingRoute.removeAll(); scene.clearDestination()
        guard let route = board.walkingPath(to: destination) else {
            scene.markDestination(destination, reachable: false); play(.blocked); return
        }
        guard !route.isEmpty else { return }
        walkingRoute = route; scene.markDestination(destination, reachable: true)
        if !animating { continueWalking() }
    }
    private func continueWalking() {
        guard canMove, !walkingRoute.isEmpty, let current = board else { scene.clearDestination(); return }
        let direction = walkingRoute.removeFirst(), next = current.state.player.offset(direction)
        // Recheck at execution time so an interrupted route can never push a box.
        guard current.floor.contains(next), !current.state.boxes.contains(next) else {
            walkingRoute.removeAll(); scene.clearDestination(); return
        }
        performMove(direction)
    }
    func move(_ direction: MoveDirection) {
        walkingRoute.removeAll(); scene.clearDestination()
        performMove(direction)
    }
    private func performMove(_ direction: MoveDirection) {
        guard canMove, var current = board else { return }
        if animating {
            if pending.count < 2 { pending.append(direction) }
            return
        }
        guard let event = current.move(direction) else {
            board = current; scene.face(direction); play(.blocked); save(); return
        }
        board = current
        if event.won {
            let previous = completed[current.level.id]
            completed[current.level.id] = LevelRecord(moves: min(previous?.moves ?? Int.max, current.state.moves),
                                                      pushes: min(previous?.pushes ?? Int.max, current.state.pushes))
        }
        save()
        play(event.won ? .win : event.delivered ? .goal : event.boxTo != nil ? .push : .step)
        animating = true
        let token = generation
        scene.animate(event) { [weak self] in
            guard let self = self, self.generation == token else { return }
            self.animating = false
            if event.won { self.pending.removeAll(); self.walkingRoute.removeAll(); self.scene.clearDestination(); self.showVictory = true; self.scene.celebrate() }
            else if !self.pending.isEmpty { self.performMove(self.pending.removeFirst()) }
            else { self.continueWalking() }
        }
    }
    func undo() {
        guard active, !choosingCharacter, var current = board else { return }
        stopInput()
        if current.undo() {
            board = current; showVictory = false; scene.rebuild(); play(.undo); save()
        }
    }
    func load(pack: Int? = nil, level: Int) {
        let p = pack ?? packIndex
        guard packs.indices.contains(p), packs[p].levels.indices.contains(level), level <= unlockedLevel else { return }
        stopInput(); packIndex = p; levelIndex = level; furthestLevel = max(furthestLevel, level)
        board = try? SokobanBoard(level: packs[p].levels[level])
        showVictory = false; scene.rebuild(); save()
    }
    func newGame(character: Int) {
        self.character = character == 1 ? 1 : 0
        choosingCharacter = false
        load(level: 0)
    }
    func changeTheme(_ value: String) {
        guard ["ice", "night", "wood"].contains(value) else { return }
        stopInput(); theme = value; scene.rebuild(); save()
    }
    func next() {
        if levelIndex + 1 < packs[0].levels.count { load(level: levelIndex + 1) }
        else { showVictory = false; settingsOpen = true }
    }
    func releaseInput() { pending.removeAll() }
    func stopInput() {
        let finishingVictory = animating && board?.won == true
        generation += 1; animating = false; pending.removeAll(); walkingRoute.removeAll(); scene.clearDestination(); scene.cancelAnimation()
        if finishingVictory { showVictory = true }
    }
    func setActive(_ value: Bool) {
        active = value
        stopInput(); scene.inputEnabled = value && !settingsOpen && !choosingCharacter
        if !value { audio.pause(); save() }
    }
    func save() {
        guard let board = board, packs.indices.contains(packIndex) else { return }
        do {
            try store.write(SavedGame(packID: packs[packIndex].id, levelIndex: levelIndex, character: character,
                                     theme: theme, sound: sound, volume: volume, completed: completed, session: board.session, furthestLevel: unlockedLevel))
            if saveError != nil { saveError = nil }
        } catch { saveError = "No se ha podido guardar la partida. Comprueba el espacio disponible." }
    }
    private func play(_ effect: NativeAudio.Effect) {
        if sound { audio.play(effect, volume: Float(volume)) }
    }
}
