import Foundation

enum BonjourConfig {
    static let serviceType = "_macremote._tcp"
    static let serviceDomain = "local."
}

// MARK: - iOS → Mac

enum RemoteCommand: Codable {
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

enum ShortcutCommand: String, Codable, CaseIterable {
    case copy, paste, switchApp, closeTab, undo, selectAll

    var label: String {
        switch self {
        case .copy: "复制"
        case .paste: "粘贴"
        case .switchApp: "切换"
        case .closeTab: "关闭"
        case .undo: "撤销"
        case .selectAll: "全选"
        }
    }

    var symbol: String {
        switch self {
        case .copy: "doc.on.doc"
        case .paste: "doc.on.clipboard"
        case .switchApp: "rectangle.on.rectangle"
        case .closeTab: "xmark.square"
        case .undo: "arrow.uturn.backward"
        case .selectAll: "selection.pin.in.out"
        }
    }

    var shortcutText: String {
        switch self {
        case .copy: "⌘C"
        case .paste: "⌘V"
        case .switchApp: "⌘Tab"
        case .closeTab: "⌘W"
        case .undo: "⌘Z"
        case .selectAll: "⌘A"
        }
    }
}

// MARK: - Mac → iOS

enum RemoteResponse: Codable {
    case appList([AppInfo])
    case textFieldFocused(Bool)
    case connectionAck(macName: String)
}

struct AppInfo: Codable, Identifiable, Hashable {
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

// MARK: - Length-prefixed framing: [4 bytes big-endian length][JSON payload]

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
