import Foundation

enum DefaultActions {

    static let items: [ActionItem] = [
        ActionItem(
            id: "copy", type: .button, label: "复制", icon: "doc.on.doc",
            config: nil,
            action: ActionExecution(type: .keyPress, keyCode: 8, modifiers: ["command"], script: nil, command: nil, url: nil, key: nil),
            state: nil
        ),
        ActionItem(
            id: "paste", type: .button, label: "粘贴", icon: "doc.on.clipboard",
            config: nil,
            action: ActionExecution(type: .keyPress, keyCode: 9, modifiers: ["command"], script: nil, command: nil, url: nil, key: nil),
            state: nil
        ),
        ActionItem(
            id: "undo", type: .button, label: "撤销", icon: "arrow.uturn.backward",
            config: nil,
            action: ActionExecution(type: .keyPress, keyCode: 6, modifiers: ["command"], script: nil, command: nil, url: nil, key: nil),
            state: nil
        ),
        ActionItem(
            id: "select_all", type: .button, label: "全选", icon: "checkmark.circle",
            config: nil,
            action: ActionExecution(type: .keyPress, keyCode: 0, modifiers: ["command"], script: nil, command: nil, url: nil, key: nil),
            state: nil
        ),
        ActionItem(
            id: "close", type: .button, label: "关闭", icon: "xmark.square",
            config: nil,
            action: ActionExecution(type: .keyPress, keyCode: 13, modifiers: ["command"], script: nil, command: nil, url: nil, key: nil),
            state: nil
        ),
        ActionItem(
            id: "vol_down", type: .button, label: "音量-", icon: "speaker.minus",
            config: nil,
            action: ActionExecution(type: .mediaKey, keyCode: nil, modifiers: nil, script: nil, command: nil, url: nil, key: "volumeDown"),
            state: nil
        ),
        ActionItem(
            id: "vol_up", type: .button, label: "音量+", icon: "speaker.plus",
            config: nil,
            action: ActionExecution(type: .mediaKey, keyCode: nil, modifiers: nil, script: nil, command: nil, url: nil, key: "volumeUp"),
            state: nil
        ),
        ActionItem(
            id: "play_pause", type: .button, label: "播放", icon: "playpause.fill",
            config: nil,
            action: ActionExecution(type: .mediaKey, keyCode: nil, modifiers: nil, script: nil, command: nil, url: nil, key: "playPause"),
            state: nil
        ),
    ]
}
