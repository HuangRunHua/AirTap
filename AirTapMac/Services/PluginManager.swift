import Foundation

final class PluginManager: Sendable {

    static let userPluginDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("AirTap/Plugins", isDirectory: true)
    }()

    private let index: [String: [PluginManifest]]

    init() {
        var all: [PluginManifest] = []
        all.append(contentsOf: Self.loadBuiltinPlugins())
        all.append(contentsOf: Self.loadUserPlugins())

        var map: [String: [PluginManifest]] = [:]
        for manifest in all {
            for bundleID in manifest.plugin.targetBundleIds {
                map[bundleID, default: []].append(manifest)
            }
        }
        self.index = map

        print("[PluginManager] Loaded \(all.count) plugin(s), covering \(map.keys.count) app(s)")
    }

    func plugins(for bundleID: String) -> [PluginManifest] {
        index[bundleID] ?? []
    }

    func mergedActions(for bundleID: String) -> [ActionItem] {
        plugins(for: bundleID).flatMap(\.actions)
    }

    func hasPlugin(for bundleID: String) -> Bool {
        index[bundleID] != nil
    }

    // MARK: - Built-in plugins (inside app bundle)

    private static func loadBuiltinPlugins() -> [PluginManifest] {
        guard let resourceURL = Bundle.main.resourceURL else { return [] }
        let pluginsDir = resourceURL.appendingPathComponent("Plugins", isDirectory: true)
        let fromSubdir = loadPlugins(from: pluginsDir, label: "builtin")
        if !fromSubdir.isEmpty { return fromSubdir }
        return loadPlugins(from: resourceURL, label: "builtin")
    }

    // MARK: - User plugins (~/Library/Application Support/AirTap/Plugins/)

    private static func loadUserPlugins() -> [PluginManifest] {
        let dir = userPluginDirectory
        let fm = FileManager.default

        if !fm.fileExists(atPath: dir.path) {
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                print("[PluginManager] Created user plugin directory: \(dir.path)")
            } catch {
                print("[PluginManager] Failed to create user plugin directory: \(error)")
            }
        }

        return loadPlugins(from: dir, label: "user")
    }

    // MARK: - Shared loader

    private static func loadPlugins(from directory: URL, label: String) -> [PluginManifest] {
        let fm = FileManager.default

        guard fm.fileExists(atPath: directory.path),
              let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }

        let jsonFiles = files.filter { $0.pathExtension == "json" }
        var results: [PluginManifest] = []

        for file in jsonFiles {
            do {
                let data = try Data(contentsOf: file)
                let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)
                results.append(manifest)
                print("[PluginManager] Loaded \(label) plugin: \(manifest.plugin.name) (\(manifest.plugin.id))")
            } catch {
                print("[PluginManager] Failed to parse \(label) plugin \(file.lastPathComponent): \(error)")
            }
        }

        return results
    }
}
