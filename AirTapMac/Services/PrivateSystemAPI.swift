import Foundation
import CoreGraphics

/// Provides access to macOS private APIs for Mission Control and space switching.
/// Uses synthetic trackpad gesture events to trigger native Dock animations,
/// and CoreDockSendNotification for Mission Control.
final class PrivateSystemAPI {
    static let shared = PrivateSystemAPI()

    private typealias CGSConnectionID = Int32
    private typealias CGSSpaceID = UInt64

    private typealias DefaultConnectionFn = @convention(c) () -> CGSConnectionID
    private typealias GetActiveSpaceFn = @convention(c) (CGSConnectionID) -> CGSSpaceID
    private typealias CopyManagedDisplaySpacesFn = @convention(c) (CGSConnectionID) -> CFArray
    private typealias DockNotificationFn = @convention(c) (CFString, Int32) -> Void

    private let _defaultConnection: DefaultConnectionFn?
    private let _getActiveSpace: GetActiveSpaceFn?
    private let _copyManagedDisplaySpaces: CopyManagedDisplaySpacesFn?
    private let _dockNotification: DockNotificationFn?

    // Undocumented CGEvent integer fields used by the WindowServer and Dock
    // for trackpad gesture routing. Stable since macOS 10.11.
    private static let fieldEventType      = CGEventField(rawValue: 55)!   // real CGS event type
    private static let fieldGestureHIDType = CGEventField(rawValue: 110)!  // IOHIDEventType
    private static let fieldScrollY        = CGEventField(rawValue: 119)!
    private static let fieldSwipeMotion    = CGEventField(rawValue: 123)!  // horiz vs vert
    private static let fieldSwipeProgress  = CGEventField(rawValue: 124)!  // cumulative distance
    private static let fieldVelocityX      = CGEventField(rawValue: 129)!
    private static let fieldVelocityY      = CGEventField(rawValue: 130)!
    private static let fieldGesturePhase   = CGEventField(rawValue: 132)!  // began/changed/ended
    private static let fieldScrollFlags    = CGEventField(rawValue: 135)!  // direction hint
    private static let fieldZoomDeltaX     = CGEventField(rawValue: 139)!  // required by Dock

    private static let cgsEventGesture: Int64     = 29
    private static let cgsEventDockControl: Int64 = 30
    private static let hidDockSwipe: Int64        = 23
    private static let motionHorizontal: Int64    = 1
    private static let phaseBegan: Int64          = 1
    private static let phaseEnded: Int64          = 4

    private init() {
        let skylight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
        let hiservices = dlopen(
            "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/HIServices",
            RTLD_LAZY
        )

        func resolve<T>(_ handle: UnsafeMutableRawPointer?, _ name: String) -> T? {
            guard let handle, let sym = dlsym(handle, name) else {
                print("[PrivateSystemAPI] Failed to resolve \(name)")
                return nil
            }
            return unsafeBitCast(sym, to: T.self)
        }

        _defaultConnection = resolve(skylight, "_CGSDefaultConnection")
        _getActiveSpace = resolve(skylight, "CGSGetActiveSpace")
        _copyManagedDisplaySpaces = resolve(skylight, "CGSCopyManagedDisplaySpaces")
        _dockNotification = resolve(hiservices, "CoreDockSendNotification")

        if skylight == nil { print("[PrivateSystemAPI] SkyLight framework not found") }
        if hiservices == nil { print("[PrivateSystemAPI] HIServices framework not found") }
    }

    // MARK: - Mission Control

    func triggerMissionControl() {
        guard let fn = _dockNotification else {
            print("[PrivateSystemAPI] CoreDockSendNotification unavailable")
            return
        }
        fn("com.apple.expose.awake" as CFString, 0)
    }

    // MARK: - Space Switching (Native Animation)

    /// Switch one space left (direction = -1) or right (direction = 1).
    /// Posts synthetic DockSwipe gesture events so the Dock performs its
    /// native sliding animation instead of an instant jump.
    func switchSpace(direction: Int) {
        guard canSwitch(direction: -direction) else {
            print("[PrivateSystemAPI] Already at edge space")
            return
        }

        let right = direction < 0
        let sign: Double = right ? 1.0 : -1.0

        guard let begin = makeDockEvent(phase: Self.phaseBegan, right: right),
              let end   = makeDockEvent(phase: Self.phaseEnded, right: right) else {
            print("[PrivateSystemAPI] Failed to create gesture events")
            return
        }

        end.setDoubleValueField(Self.fieldSwipeProgress, value: sign * 1.0)
        end.setDoubleValueField(Self.fieldVelocityX, value: sign * 5.0)
        end.setDoubleValueField(Self.fieldVelocityY, value: 0)

        postEventPair(dock: begin)
        postEventPair(dock: end)
    }

    // MARK: - Private Helpers

    private func canSwitch(direction: Int) -> Bool {
        guard let conn = _defaultConnection,
              let getActive = _getActiveSpace,
              let copySpaces = _copyManagedDisplaySpaces else { return true }

        let cid = conn()
        let activeSpace = getActive(cid)
        let displays = copySpaces(cid) as NSArray

        for (di, displayInfo) in displays.enumerated() {
            guard let dict = displayInfo as? NSDictionary,
                  let spaces = dict["Spaces"] as? [NSDictionary],
                  let displayID = dict["Display Identifier"] as? String else { continue }

            let navigableSpaces = spaces.filter {
                let t = $0["type"] as? Int ?? -1
                return t == 0 || t == 4
            }

            let spaceIDs: [CGSSpaceID] = navigableSpaces.compactMap { space in
                if let id = space["ManagedSpaceID"] as? CGSSpaceID { return id }
                if let id = space["ManagedSpaceID"] as? Int64 { return CGSSpaceID(id) }
                if let id = space["ManagedSpaceID"] as? Int { return CGSSpaceID(id) }
                return nil
            }

            guard let currentIndex = spaceIDs.firstIndex(of: activeSpace) else { continue }
            let newIndex = currentIndex + direction
            let canDo = spaceIDs.indices.contains(newIndex)
            print("[PrivateSystemAPI] canSwitch: display=\(di) (\(displayID.prefix(8))...), active=\(activeSpace), index=\(currentIndex)/\(spaceIDs.count), dir=\(direction), spaces=\(spaceIDs), result=\(canDo)")
            return canDo
        }

        print("[PrivateSystemAPI] canSwitch: active=\(activeSpace) not found on any display")
        return true
    }

    /// Build a DockControl event with fields common to both Begin and End phases.
    private func makeDockEvent(phase: Int64, right: Bool) -> CGEvent? {
        guard let ev = CGEvent(source: nil) else { return nil }
        ev.setIntegerValueField(Self.fieldEventType, value: Self.cgsEventDockControl)
        ev.setIntegerValueField(Self.fieldGestureHIDType, value: Self.hidDockSwipe)
        ev.setIntegerValueField(Self.fieldGesturePhase, value: phase)
        ev.setIntegerValueField(Self.fieldScrollFlags, value: right ? 1 : 0)
        ev.setIntegerValueField(Self.fieldSwipeMotion, value: Self.motionHorizontal)
        ev.setDoubleValueField(Self.fieldScrollY, value: 0)
        ev.setDoubleValueField(Self.fieldZoomDeltaX, value: Double(Float.leastNonzeroMagnitude))
        return ev
    }

    /// Post a dock-control event followed by its companion gesture event.
    /// The Dock expects paired events for proper processing.
    private func postEventPair(dock: CGEvent) {
        guard let companion = CGEvent(source: nil) else { return }
        companion.setIntegerValueField(Self.fieldEventType, value: Self.cgsEventGesture)
        dock.post(tap: .cgSessionEventTap)
        companion.post(tap: .cgSessionEventTap)
    }
}
