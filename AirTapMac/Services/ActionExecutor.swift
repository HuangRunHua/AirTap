import AppKit
import CoreGraphics

final class ActionExecutor {

    func execute(_ action: ActionExecution, value: Double? = nil, using simulator: InputSimulator) {
        switch action.type {
        case .keyPress:
            executeKeyPress(action, using: simulator)
        case .appleScript:
            executeAppleScript(action, value: value)
        case .shell:
            executeShell(action, value: value)
        case .openURL:
            executeOpenURL(action)
        case .mediaKey:
            executeMediaKey(action, using: simulator)
        }
    }

    // MARK: - keyPress

    private func executeKeyPress(_ action: ActionExecution, using simulator: InputSimulator) {
        guard let keyCode = action.keyCode else { return }
        let flags = Self.modifierFlags(from: action.modifiers ?? [])
        simulator.keyPress(keyCode: keyCode, modifiers: flags)
    }

    static func modifierFlags(from names: [String]) -> UInt64 {
        var flags: UInt64 = 0
        for name in names {
            switch name.lowercased() {
            case "command", "cmd":
                flags |= CGEventFlags.maskCommand.rawValue
            case "shift":
                flags |= CGEventFlags.maskShift.rawValue
            case "option", "alt":
                flags |= CGEventFlags.maskAlternate.rawValue
            case "control", "ctrl":
                flags |= CGEventFlags.maskControl.rawValue
            default:
                print("[ActionExecutor] Unknown modifier: \(name)")
            }
        }
        return flags
    }

    // MARK: - appleScript

    private func executeAppleScript(_ action: ActionExecution, value: Double?) {
        guard var source = action.script else { return }

        if let v = value {
            source = source.replacingOccurrences(of: "{value}", with: String(Int(v)))
        }

        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            let script = NSAppleScript(source: source)
            script?.executeAndReturnError(&error)
            if let error {
                print("[ActionExecutor] AppleScript error: \(error)")
            }
        }
    }

    // MARK: - shell

    private func executeShell(_ action: ActionExecution, value: Double?) {
        guard var command = action.command else { return }

        if let v = value {
            command = command.replacingOccurrences(of: "{value}", with: String(Int(v)))
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", command]
            do {
                try process.run()
            } catch {
                print("[ActionExecutor] Shell error: \(error)")
            }
        }
    }

    // MARK: - openURL

    private func executeOpenURL(_ action: ActionExecution) {
        guard let urlString = action.url, let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - mediaKey

    private static let mediaKeyMap: [String: Int32] = [
        "playPause": 16,
        "nextTrack": 17,
        "previousTrack": 18,
        "volumeUp": 0,
        "volumeDown": 1,
        "mute": 7,
    ]

    private func executeMediaKey(_ action: ActionExecution, using simulator: InputSimulator) {
        guard let keyName = action.key,
              let keyCode = Self.mediaKeyMap[keyName] else {
            print("[ActionExecutor] Unknown media key: \(action.key ?? "nil")")
            return
        }

        switch keyName {
        case "volumeUp":    simulator.volumeUp()
        case "volumeDown":  simulator.volumeDown()
        case "playPause":   simulator.playPause()
        default:            postMediaKey(keyCode)
        }
    }

    private func postMediaKey(_ key: Int32) {
        func make(down: Bool) -> NSEvent? {
            let flags: NSEvent.ModifierFlags = down ? .init(rawValue: 0xa00) : .init(rawValue: 0xb00)
            let data1 = Int((key << 16) | (down ? 0x0A00 : 0x0B00))
            return NSEvent.otherEvent(with: .systemDefined, location: .zero,
                                      modifierFlags: flags, timestamp: 0,
                                      windowNumber: 0, context: nil,
                                      subtype: 8, data1: data1, data2: -1)
        }
        make(down: true)?.cgEvent?.post(tap: .cghidEventTap)
        make(down: false)?.cgEvent?.post(tap: .cghidEventTap)
    }
}
