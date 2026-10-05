import Foundation
import SQLite3

/// One-time read-only import of the old WKWebView localStorage. No web engine is loaded.
enum LegacySaveMigration {
    private struct LegacyState: Decodable {
        let player: [Int]
        let boxes: [String]
        let moves: Int
        let pushes: Int
        let direction: Int
        func native() -> BoardSnapshot? {
            guard player.count == 2, let facing = MoveDirection(rawValue: direction) else { return nil }
            var points = Set<GridPoint>()
            for box in boxes {
                let coordinates = box.split(separator: ",").compactMap { Int($0) }
                guard coordinates.count == 2, points.insert(GridPoint(x: coordinates[0], y: coordinates[1])).inserted else { return nil }
            }
            return BoardSnapshot(player: GridPoint(x: player[0], y: player[1]), boxes: points, moves: moves, pushes: pushes, direction: facing)
        }
    }
    private struct LegacySession: Decodable {
        let level: String
        let player: [Int]
        let boxes: [String]
        let moves: Int
        let pushes: Int
        let direction: Int
        let history: [LegacyState]
        func native() -> BoardSession? {
            let state = LegacyState(player: player, boxes: boxes, moves: moves, pushes: pushes, direction: direction)
            guard let current = state.native() else { return nil }
            let snapshots = history.compactMap { $0.native() }
            guard snapshots.count == history.count else { return nil }
            return BoardSession(levelID: level, state: current, history: snapshots)
        }
    }
    private struct LegacySave: Decodable {
        let pack: String?
        let index: Int?
        let character: Int?
        let theme: String?
        let sound: Bool?
        let volume: Double?
        let completed: [String: LevelRecord]?
        let session: LegacySession?
    }
    static func convert(_ data: Data, packs: [LevelPack]) -> SavedGame? {
        guard let legacy = try? JSONDecoder().decode(LegacySave.self, from: data),
              let pack = packs.first(where: { $0.id == legacy.pack }) ?? packs.first, !pack.levels.isEmpty else { return nil }
        let index = min(pack.levels.count - 1, max(0, legacy.index ?? 0))
        guard var board = try? SokobanBoard(level: pack.levels[index]) else { return nil }
        if let session = legacy.session?.native() { _ = board.restore(session) }
        return SavedGame(packID: pack.id, levelIndex: index, character: legacy.character == 1 ? 1 : 0,
                         theme: ["ice", "night", "wood"].contains(legacy.theme ?? "") ? legacy.theme! : "ice",
                         sound: legacy.sound ?? true, volume: min(1, max(0, legacy.volume ?? 0.35)),
                         completed: legacy.completed ?? [:], session: board.session)
    }
    static func read(packs: [LevelPack], library: URL? = nil) -> SavedGame? {
        let root = library ?? FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        for directory in [root.appendingPathComponent("WebKit"), root.appendingPathComponent("Caches/WebKit")] {
            guard let entries = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in entries where (url.pathExtension == "localstorage" || url.lastPathComponent == "localstorage.sqlite3") {
                if let data = localStorageValue(url), let saved = convert(data, packs: packs) { return saved }
            }
        }
        return nil
    }
    private static func localStorageValue(_ url: URL) -> Data? {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            if let database = database { sqlite3_close(database) }; return nil
        }
        defer { sqlite3_close(database) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT value FROM ItemTable WHERE key = 'penguinpush-v2' LIMIT 1", -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW, let bytes = sqlite3_column_blob(statement, 0) else { return nil }
        let count = Int(sqlite3_column_bytes(statement, 0))
        guard count > 0, count <= 32 * 1024 * 1024 else { return nil }
        let raw = Data(bytes: bytes, count: count)
        if let text = String(data: raw, encoding: .utf8), let data = text.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil { return data }
        return String(data: raw, encoding: .utf16LittleEndian)?.data(using: .utf8)
    }
}
