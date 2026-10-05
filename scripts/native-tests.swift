import Foundation
import SQLite3

struct TestStep: Decodable { let undo: Bool; let direction: MoveDirection; let state: BoardSnapshot }
struct TestFixture: Decodable { let level: GameLevel; let steps: [TestStep] }

@main struct NativeTests {
    static func main() throws {
        let fixtures = try JSONDecoder().decode([TestFixture].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        var steps = 0
        for fixture in fixtures {
            var board = try SokobanBoard(level: fixture.level)
            for step in fixture.steps {
                if step.undo { board.undo() } else { _ = board.move(step.direction) }
                precondition(board.state == step.state, "Rule mismatch in \(fixture.level.id) after \(steps) steps")
                steps += 1
            }
            let data = try JSONEncoder().encode(board.session)
            let session = try JSONDecoder().decode(BoardSession.self, from: data)
            var restored = try SokobanBoard(level: fixture.level)
            precondition(restored.restore(session), "Cannot restore \(fixture.level.id)")
            precondition(restored.state == board.state && restored.history == board.history, "Restore changed state or undo history")
            while board.undo() { precondition(restored.undo() && restored.state == board.state, "Undo after reload differs") }
        }
        let level = GameLevel(id: "test", name: "test", author: "PenguinPush", map: ["#####", "#@$.#", "#####"])
        var game = try SokobanBoard(level: level)
        precondition(game.move(.right)?.won == true && game.state.moves == 1 && game.state.pushes == 1)
        precondition(game.move(.left) == nil, "A finished board must not accept movement")
        var bad = game.state; bad.player = GridPoint(x: 999, y: 999)
        var initial = try SokobanBoard(level: level)
        precondition(!initial.restore(BoardSession(levelID: level.id, state: bad, history: game.history)))
        precondition(!initial.restore(BoardSession(levelID: "wrong-level", state: game.state, history: game.history)))
        do { _ = try SokobanBoard(level: GameLevel(id: "bad", name: "bad", author: "test", map: ["@$."])); fatalError("Accepted unenclosed map") }
        catch BoardError.invalidLevel { }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = GameStore(url: dir.appendingPathComponent("save.json"))
        precondition(store.read() == nil)
        let saved = SavedGame(packID: "test", levelIndex: 0, character: 1, theme: "night", sound: true, volume: 0.2,
                              completed: [level.id: LevelRecord(moves: 1, pushes: 1)], session: game.session)
        try store.write(saved)
        let reloaded = GameStore(url: store.url).read()!
        precondition(initial.restore(reloaded.session) && initial.won)
        precondition(reloaded.character == 1 && reloaded.theme == "night" && reloaded.completed[level.id]?.moves == 1)
        precondition(initial.undo() && !initial.won)
        func legacyState(_ state: BoardSnapshot) -> [String: Any] {
            ["player": [state.player.x, state.player.y], "boxes": state.boxes.map { "\($0.x),\($0.y)" },
             "moves": state.moves, "pushes": state.pushes, "direction": state.direction.rawValue]
        }
        var legacySession = legacyState(game.state)
        legacySession["level"] = level.id; legacySession["history"] = game.history.map(legacyState)
        let legacy: [String: Any] = ["pack": "test", "index": 0, "character": 1, "theme": "night",
                                    "completed": [level.id: ["moves": 1, "pushes": 1]], "session": legacySession]
        let legacyData = try JSONSerialization.data(withJSONObject: legacy)
        let testPack = LevelPack(id: "test", name: "test", author: "test", levels: [level])
        let converted = LegacySaveMigration.convert(legacyData, packs: [testPack])!
        precondition(converted.session.state == game.state && converted.session.history == game.history)
        let databaseURL = dir.appendingPathComponent("WebKit/WebsiteData/LocalStorage/file__0.localstorage")
        try FileManager.default.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var database: OpaquePointer?
        precondition(sqlite3_open(databaseURL.path, &database) == SQLITE_OK)
        precondition(sqlite3_exec(database, "CREATE TABLE ItemTable (key TEXT UNIQUE, value BLOB NOT NULL)", nil, nil, nil) == SQLITE_OK)
        var statement: OpaquePointer?
        precondition(sqlite3_prepare_v2(database, "INSERT INTO ItemTable VALUES ('penguinpush-v2', ?)", -1, &statement, nil) == SQLITE_OK)
        let legacyUTF16 = String(data: legacyData, encoding: .utf8)!.data(using: .utf16LittleEndian)!
        legacyUTF16.withUnsafeBytes { bytes in
            _ = sqlite3_bind_blob(statement, 1, bytes.baseAddress, Int32(bytes.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        precondition(sqlite3_step(statement) == SQLITE_DONE)
        sqlite3_finalize(statement); sqlite3_close(database)
        let migrated = LegacySaveMigration.read(packs: [testPack], library: dir)!
        precondition(migrated.session.state == game.state && migrated.character == 1)
        print("PASS one-time import from legacy WebKit SQLite storage with UTF-16 values")
        try Data("broken".utf8).write(to: store.url)
        precondition(store.read() == nil)
        print("PASS Swift engine: \(fixtures.count) maps, \(steps) reference operations, save/reload, complete undo history, victory and corrupt-save rejection")
    }
}
