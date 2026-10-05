import SpriteKit
import UIKit

final class PenguinScene: SKScene {
    weak var model: GameModel?
    var inputEnabled = true
    var safeInsets = UIEdgeInsets.zero
    private let boardNode = SKNode()
    private let decorations = SKNode()
    private let player = SKSpriteNode()
    private let actor = SKNode()
    private let shadow = SKShapeNode(ellipseOf: CGSize(width: 35, height: 9))
    private var manualCamera = false
    private var stepSide: CGFloat = 1
    private var boxNodes: [GridPoint: SKNode] = [:]
    private var textures: [[SKTexture]] = []
    private var cell: CGFloat = 64
    private var fitScale: CGFloat = 1
    private var zoom: CGFloat = 1
    private var pan = CGPoint.zero
    private var touchStart: CGPoint?
    private var touchOrigin: CGPoint?
    private var gestureMoved = false
    private let destinationMarker = SKShapeNode(rectOf: CGSize(width: 54, height: 54), cornerRadius: 10)
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
        zoom = 1; pan = .zero; manualCamera = false
        guard let board = model?.board else { return }
        let night = model?.theme == "night", wood = model?.theme == "wood"
        let floorColor = night ? UIColor(hex: 0x789db8) : wood ? UIColor(hex: 0xe8d3b3) : UIColor(hex: 0xedf6f8)
        for p in board.floor {
            let tile = rounded(size: CGSize(width: cell - 1, height: cell - 1), color: floorColor, stroke: UIColor(hex: 0xb7d2dc).withAlphaComponent(0.35))
            tile.position = position(p); boardNode.addChild(tile)
            if board.goals.contains(p) {
                let goal = SKShapeNode(circleOfRadius: cell * 0.29)
                goal.fillColor = UIColor(hex: 0xfef5ce); goal.strokeColor = UIColor(hex: 0xd49d3c); goal.lineWidth = 2
                goal.position = position(p); goal.zPosition = 1; boardNode.addChild(goal)
                let mark = fish(); mark.position = position(p); mark.zPosition = 2; boardNode.addChild(mark)
            }
        }
        for p in board.walls {
            let igloo = makeIgloo()
            igloo.position = position(p); igloo.zPosition = 3; boardNode.addChild(igloo)
        }
        for p in board.state.boxes {
            let node = makeBox(delivered: board.goals.contains(p)); node.position = position(p)
            boardNode.addChild(node); boxNodes[p] = node
        }
        actor.removeAllActions(); actor.removeFromParent(); actor.removeAllChildren()
        player.removeAllActions(); player.removeFromParent(); player.position = .zero
        player.setScale(1); player.zRotation = 0
        player.size = CGSize(width: cell * 1.13, height: cell * 1.13)
        player.zPosition = 2
        shadow.fillColor = UIColor(hex: 0x214454).withAlphaComponent(0.22); shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -27); shadow.zPosition = 0; shadow.setScale(1)
        actor.position = position(board.state.player); actor.zPosition = 10
        actor.addChild(shadow); actor.addChild(player)
        face(board.state.direction); boardNode.addChild(actor)
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
        let pushing = event.boxTo != nil
        let duration: TimeInterval = UIAccessibility.isReduceMotionEnabled ? 0 : pushing ? 0.12 : 0.10
        if let from = event.boxFrom, let to = event.boxTo, let box = boxNodes.removeValue(forKey: from) {
            boxNodes[to] = box
            if !event.delivered { colorBox(box, delivered: false) }
            let move = SKAction.move(to: position(to), duration: duration); move.timingMode = .easeInEaseOut
            box.run(move) { [weak self, weak box] in
                guard let self = self, let box = box else { return }
                self.colorBox(box, delivered: event.delivered)
                if event.delivered && duration > 0 {
                    box.run(.sequence([.scale(to: 1.12, duration: 0.07), .scale(to: 1, duration: 0.10)]))
                }
            }
        }
        let move = SKAction.move(to: position(event.to), duration: duration)
        move.timingMode = pushing ? .easeInEaseOut : .linear
        stepSide *= -1
        let side = stepSide
        let gait = SKAction.customAction(withDuration: duration) { [weak self] _, elapsed in
            guard let self = self, duration > 0 else { return }
            let phase = min(1, CGFloat(elapsed) / CGFloat(duration)), lift = sin(phase * .pi)
            self.player.position = CGPoint(x: pushing ? CGFloat(event.direction.dx) * lift * 3 : 0, y: pushing ? lift * 2 : lift * 7)
            self.player.zRotation = (pushing ? -CGFloat(event.direction.dx) * 0.09 : side * 0.07) * lift
            self.player.xScale = 1 + lift * (pushing ? 0.05 : 0.025)
            self.player.yScale = 1 - lift * (pushing ? 0.06 : 0.025)
            self.shadow.xScale = 1 - lift * 0.15
        }
        actor.run(.group([move, gait])) { [weak self] in
            self?.player.position = .zero; self?.player.zRotation = 0; self?.player.setScale(1); self?.shadow.setScale(1)
            completion()
        }
        if duration > 0 && !pushing {
            let print = SKShapeNode(ellipseOf: CGSize(width: 7, height: 3))
            print.fillColor = UIColor(hex: 0x6d9dad).withAlphaComponent(0.3); print.strokeColor = .clear
            print.position = CGPoint(x: position(event.from).x + side * 8, y: position(event.from).y - 25)
            print.zPosition = 2; boardNode.addChild(print)
            print.run(.sequence([.fadeOut(withDuration: 0.45), .removeFromParent()]))
        }
        if !manualCamera { follow(event.to, duration: duration) }
    }
    func cancelAnimation() {
        touchStart = nil; touchOrigin = nil; touchID = nil
        actor.removeAllActions(); player.removeAllActions(); player.zRotation = 0; player.position = .zero; player.setScale(1); shadow.setScale(1)
        guard let board = model?.board else { return }
        actor.position = position(board.state.player); face(board.state.direction)
        if !manualCamera { follow(board.state.player, duration: 0) }
        for (p, node) in boxNodes { node.removeAllActions(); node.setScale(1); node.position = position(p); colorBox(node, delivered: board.goals.contains(p)) }
    }

    func layoutBoard() {
        guard let board = model?.board, size.width > 0, size.height > 0 else { return }
        usable = CGRect(origin: .zero, size: size)
        // Controls float over the world; no strip of the display is reserved for them.
        fitScale = max(size.width / (CGFloat(board.width) * cell), size.height / (CGFloat(board.height) * cell))
        if !manualCamera { follow(board.state.player, duration: 0) } else { applyTransform() }
    }
    private var overviewFactor: CGFloat {
        guard let board = model?.board, fitScale > 0 else { return 1 }
        return min(size.width / (CGFloat(board.width) * cell), size.height / (CGFloat(board.height) * cell)) / fitScale
    }
    func magnify(by factor: CGFloat) {
        guard inputEnabled else { return }
        manualCamera = true
        zoom = min(3, max(overviewFactor, zoom * factor)); applyTransform()
    }
    var isZoomed: Bool { manualCamera && zoom > overviewFactor + 0.01 }
    private func applyTransform(duration: TimeInterval = 0) {
        guard let board = model?.board else { return }
        let scale = fitScale * zoom, w = CGFloat(board.width) * cell * scale, h = CGFloat(board.height) * cell * scale
        let limitX = max(0, (w - usable.width) / 2), limitY = max(0, (h - usable.height) / 2)
        pan.x = min(limitX, max(-limitX, pan.x)); pan.y = min(limitY, max(-limitY, pan.y))
        boardNode.setScale(scale)
        let target = CGPoint(x: usable.midX - w / 2 + pan.x, y: usable.midY - h / 2 + pan.y)
        boardNode.removeAction(forKey: "camera")
        if duration > 0 { boardNode.run(.move(to: target, duration: duration), withKey: "camera") }
        else { boardNode.position = target }
    }
    private func follow(_ point: GridPoint, duration: TimeInterval) {
        guard let board = model?.board else { return }
        let scale = fitScale * zoom, center = position(point)
        pan = CGPoint(x: (CGFloat(board.width) * cell / 2 - center.x) * scale,
                      y: (CGFloat(board.height) * cell / 2 - center.y) * scale)
        applyTransform(duration: UIAccessibility.isReduceMotionEnabled ? 0 : duration)
    }
    func overview() { manualCamera = true; zoom = overviewFactor; pan = .zero; applyTransform() }
    func resetZoom() { zoom = 1; manualCamera = false; if let p = model?.board?.state.player { follow(p, duration: 0) } }
    func panBoard(by offset: CGPoint) {
        guard inputEnabled else { return }
        manualCamera = true; pan.x += offset.x; pan.y -= offset.y; applyTransform()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard inputEnabled, touchID == nil, touches.count == 1, let touch = touches.first else { touchStart = nil; touchOrigin = nil; touchID = nil; return }
        touchID = touch; touchStart = touch.location(in: self); touchOrigin = touchStart; gestureMoved = false
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { track(touches) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        track(touches)
        if inputEnabled, !gestureMoved, let touch = touchID, touches.contains(touch), let origin = touchOrigin {
            let point = touch.location(in: self)
            if hypot(point.x - origin.x, point.y - origin.y) < 12 { tapCell(at: point) }
        }
        touchStart = nil; touchOrigin = nil; touchID = nil
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touchStart = nil; touchOrigin = nil; touchID = nil }
    private func track(_ touches: Set<UITouch>) {
        guard inputEnabled, let touch = touchID, touches.contains(touch), let start = touchStart else { return }
        let point = touch.location(in: self), dx = point.x - start.x, dy = point.y - start.y
        if isZoomed {
            if let origin = touchOrigin, hypot(point.x - origin.x, point.y - origin.y) >= 12 { gestureMoved = true }
            pan.x += dx; pan.y += dy; applyTransform(); touchStart = point }
        else if max(abs(dx), abs(dy)) >= 24 {
            gestureMoved = true
            model?.move(abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .up : .down))
            touchStart = point
        }
    }

    private func tapCell(at scenePoint: CGPoint) {
        guard let board = model?.board else { return }
        let local = boardNode.convert(scenePoint, from: self)
        let x = Int(floor(local.x / cell)), y = board.height - 1 - Int(floor(local.y / cell))
        guard x >= 0, x < board.width, y >= 0, y < board.height else { return }
        model?.walk(to: GridPoint(x: x, y: y))
    }
    func markDestination(_ point: GridPoint, reachable: Bool) {
        clearDestination()
        destinationMarker.position = position(point); destinationMarker.zPosition = 4
        destinationMarker.lineWidth = 2.5
        destinationMarker.strokeColor = UIColor(hex: reachable ? 0x259c99 : 0xd2766b)
        destinationMarker.fillColor = destinationMarker.strokeColor.withAlphaComponent(0.12)
        boardNode.addChild(destinationMarker)
        if !reachable { destinationMarker.run(.sequence([.wait(forDuration: 0.35), .fadeOut(withDuration: 0.15), .removeFromParent()])) }
    }
    func clearDestination() {
        destinationMarker.removeAllActions(); destinationMarker.removeFromParent(); destinationMarker.alpha = 1
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
    private func makeIgloo() -> SKNode {
        let node = SKNode()
        let base = SKShapeNode(ellipseOf: CGSize(width: 58, height: 12))
        base.fillColor = UIColor(hex: 0x719dad).withAlphaComponent(0.2); base.strokeColor = .clear
        base.position.y = -24; node.addChild(base)
        let outline = CGMutablePath()
        outline.move(to: CGPoint(x: -29, y: -22)); outline.addLine(to: CGPoint(x: 29, y: -22))
        outline.addLine(to: CGPoint(x: 29, y: -7))
        outline.addArc(center: CGPoint(x: 0, y: -7), radius: 29, startAngle: 0, endAngle: .pi, clockwise: false)
        outline.closeSubpath()
        let dome = SKShapeNode(path: outline)
        dome.fillColor = UIColor(hex: 0xf9fdff); dome.strokeColor = UIColor(hex: 0x91b8c8); dome.lineWidth = 1.2
        node.addChild(dome)
        let seams = CGMutablePath()
        for y in [CGFloat(-10), 0, 10] {
            let half = y < -7 ? CGFloat(28) : sqrt(29 * 29 - (y + 7) * (y + 7))
            seams.move(to: CGPoint(x: -half, y: y)); seams.addLine(to: CGPoint(x: half, y: y))
        }
        let joints: [(CGFloat, CGFloat)] = [(-14, -18), (7, -18), (0, -7), (-14, 3), (14, 3), (0, 13)]
        for (x, y) in joints {
            seams.move(to: CGPoint(x: x, y: y)); seams.addLine(to: CGPoint(x: x, y: y + 7))
        }
        let bricks = SKShapeNode(path: seams); bricks.strokeColor = UIColor(hex: 0xb6d5df); bricks.lineWidth = 1
        node.addChild(bricks)
        let tunnel = SKShapeNode(rectOf: CGSize(width: 25, height: 25), cornerRadius: 11)
        tunnel.fillColor = .white; tunnel.strokeColor = UIColor(hex: 0x91b8c8); tunnel.lineWidth = 1.2
        tunnel.position = CGPoint(x: 9, y: -16); node.addChild(tunnel)
        let door = SKShapeNode(rectOf: CGSize(width: 15, height: 19), cornerRadius: 7)
        door.fillColor = UIColor(hex: 0x648c9e); door.strokeColor = UIColor(hex: 0x416c81); door.lineWidth = 1
        door.position = CGPoint(x: 9, y: -19); node.addChild(door)
        let drift = SKShapeNode(ellipseOf: CGSize(width: 22, height: 5))
        drift.fillColor = UIColor(hex: 0xe7f3f8); drift.strokeColor = .clear
        drift.position = CGPoint(x: -14, y: -23); node.addChild(drift)
        return node
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
