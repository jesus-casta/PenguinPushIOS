import Foundation

struct GridPoint: Codable, Hashable {
    let x: Int
    let y: Int
    func offset(_ direction: MoveDirection) -> GridPoint {
        GridPoint(x: x + direction.dx, y: y + direction.dy)
    }
}

enum MoveDirection: Int, Codable, CaseIterable {
    case down = 0, left, right, up
    var dx: Int { self == .left ? -1 : self == .right ? 1 : 0 }
    var dy: Int { self == .up ? -1 : self == .down ? 1 : 0 }
    var symbol: String { ["arrow.down", "arrow.left", "arrow.right", "arrow.up"][rawValue] }
}

struct GameLevel: Codable {
    let id: String
    let name: String
    let author: String
    let map: [String]
}
struct LevelPack: Codable {
    let id: String
    let name: String
    let author: String
    let levels: [GameLevel]
}
struct BoardSnapshot: Codable, Equatable {
    var player: GridPoint
    var boxes: Set<GridPoint>
    var moves: Int
    var pushes: Int
    var direction: MoveDirection
}
struct BoardSession: Codable {
    let levelID: String
    let state: BoardSnapshot
    let history: [BoardSnapshot]
}
struct BoardMove {
    let from: GridPoint
    let to: GridPoint
    let boxFrom: GridPoint?
    let boxTo: GridPoint?
    let direction: MoveDirection
    let delivered: Bool
    let won: Bool
}

enum BoardError: Error { case invalidLevel }

/// Pure Swift rules, independent of rendering and UIKit.
struct SokobanBoard {
    let level: GameLevel
    let width: Int
    let height: Int
    let walls: Set<GridPoint>
    let floor: Set<GridPoint>
    let goals: Set<GridPoint>
    private(set) var state: BoardSnapshot
    private(set) var history: [BoardSnapshot] = []

    init(level: GameLevel) throws {
        let rows = level.map.map(Array.init)
        guard !rows.isEmpty else { throw BoardError.invalidLevel }
        let width = rows.map(\.count).max() ?? 0, height = rows.count
        var outside: Set<GridPoint> = [GridPoint(x: -1, y: -1)]
        var queue = Array(outside), cursor = 0
        func tile(_ p: GridPoint) -> Character {
            guard p.y >= 0, p.y < height, p.x >= 0, p.x < rows[p.y].count else { return " " }
            return rows[p.y][p.x]
        }
        while cursor < queue.count {
            let p = queue[cursor]; cursor += 1
            for direction in MoveDirection.allCases {
                let next = p.offset(direction)
                if next.x >= -1, next.y >= -1, next.x <= width, next.y <= height,
                   tile(next) != "#", outside.insert(next).inserted { queue.append(next) }
            }
        }
        var walls = Set<GridPoint>(), floor = Set<GridPoint>(), goals = Set<GridPoint>(), boxes = Set<GridPoint>()
        var players: [GridPoint] = []
        for (y, row) in rows.enumerated() {
            for (x, c) in row.enumerated() {
                guard " #.$@+*".contains(c) else { throw BoardError.invalidLevel }
                let p = GridPoint(x: x, y: y)
                if c == "#" { walls.insert(p); continue }
                if outside.contains(p) {
                    guard c == " " else { throw BoardError.invalidLevel }
                    continue
                }
                floor.insert(p)
                if ".+*".contains(c) { goals.insert(p) }
                if "$*".contains(c) { boxes.insert(p) }
                if "@+".contains(c) { players.append(p) }
            }
        }
        guard players.count == 1, !boxes.isEmpty, boxes.count == goals.count else { throw BoardError.invalidLevel }
        self.level = level; self.width = width; self.height = height
        self.walls = walls; self.floor = floor; self.goals = goals
        state = BoardSnapshot(player: players[0], boxes: boxes, moves: 0, pushes: 0, direction: .down)
    }

    var won: Bool { state.boxes.isSubset(of: goals) }
    var placed: Int { state.boxes.intersection(goals).count }
    var cornerBlocked: Bool {
        state.boxes.contains { p in
            !goals.contains(p) && (!floor.contains(p.offset(.left)) || !floor.contains(p.offset(.right))) &&
            (!floor.contains(p.offset(.up)) || !floor.contains(p.offset(.down)))
        }
    }

    mutating func move(_ direction: MoveDirection) -> BoardMove? {
        guard !won else { return nil }
        let previous = state
        state.direction = direction
        let from = state.player, to = from.offset(direction), beyond = to.offset(direction)
        let pushing = state.boxes.contains(to)
        guard floor.contains(to), !pushing || (floor.contains(beyond) && !state.boxes.contains(beyond)) else { return nil }
        history.append(previous)
        state.player = to; state.moves += 1
        if pushing {
            state.boxes.remove(to); state.boxes.insert(beyond); state.pushes += 1
        }
        return BoardMove(from: from, to: to, boxFrom: pushing ? to : nil, boxTo: pushing ? beyond : nil,
                         direction: direction, delivered: pushing && goals.contains(beyond), won: won)
    }

    @discardableResult mutating func undo() -> Bool {
        guard let previous = history.popLast() else { return false }
        state = previous
        return true
    }
    var session: BoardSession { BoardSession(levelID: level.id, state: state, history: history) }

    /// Validate saved positions by replaying legal moves. Never trust decoded coordinates.
    @discardableResult mutating func restore(_ session: BoardSession) -> Bool {
        guard session.levelID == level.id, session.history.count <= 100_000,
              var candidate = try? SokobanBoard(level: level) else { return false }
        let states = session.history + [session.state]
        for (i, expected) in states.enumerated() {
            guard candidate.state.player == expected.player, candidate.state.boxes == expected.boxes,
                  candidate.state.moves == expected.moves, candidate.state.pushes == expected.pushes else { return false }
            // A blocked attempt can turn the character without adding to history.
            candidate.state.direction = expected.direction
            if i + 1 < states.count {
                let next = states[i + 1].player
                guard let direction = MoveDirection.allCases.first(where: { expected.player.offset($0) == next }),
                      candidate.move(direction) != nil else { return false }
            }
        }
        self = candidate
        return true
    }
}
