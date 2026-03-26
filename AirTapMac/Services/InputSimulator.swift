import AppKit
import CoreGraphics

final class InputSimulator {

    // MARK: - Mouse

    func moveMouse(dx: Double, dy: Double) {
        let pos = currentPosition()
        let dest = CGPoint(x: pos.x + dx, y: pos.y + dy)
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                mouseCursorPosition: dest, mouseButton: .left)?
            .post(tap: .cghidEventTap)
    }

    func leftClick() {
        let p = currentPosition()
        postMousePair(.leftMouseDown, .leftMouseUp, at: p, button: .left)
    }

    func rightClick() {
        let p = currentPosition()
        postMousePair(.rightMouseDown, .rightMouseUp, at: p, button: .right)
    }

    func doubleClick() {
        let p = currentPosition()
        postMousePair(.leftMouseDown, .leftMouseUp, at: p, button: .left)
        let d = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                        mouseCursorPosition: p, mouseButton: .left)
        let u = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                        mouseCursorPosition: p, mouseButton: .left)
        d?.setIntegerValueField(.mouseEventClickState, value: 2)
        u?.setIntegerValueField(.mouseEventClickState, value: 2)
        d?.post(tap: .cghidEventTap)
        u?.post(tap: .cghidEventTap)
    }

    func scroll(dx: Double, dy: Double) {
        CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                wheelCount: 2, wheel1: Int32(dy), wheel2: Int32(dx), wheel3: 0)?
            .post(tap: .cghidEventTap)
    }

    // MARK: - Keyboard

    func keyPress(keyCode: Int, modifiers: UInt64) {
        let flags = CGEventFlags(rawValue: modifiers)
        let down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true)
        let up   = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: false)
        down?.flags = flags
        up?.flags   = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    func typeText(_ text: String) {
        for char in text {
            var utf16 = Array(String(char).utf16)
            let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
            down?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            down?.post(tap: .cghidEventTap)

            let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
            up?.post(tap: .cghidEventTap)
        }
    }

    func deleteBack() {
        keyPress(keyCode: 51, modifiers: 0)
    }

    func executeShortcut(_ shortcut: ShortcutCommand) {
        let cmd = CGEventFlags.maskCommand.rawValue
        switch shortcut {
        case .copy:      keyPress(keyCode: 8,  modifiers: cmd)
        case .paste:     keyPress(keyCode: 9,  modifiers: cmd)
        case .switchApp: keyPress(keyCode: 48, modifiers: cmd)
        case .closeTab:  keyPress(keyCode: 13, modifiers: cmd)
        case .undo:      keyPress(keyCode: 6,  modifiers: cmd)
        case .selectAll: keyPress(keyCode: 0,  modifiers: cmd)
        }
    }

    // MARK: - Gestures

    func zoomIn() {
        keyPress(keyCode: 24, modifiers: CGEventFlags.maskCommand.rawValue)
    }

    func zoomOut() {
        keyPress(keyCode: 27, modifiers: CGEventFlags.maskCommand.rawValue)
    }

    func smartZoom() {
        keyPress(keyCode: 29, modifiers: CGEventFlags.maskCommand.rawValue)
    }

    func switchSpaceLeft() {
        PrivateSystemAPI.shared.switchSpace(direction: -1)
    }

    func switchSpaceRight() {
        PrivateSystemAPI.shared.switchSpace(direction: 1)
    }

    func missionControl() {
        PrivateSystemAPI.shared.triggerMissionControl()
    }

    // MARK: - Media keys

    func volumeUp()   { postMediaKey(0) }
    func volumeDown()  { postMediaKey(1) }
    func playPause()   { postMediaKey(16) }

    // MARK: - Helpers

    private func currentPosition() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    private func postMousePair(_ downType: CGEventType, _ upType: CGEventType,
                               at point: CGPoint, button: CGMouseButton) {
        CGEvent(mouseEventSource: nil, mouseType: downType,
                mouseCursorPosition: point, mouseButton: button)?
            .post(tap: .cghidEventTap)
        CGEvent(mouseEventSource: nil, mouseType: upType,
                mouseCursorPosition: point, mouseButton: button)?
            .post(tap: .cghidEventTap)
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
