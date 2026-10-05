import Foundation

struct LevelRecord: Codable {
    var moves: Int
    var pushes: Int
}
struct SavedGame: Codable {
    var version = 1
    var packID: String
    var levelIndex: Int
    var character: Int
    var theme: String
    var sound: Bool
    var volume: Double
    var completed: [String: LevelRecord]
    var session: BoardSession
    var furthestLevel: Int? = nil
}

/// Atomic file replacement keeps the last complete save if the process exits during a write.
struct GameStore {
    let url: URL
    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PenguinPush", isDirectory: true).appendingPathComponent("session-v1.json")
    }
    func read() -> SavedGame? {
        guard let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode(SavedGame.self, from: data),
              saved.version == 1 else { return nil }
        return saved
    }
    func archivePreviousCampaign() throws {
        let backup = url.deletingLastPathComponent().appendingPathComponent("session-before-adventure.json")
        if !FileManager.default.fileExists(atPath: backup.path), FileManager.default.fileExists(atPath: url.path) {
            try Data(contentsOf: url).write(to: backup, options: .atomic)
        }
    }
    func write(_ saved: SavedGame) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(saved).write(to: url, options: .atomic)
    }
}
