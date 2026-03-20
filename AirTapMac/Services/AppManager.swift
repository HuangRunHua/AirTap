import AppKit

final class AppManager {
    static let shared = AppManager()

    func installedApps() -> [AppInfo] {
        var apps: [AppInfo] = []
        let fm = FileManager.default
        let dirs = ["/Applications", "/System/Applications"]

        for dir in dirs {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items where item.hasSuffix(".app") {
                let path = (dir as NSString).appendingPathComponent(item)
                guard let bundle = Bundle(path: path),
                      let bundleID = bundle.bundleIdentifier else { continue }

                let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? item.replacingOccurrences(of: ".app", with: "")

                let iconData = iconPNG(for: path)
                apps.append(AppInfo(bundleID: bundleID, name: name, iconPNGData: iconData))
            }
        }

        return apps.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    func launch(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, _ in }
    }

    // MARK: - Icon extraction

    private func iconPNG(for appPath: String) -> Data? {
        let icon = NSWorkspace.shared.icon(forFile: appPath)
        let target = NSSize(width: 128, height: 128)
        let resized = NSImage(size: target)
        resized.lockFocus()
        icon.draw(in: NSRect(origin: .zero, size: target),
                  from: .zero, operation: .copy, fraction: 1)
        resized.unlockFocus()

        guard let tiff = resized.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        return png
    }
}
