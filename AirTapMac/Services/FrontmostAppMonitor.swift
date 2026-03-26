import AppKit

final class FrontmostAppMonitor: Sendable {
    private let callback: @Sendable (String, String) -> Void
    private let lastBundleID = MutableState("")

    init(onAppChanged: @escaping @Sendable (_ bundleID: String, _ appName: String) -> Void) {
        self.callback = onAppChanged
    }

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        if let app = NSWorkspace.shared.frontmostApplication,
           let bundleID = app.bundleIdentifier,
           let name = app.localizedName {
            lastBundleID.value = bundleID
            callback(bundleID, name)
        }
    }

    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier,
              let name = app.localizedName else { return }

        guard bundleID != lastBundleID.value else { return }
        lastBundleID.value = bundleID
        callback(bundleID, name)
    }
}

private final class MutableState<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T

    init(_ value: T) { _value = value }

    var value: T {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
}
