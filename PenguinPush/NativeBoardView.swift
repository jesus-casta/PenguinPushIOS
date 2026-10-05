import SwiftUI
import SpriteKit

struct NativeBoardView: UIViewRepresentable {
    @ObservedObject var model: GameModel
    func makeUIView(context: Context) -> NativeSKView {
        let view = NativeSKView()
        view.gameModel = model
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        view.isMultipleTouchEnabled = true
        view.presentScene(model.scene)
        let pinch = UIPinchGestureRecognizer(target: view, action: #selector(NativeSKView.pinch(_:)))
        view.addGestureRecognizer(pinch)
        let pan = UIPanGestureRecognizer(target: view, action: #selector(NativeSKView.pan(_:)))
        pan.minimumNumberOfTouches = 2; pan.maximumNumberOfTouches = 2
        view.addGestureRecognizer(pan)
        DispatchQueue.main.async { view.becomeFirstResponder() }
        return view
    }
    func updateUIView(_ view: NativeSKView, context: Context) {
        view.isPaused = !model.active
        view.setNeedsLayout()
    }
    static func dismantleUIView(_ view: NativeSKView, coordinator: ()) { view.presentScene(nil) }
}

final class NativeSKView: SKView {
    weak var gameModel: GameModel?
    override var canBecomeFirstResponder: Bool { true }
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let scene = gameModel?.scene else { return }
        let changed = scene.size != bounds.size || scene.safeInsets != safeAreaInsets
        scene.safeInsets = safeAreaInsets
        if scene.size != bounds.size { scene.size = bounds.size }
        if changed { scene.layoutBoard() }
    }
    @objc func pinch(_ gesture: UIPinchGestureRecognizer) {
        gameModel?.scene.magnify(by: gesture.scale); gesture.scale = 1
    }
    @objc func pan(_ gesture: UIPanGestureRecognizer) {
        gameModel?.scene.panBoard(by: gesture.translation(in: self)); gesture.setTranslation(.zero, in: self)
    }
    override var keyCommands: [UIKeyCommand]? {
        [UIKeyCommand.inputUpArrow, UIKeyCommand.inputDownArrow, UIKeyCommand.inputLeftArrow, UIKeyCommand.inputRightArrow,
         "w", "a", "s", "d", "z", "r"].map { UIKeyCommand(input: $0, modifierFlags: [], action: #selector(key(_:))) }
    }
    @objc private func key(_ command: UIKeyCommand) {
        guard let model = gameModel, !model.settingsOpen, !model.choosingCharacter, model.active else { return }
        switch command.input {
        case UIKeyCommand.inputUpArrow, "w": model.move(.up)
        case UIKeyCommand.inputDownArrow, "s": model.move(.down)
        case UIKeyCommand.inputLeftArrow, "a": model.move(.left)
        case UIKeyCommand.inputRightArrow, "d": model.move(.right)
        case "z": model.undo()
        case "r": model.load(level: model.levelIndex)
        default: break
        }
    }
}

/// UIControl tracking gives release/cancel semantics without a long-press gesture delaying the first step.
struct DirectionButton: UIViewRepresentable {
    let direction: MoveDirection
    let enabled: Bool
    let action: () -> Void
    let onRelease: () -> Void
    func makeUIView(context: Context) -> RepeatingArrow {
        let button = RepeatingArrow(frame: .zero)
        button.imageView.image = UIImage(systemName: direction.symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold))
        button.tintColor = .white
        button.backgroundColor = UIColor(hex: 0x214454).withAlphaComponent(0.4)
        button.layer.cornerRadius = 15
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        button.accessibilityLabel = ["Abajo", "Izquierda", "Derecha", "Arriba"][direction.rawValue]
        return button
    }
    func updateUIView(_ view: RepeatingArrow, context: Context) {
        view.onStep = action; view.onRelease = onRelease; view.isEnabled = enabled; view.alpha = enabled ? 1 : 0.4
    }
    static func dismantleUIView(_ view: RepeatingArrow, coordinator: ()) { view.stop() }
}
final class RepeatingArrow: UIControl {
    let imageView = UIImageView()
    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true; accessibilityTraits = .button
        imageView.contentMode = .center; imageView.isUserInteractionEnabled = false
        addSubview(imageView)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func layoutSubviews() { super.layoutSubviews(); imageView.frame = bounds }
    override var isHighlighted: Bool { didSet { imageView.alpha = isHighlighted ? 0.6 : 1 } }
    var onStep: (() -> Void)?
    var onRelease: (() -> Void)?
    private var repeatTimer: Timer?
    override var isEnabled: Bool { didSet { if !isEnabled { stop() } } }
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        guard isEnabled else { return false }
        stop(); isHighlighted = true; onStep?()
        let timer = Timer(timeInterval: 0.11, repeats: true) { [weak self] _ in
            guard let self = self, self.isEnabled else { return }
            self.onStep?()
        }
        timer.fireDate = Date(timeIntervalSinceNow: 0.28)
        RunLoop.main.add(timer, forMode: .common); repeatTimer = timer
        return true
    }
    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        if !bounds.insetBy(dx: -15, dy: -15).contains(touch.location(in: self)) { stop(); return false }
        return true
    }
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) { stop() }
    override func cancelTracking(with event: UIEvent?) { stop() }
    override func accessibilityActivate() -> Bool { guard isEnabled else { return false }; onStep?(); return true }
    func stop() {
        let wasTracking = repeatTimer != nil || isHighlighted
        repeatTimer?.invalidate(); repeatTimer = nil; isHighlighted = false
        if wasTracking { onRelease?() }
    }
    deinit { repeatTimer?.invalidate() }
}
