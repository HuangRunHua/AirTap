import Foundation

// MARK: - Top-level manifest

struct PluginManifest: Codable, Sendable {
    let manifestVersion: Int
    let plugin: PluginInfo
    let actions: [ActionItem]
}

// MARK: - Plugin metadata

struct PluginInfo: Codable, Sendable {
    let id: String
    let name: String
    let version: String
    let targetBundleIds: [String]
    let description: String?
}

// MARK: - Action item

struct ActionItem: Codable, Identifiable, Sendable {
    let id: String
    let type: ActionItemType
    let label: String
    let icon: String?
    let config: ActionItemConfig?
    let action: ActionExecution
    let state: StateQuery?
}

enum ActionItemType: String, Codable, Sendable {
    case button
    case toggle
    case slider
    case segmented
}

// MARK: - Action configuration (slider range, segment options, etc.)

struct ActionItemConfig: Codable, Sendable {
    let min: Double?
    let max: Double?
    let step: Double?
    let options: [SegmentOption]?
}

struct SegmentOption: Codable, Identifiable, Sendable {
    let id: String
    let label: String
    let icon: String?
}

// MARK: - Action execution definition

struct ActionExecution: Codable, Sendable {
    let type: ActionExecutionType
    let keyCode: Int?
    let modifiers: [String]?
    let script: String?
    let command: String?
    let url: String?
    let key: String?
}

enum ActionExecutionType: String, Codable, Sendable {
    case keyPress
    case appleScript
    case shell
    case openURL
    case mediaKey
}

// MARK: - State query (for polling current values)

struct StateQuery: Codable, Sendable {
    let type: String
    let script: String
}
