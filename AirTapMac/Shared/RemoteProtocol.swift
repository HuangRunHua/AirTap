import Foundation

enum BonjourConfig {
    static let serviceType = "_macremote._tcp"
    static let serviceDomain = "local."
}

// MARK: - iOS → Mac

enum RemoteCommand: Codable, Sendable {
    case requestAppList
    case launchApp(bundleID: String)
    case mouseMove(deltaX: Double, deltaY: Double)
    case leftClick
    case rightClick
    case doubleClick
    case scroll(deltaX: Double, deltaY: Double)
    case keyPress(keyCode: Int, modifiers: UInt64)
    case textInput(text: String)
    case deleteBack
    case shortcut(ShortcutCommand)
    case volumeUp
    case volumeDown
    case playPause
    case zoomIn
    case zoomOut
    case smartZoom
    case switchSpaceLeft
    case switchSpaceRight
    case missionControl
}

enum ShortcutCommand: String, Codable, CaseIterable, Sendable {
    case copy, paste, switchApp, closeTab, undo, selectAll
}

// MARK: - Mac → iOS

enum RemoteResponse: Codable, Sendable {
    case appList([AppInfo])
    case textFieldFocused(Bool)
    case connectionAck(macName: String)
}

struct AppInfo: Codable, Identifiable, Hashable, Sendable {
    var id: String { bundleID }
    let bundleID: String
    let name: String
    let iconPNGData: Data?

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleID)
    }

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.bundleID == rhs.bundleID
    }
}

// MARK: - Length-prefixed framing

enum NetworkFraming {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let json = try JSONEncoder().encode(value)
        var length = UInt32(json.count).bigEndian
        var frame = Data(bytes: &length, count: 4)
        frame.append(json)
        return frame
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}
