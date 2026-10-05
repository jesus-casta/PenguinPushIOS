import SpriteKit
import UIKit

final class PenguinScene: SKScene {
    weak var model: GameModel?
    var inputEnabled = true
    var safeInsets = UIEdgeInsets.zero
    private let boardNode = SKNode()
    private let decorations = SKNode()
    private let player = SKSpriteNode()
    private var boxNodes: [GridPoint: SKNode] = [:]
    private var textures: [[SKTexture]] = []
    private var cell: CGFloat = 64
    private var fitScale: CGFloat = 1
    private var zoom: CGFloat = 1
    private var pan = CGPoint.zero
    private var touchStart: CGPoint?
    private var touchID: UITouch?
    private var usable = CGRect.zero

    override init(size: CGSize = .zero) {
        super.init(size: size)
        backgroundColor = UIColor(red: 0.78, green: 0.9, blue: 0.94, alpha: 1)
        addChild(decorations); addChild(boardNode)
        boardNode.zPosition = 1
        if let url = Bundle.main.url(forResource: "penguins", withExtension: "png", subdirectory: "NativeGame"),
           let image = UIImage(contentsOfFile: url.path) {
            let atlas = SKTexture(image: image)
            textures = (0..<2).map { character in (0..<4).map { direction in
                let texture = SKTexture(rect: CGRect(x: CGFloat(direction) / 4, y: character == 0 ? 0.5 : 0,
                                                     width: 0.25, height: 0.5), in: atlas)
                texture.filteringMode = .linear
                return texture
            } }
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func didMove(to view: SKView) { rebuild() }
    override func didChangeSize(_ oldSize: CGSize) { layoutBoard(); scenery() }

    func rebuild() {
        boardNode.removeAllActions(); boardNode.removeAllChildren(); boxNodes.removeAll()
        zoom = 1; pan = .zero
        guard let board = model?.board else { return }
        let night = model?.theme == "night", wood = model?.theme == "wood"
        let floorColor = night ? UIColor(hex: 0x789db8) : wood ? UIColor(hex: 0xe8d3b3) : UIColor(hex: 0xdaedf2)
        let wallColor = night ? UIColor(hex: 0x567d9d) : wood ? UIColor(hex: 0xa98463) : UIColor(hex: 0xa5cfe1)
        for p in board.floor {
            let tile = rounded(size: CGSize(width: cell - 1, height: cell - 1), color: floorColor, stroke: floorColor.darker)
            tile.position = position(p); boardNode.addChild(tile)
            if board.goals.contains(p) {
                let goal = SKShapeNode(circleOfRadius: cell * 0.29)
                goal.fillColor = UIColor(hex: 0xfef5ce); goal.strokeColor = UIColor(hex: 0xd49d3c); goal.lineWidth = 2
                goal.position = position(p); goal.zPosition = 1; boardNode.addChild(goal)
                let mark = fish(); mark.position = position(p); mark.zPosition = 2; boardNode.addChild(mark)
            }
        }
        for p in board.walls {
            let wall = rounded(size: CGSize(width: cell - 1, height: cell - 1), color: wallColor, stroke: wallColor.darker)
            wall.position = position(p); wall.zPosition = 3
            let cap = rounded(size: CGSize(width: cell - 5, height: 10), color: wallColor.lighter, stroke: .clear)
            cap.position.y = 23; wall.addChild(cap); boardNode.addChild(wall)
        }
        for p in board.state.boxes {
            let node = makeBox(delivered: board.goals.contains(p)); node.position = position(p)
            boardNode.addChild(node); boxNodes[p] = node
        }
        player.removeAllActions(); player.removeFromParent()
        player.size = CGSize(width: cell * 1.13, height: cell * 1.13)
        player.position = position(board.state.player); player.zPosition = 10
        face(board.state.direction); boardNode.addChild(player)
        layoutBoard(); scenery()
    }

    private func position(_ p: GridPoint) -> CGPoint {
        guard let board = model?.board else { return .zero }
        return CGPoint(x: (CGFloat(p.x) + 0.5) * cell, y: (CGFloat(board.height - p.y) - 0.5) * cell)
    }
    func face(_ direction: MoveDirection) {
        let character = model?.character ?? 0
        if textures.indices.contains(character) { player.texture = textures[character][direction.rawValue] }
    }
    func animate(_ event: BoardMove, completion: @escaping () -> Void) {
        face(event.direction)
        let duration: TimeInterval = UIAccessibility.isReduceMotionEnabled ? 0 : event.boxTo == nil ? 0.07 : 0.09
        if let from = event.boxFrom, let to = event.boxTo, let box = boxNodes.removeValue(forKey: from) {
            boxNodes[to] = box
            let move = SKAction.move(to: position(to), duration: duration); move.timingMode = .easeInEaseOut
            box.run(move) { [weak self, weak box] in
                guard let self = self, let box = box else { return }
                if event.delivered { self.colorBox(box, delivered: true) }
            }
            colorBox(box, delivered: event.delivered)
        }
        let move = SKAction.move(to: position(event.to), duration: duration); move.timingMode = .easeInEaseOut
        player.run(move, completion: completion)
        if duration > 0 {
            player.run(.sequence([.rotate(toAngle: 0.05, duration: duration / 2), .rotate(toAngle: 0, duration: duration / 2)]))
        }
    }
    func cancelAnimation() {
        touchStart = nil; touchID = nil
        player.removeAllActions(); player.zRotation = 0
        guard let board = model?.board else { return }
        player.position = position(board.state.player); face(board.state.direction)
        for (p, node) in boxNodes { node.removeAllActions(); node.position = position(p); colorBox(node, delivered: board.goals.contains(p)) }
    }

    func layoutBoard() {
        guard let board = model?.board, size.width > 0, size.height > 0 else { return }
        let landscape = size.width > size.height
        let left = safeInsets.left + (landscape ? 200 : 12), right = safeInsets.right + (landscape ? 176 : 12)
        let top = safeInsets.top + (landscape ? 12 : 82), bottom = safeInsets.bottom + (landscape ? 12 : 174)
        usable = CGRect(x: left, y: bottom, width: max(50, size.width - left - right), height: max(50, size.height - top - bottom))
        fitScale = min(usable.width / (CGFloat(board.width) * cell), usable.height / (CGFloat(board.height) * cell))
        applyTransform()
    }
    func magnify(by factor: CGFloat) {
        guard inputEnabled else { return }
        zoom = min(3, max(1, zoom * factor)); if zoom == 1 { pan = .zero }
        applyTransform()
    }
    var isZoomed: Bool { zoom > 1.01 }
    private func applyTransform() {
        guard let board = model?.board else { return }
        let scale = fitScale * zoom, w = CGFloat(board.width) * cell * scale, h = CGFloat(board.height) * cell * scale
        let limitX = max(0, (w - usable.width) / 2), limitY = max(0, (h - usable.height) / 2)
        pan.x = min(limitX, max(-limitX, pan.x)); pan.y = min(limitY, max(-limitY, pan.y))
        boardNode.setScale(scale)
        boardNode.position = CGPoint(x: usable.midX - w / 2 + pan.x, y: usable.midY - h / 2 + pan.y)
    }
    func resetZoom() { zoom = 1; pan = .zero; applyTransform() }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard inputEnabled, touchID == nil, touches.count == 1, let touch = touches.first else { touchStart = nil; touchID = nil; return }
        touchID = touch; touchStart = touch.location(in: self)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { track(touches) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        track(touches); touchStart = nil; touchID = nil
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touchStart = nil; touchID = nil }
    private func track(_ touches: Set<UITouch>) {
        guard inputEnabled, let touch = touchID, touches.contains(touch), let start = touchStart else { return }
        let point = touch.location(in: self), dx = point.x - start.x, dy = point.y - start.y
        if isZoomed { pan.x += dx; pan.y += dy; applyTransform(); touchStart = point }
        else if max(abs(dx), abs(dy)) >= 24 {
            model?.move(abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .up : .down))
            touchStart = point
        }
    }

    func celebrate() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        for i in 0..<32 {
            let dot = SKShapeNode(circleOfRadius: 3)
            dot.fillColor = [UIColor.white, UIColor(hex: 0xfff2a5), UIColor(hex: 0xe97aab)][i % 3]
            dot.strokeColor = .clear; dot.zPosition = 30
            dot.position = CGPoint(x: usable.minX + CGFloat(i) / 32 * usable.width, y: usable.maxY)
            addChild(dot)
            dot.run(.sequence([.group([.moveBy(x: CGFloat((i % 5) - 2) * 14, y: -usable.height, duration: 1), .fadeOut(withDuration: 1)]), .removeFromParent()]))
        }
    }
    private func scenery() {
        decorations.removeAllChildren()
        let night = model?.theme == "night", wood = model?.theme == "wood"
        backgroundColor = UIColor(hex: night ? 0x173351 : wood ? 0xbcd9df : 0xc7e6f0)
        let snow = SKShapeNode(ellipseOf: CGSize(width: size.width * 1.8, height: size.height * 1.3))
        snow.fillColor = UIColor(hex: night ? 0x315877 : wood ? 0xe9eee6 : 0xedf8fb); snow.strokeColor = .clear
        snow.position = CGPoint(x: size.width / 2, y: size.height * 0.12); decorations.addChild(snow)
        let sun = SKShapeNode(circleOfRadius: 24); sun.fillColor = UIColor(hex: 0xfff1c0); sun.strokeColor = .clear
        sun.position = CGPoint(x: size.width * 0.83, y: size.height * 0.85); decorations.addChild(sun)
    }
    private func rounded(size: CGSize, color: UIColor, stroke: UIColor) -> SKShapeNode {
        let node = SKShapeNode(rectOf: size, cornerRadius: 4); node.fillColor = color; node.strokeColor = stroke; node.lineWidth = 1
        return node
    }
    private func fish() -> SKNode {
        let node = SKNode()
        let body = SKShapeNode(ellipseOf: CGSize(width: 27, height: 12)); body.fillColor = UIColor(hex: 0xc0dde2); body.strokeColor = UIColor(hex: 0x3f7386)
        node.addChild(body)
        let tailPath = CGMutablePath(); tailPath.move(to: CGPoint(x: -12, y: 0)); tailPath.addLine(to: CGPoint(x: -23, y: 8)); tailPath.addLine(to: CGPoint(x: -23, y: -8)); tailPath.closeSubpath()
        let tail = SKShapeNode(path: tailPath); tail.fillColor = UIColor(hex: 0x97bdc8); tail.strokeColor = UIColor(hex: 0x3f7386); node.addChild(tail)
        let eye = SKShapeNode(circleOfRadius: 1.5); eye.fillColor = UIColor(hex: 0x274854); eye.strokeColor = .clear; eye.position = CGPoint(x: 7, y: 2); node.addChild(eye)
        return node
    }
    private func makeBox(delivered: Bool) -> SKNode {
        let node = SKNode(); node.zPosition = 5
        let body = rounded(size: CGSize(width: 52, height: 45), color: .clear, stroke: UIColor(hex: 0x765536)); body.name = "body"; node.addChild(body)
        let inset = rounded(size: CGSize(width: 42, height: 32), color: .clear, stroke: UIColor(hex: 0xc39763)); inset.name = "inset"; node.addChild(inset)
        node.addChild(fish()); colorBox(node, delivered: delivered); return node
    }
    private func colorBox(_ box: SKNode, delivered: Bool) {
        (box.childNode(withName: "body") as? SKShapeNode)?.fillColor = UIColor(hex: delivered ? 0x92bf9e : 0xbf9565)
        (box.childNode(withName: "inset") as? SKShapeNode)?.fillColor = UIColor(hex: delivered ? 0xd6ecd3 : 0xefd3a1)
    }
}

extension UIColor {
    convenience init(hex: UInt32) { self.init(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1) }
    var darker: UIColor { withBrightness(0.76) }
    var lighter: UIColor { withBrightness(1.22) }
    private func withBrightness(_ factor: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: min(1, r * factor), green: min(1, g * factor), blue: min(1, b * factor), alpha: a)
    }
}
