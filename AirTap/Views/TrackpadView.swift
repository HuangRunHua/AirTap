import SwiftUI
import UIKit

struct TrackpadView: View {
    @ObservedObject var viewModel: RemoteViewModel
    @Binding var manualKeyboard: Bool
    var showShortcutBar: Bool

    var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.10, blue: 0.10)
                .ignoresSafeArea()

            if !viewModel.connection.isConnected {
                ConnectionView(viewModel: viewModel)
            } else {
                VStack(spacing: 0) {
                    if let name = viewModel.connection.macName {
                        HStack {
                            Text(name)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.leading, 20)
                            Spacer()
                        }
                        .padding(.top, 12)
                    }

                    TrackpadSurface(
                        onMove: viewModel.sendMouseMove,
                        onTap: viewModel.sendLeftClick,
                        onDoubleTap: viewModel.sendDoubleClick,
                        onTwoFingerTap: viewModel.sendRightClick,
                        onScroll: viewModel.sendScroll,
                        onZoomIn: viewModel.sendZoomIn,
                        onZoomOut: viewModel.sendZoomOut,
                        onSmartZoom: viewModel.sendSmartZoom,
                        onSwitchSpaceLeft: viewModel.sendSwitchSpaceLeft,
                        onSwitchSpaceRight: viewModel.sendSwitchSpaceRight,
                        onMissionControl: viewModel.sendMissionControl
                    )

                    if showShortcutBar {
                        ShortcutBarView(viewModel: viewModel, showKeyboard: $manualKeyboard)
                    }

                    if manualKeyboard {
                        TextInputBar(
                            onText: viewModel.sendTextInput,
                            onDelete: viewModel.sendDeleteBack,
                            onReturn: viewModel.sendReturn,
                            onDismiss: { manualKeyboard = false }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Trackpad surface (UIKit gesture recognizers)

struct TrackpadSurface: UIViewRepresentable {
    let onMove: (Double, Double) -> Void
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onTwoFingerTap: () -> Void
    let onScroll: (Double, Double) -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onSmartZoom: () -> Void
    let onSwitchSpaceLeft: () -> Void
    let onSwitchSpaceRight: () -> Void
    let onMissionControl: () -> Void

    func makeUIView(context: Context) -> TrackpadUIView {
        let view = TrackpadUIView()
        view.onMove = onMove
        view.onTap = onTap
        view.onDoubleTap = onDoubleTap
        view.onTwoFingerTap = onTwoFingerTap
        view.onScroll = onScroll
        view.onZoomIn = onZoomIn
        view.onZoomOut = onZoomOut
        view.onSmartZoom = onSmartZoom
        view.onSwitchSpaceLeft = onSwitchSpaceLeft
        view.onSwitchSpaceRight = onSwitchSpaceRight
        view.onMissionControl = onMissionControl
        return view
    }

    func updateUIView(_ uiView: TrackpadUIView, context: Context) {}
}

final class TrackpadUIView: UIView {
    var onMove: ((Double, Double) -> Void)?
    var onTap: (() -> Void)?
    var onDoubleTap: (() -> Void)?
    var onTwoFingerTap: (() -> Void)?
    var onScroll: ((Double, Double) -> Void)?
    var onZoomIn: (() -> Void)?
    var onZoomOut: (() -> Void)?
    var onSmartZoom: (() -> Void)?
    var onSwitchSpaceLeft: (() -> Void)?
    var onSwitchSpaceRight: (() -> Void)?
    var onMissionControl: (() -> Void)?

    private var pinchAccumulator: CGFloat = 0
    private let pinchStepThreshold: CGFloat = 0.15

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()

    private var displayLink: CADisplayLink?
    private var momentumVelocity: CGPoint = .zero
    private let momentumDecay: CGFloat = 0.95
    private let momentumStopThreshold: CGFloat = 15.0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit { stopMomentum() }

    private func setup() {
        isMultipleTouchEnabled = true
        backgroundColor = .clear

        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        selectionFeedback.prepare()

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        tap.require(toFail: doubleTap)

        let twoFingerDoubleTap = UITapGestureRecognizer(target: self, action: #selector(handleSmartZoom))
        twoFingerDoubleTap.numberOfTouchesRequired = 2
        twoFingerDoubleTap.numberOfTapsRequired = 2

        let twoFingerTap = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTap))
        twoFingerTap.numberOfTouchesRequired = 2
        twoFingerTap.require(toFail: twoFingerDoubleTap)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        pan.maximumNumberOfTouches = 1

        let twoFingerPan = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan))
        twoFingerPan.minimumNumberOfTouches = 2
        twoFingerPan.maximumNumberOfTouches = 2

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))

        [tap, doubleTap, twoFingerDoubleTap, twoFingerTap, pan, twoFingerPan, pinch].forEach(addGestureRecognizer)
    }

    private func accelerationFactor(for velocity: CGPoint) -> CGFloat {
        let speed = hypot(velocity.x, velocity.y)
        let factor = 1.0 + pow(speed / 300.0, 0.7) * 1.5
        return min(factor, 8.0)
    }

    // MARK: - Tap handlers

    @objc private func handleTap(_ g: UITapGestureRecognizer)           { lightImpact.impactOccurred(); onTap?() }
    @objc private func handleDoubleTap(_ g: UITapGestureRecognizer)     { mediumImpact.impactOccurred(); onDoubleTap?() }
    @objc private func handleTwoFingerTap(_ g: UITapGestureRecognizer)  { heavyImpact.impactOccurred(); onTwoFingerTap?() }

    @objc private func handleSmartZoom(_ g: UITapGestureRecognizer)   { mediumImpact.impactOccurred(); onSmartZoom?() }

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        switch g.state {
        case .began:
            pinchAccumulator = 0
        case .changed:
            pinchAccumulator += g.scale - 1.0
            g.scale = 1.0
            while pinchAccumulator > pinchStepThreshold {
                pinchAccumulator -= pinchStepThreshold
                selectionFeedback.selectionChanged()
                onZoomIn?()
            }
            while pinchAccumulator < -pinchStepThreshold {
                pinchAccumulator += pinchStepThreshold
                selectionFeedback.selectionChanged()
                onZoomOut?()
            }
        case .ended, .cancelled:
            pinchAccumulator = 0
        default: break
        }
    }

    // MARK: - Pan gestures

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        let t = g.translation(in: self)
        let v = g.velocity(in: self)
        let f = accelerationFactor(for: v)
        onMove?(Double(t.x * f), Double(t.y * f))
        g.setTranslation(.zero, in: self)
    }

    @objc private func handleTwoFingerPan(_ g: UIPanGestureRecognizer) {
        switch g.state {
        case .began:      stopMomentum()
        case .changed:
            let t = g.translation(in: self)
            onScroll?(Double(t.x), Double(t.y))
            g.setTranslation(.zero, in: self)
        case .ended, .cancelled:
            startMomentum(velocity: g.velocity(in: self))
        default: break
        }
    }

    private func startMomentum(velocity: CGPoint) {
        momentumVelocity = velocity
        guard hypot(momentumVelocity.x, momentumVelocity.y) > momentumStopThreshold else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(momentumTick(_:)))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopMomentum() {
        displayLink?.invalidate()
        displayLink = nil
        momentumVelocity = .zero
    }

    @objc private func momentumTick(_ link: CADisplayLink) {
        let dt = link.targetTimestamp - link.timestamp
        guard dt > 0 else { return }
        onScroll?(Double(momentumVelocity.x * dt), Double(momentumVelocity.y * dt))
        let decay = pow(momentumDecay, CGFloat(dt * 60.0))
        momentumVelocity.x *= decay
        momentumVelocity.y *= decay
        if hypot(momentumVelocity.x, momentumVelocity.y) < momentumStopThreshold {
            stopMomentum()
            selectionFeedback.selectionChanged()
        }
    }
}

// MARK: - Visible text input bar with full IME support

struct TextInputBar: View {
    let onText: (String) -> Void
    let onDelete: () -> Void
    let onReturn: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            IMETextFieldView(onText: onText, onDelete: onDelete, onReturn: onReturn)
                .frame(height: 36)

            Button {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
                onDismiss()
            } label: {
                Text("完成")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }
}

// MARK: - IME-compatible UITextField wrapper

struct IMETextFieldView: UIViewRepresentable {
    let onText: (String) -> Void
    let onDelete: () -> Void
    let onReturn: () -> Void

    func makeUIView(context: Context) -> IMETextField {
        let field = IMETextField()
        field.font = .systemFont(ofSize: 16)
        field.textColor = .white
        field.tintColor = .systemBlue
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.returnKeyType = .send
        field.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        field.layer.cornerRadius = 8
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 1))
        field.leftViewMode = .always
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 1))
        field.rightViewMode = .always
        field.attributedPlaceholder = NSAttributedString(
            string: "输入文本…",
            attributes: [.foregroundColor: UIColor.lightGray]
        )
        field.delegate = context.coordinator
        context.coordinator.field = field

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(IMECoordinator.textDidChange(_:)),
            name: UITextField.textDidChangeNotification,
            object: field
        )

        DispatchQueue.main.async { field.becomeFirstResponder() }
        return field
    }

    func updateUIView(_ uiView: IMETextField, context: Context) {}

    func makeCoordinator() -> IMECoordinator {
        IMECoordinator(onText: onText, onDelete: onDelete, onReturn: onReturn)
    }

    static func dismantleUIView(_ uiView: IMETextField, coordinator: IMECoordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }
}

final class IMETextField: UITextField {
    override func deleteBackward() {
        let wasMarked = markedTextRange != nil
        super.deleteBackward()
        if !wasMarked {
            (delegate as? IMECoordinator)?.handleDeleteBack()
        }
    }
}

final class IMECoordinator: NSObject, UITextFieldDelegate {
    let onText: (String) -> Void
    let onDelete: () -> Void
    let onReturn: () -> Void
    weak var field: IMETextField?
    private var lastSentLength = 0

    init(onText: @escaping (String) -> Void, onDelete: @escaping () -> Void, onReturn: @escaping () -> Void) {
        self.onText = onText
        self.onDelete = onDelete
        self.onReturn = onReturn
    }

    func handleDeleteBack() {
        onDelete()
        let currentLength = field?.text?.count ?? 0
        lastSentLength = currentLength
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard textField.markedTextRange == nil else { return false }
        flushUnsent(in: textField)
        onReturn()
        textField.text = ""
        lastSentLength = 0
        return false
    }

    @objc func textDidChange(_ notification: Notification) {
        guard let tf = notification.object as? UITextField else { return }
        guard tf.markedTextRange == nil else { return }

        let currentLength = tf.text?.count ?? 0
        if currentLength > lastSentLength, let text = tf.text {
            let newText = String(text.suffix(currentLength - lastSentLength))
            onText(newText)
        }
        lastSentLength = currentLength
    }

    private func flushUnsent(in textField: UITextField) {
        let currentLength = textField.text?.count ?? 0
        if currentLength > lastSentLength, let text = textField.text {
            let newText = String(text.suffix(currentLength - lastSentLength))
            onText(newText)
        }
    }
}

