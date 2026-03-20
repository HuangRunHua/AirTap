import AppKit
import ApplicationServices

final class AccessibilityMonitor {
    var onFocusChanged: ((Bool) -> Void)?

    private var timer: Timer?
    private var lastState = false

    func start() {
        requestPermissionIfNeeded()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    static func requestPermission() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private

    private func requestPermissionIfNeeded() {
        if !AXIsProcessTrusted() {
            Self.requestPermission()
        }
    }

    private func poll() {
        let focused = isTextFieldFocused()
        if focused != lastState {
            lastState = focused
            onFocusChanged?(focused)
        }
    }

    private func isTextFieldFocused() -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var element: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &element) == .success else {
            return false
        }

        var role: AnyObject?
        AXUIElementCopyAttributeValue(element as! AXUIElement, kAXRoleAttribute as CFString, &role)

        guard let roleStr = role as? String else { return false }
        return ["AXTextField", "AXTextArea", "AXComboBox", "AXWebArea"].contains(roleStr)
    }
}
