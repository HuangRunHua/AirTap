import AppKit
import SwiftUI

final class TouchBarPanel: NSPanel {

    private let barHeight: CGFloat = 52
    private let dockMargin: CGFloat = 8

    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?

    private var trackingArea: NSTrackingArea?
    private(set) var isBarVisible = false

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 52),
            styleMask: [.borderless, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )

        level = .statusBar
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
    }

    func setBarContent<V: View>(_ view: V) {
        let wrappedView = view
            .frame(height: barHeight)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

        let hosting = NSHostingView(rootView: wrappedView)
        contentView = hosting

        let intrinsic = hosting.fittingSize
        let width = max(min(intrinsic.width + 32, maxBarWidth()), 200)
        setContentSize(NSSize(width: width, height: barHeight))

        updateTrackingArea()
    }

    func showBar() {
        guard !isBarVisible else { return }
        guard let screen = NSScreen.main else { return }

        isBarVisible = true
        let target = targetPosition(on: screen)
        setFrameOrigin(target)
        alphaValue = 1
        orderFrontRegardless()
    }

    func hideBar() {
        guard isBarVisible else { return }
        isBarVisible = false
        orderOut(nil)
    }

    // MARK: - Tracking area

    private func updateTrackingArea() {
        if let old = trackingArea {
            contentView?.removeTrackingArea(old)
        }
        let area = NSTrackingArea(
            rect: contentView?.bounds ?? .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        trackingArea = area
        contentView?.addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }

    // MARK: - Positioning

    private func targetPosition(on screen: NSScreen) -> NSPoint {
        let visibleFrame = screen.visibleFrame
        let x = visibleFrame.origin.x + (visibleFrame.width - frame.width) / 2
        let y = visibleFrame.origin.y + dockMargin
        return NSPoint(x: x, y: y)
    }

    private func maxBarWidth() -> CGFloat {
        let screenWidth = NSScreen.main?.frame.width ?? 1440
        return screenWidth * 0.7
    }
}
