import SwiftUI
import Combine

@MainActor
class RemoteViewModel: ObservableObject {
    @Published var selectedApps: [AppInfo] = []

    let connection = ConnectionManager()

    private let storageKey = "selectedAppBundleIDs"
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Forward connection's changes so SwiftUI re-renders views observing this ViewModel
        connection.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        connection.$availableApps
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] apps in
                self?.restoreSelectedApps(from: apps)
            }
            .store(in: &cancellables)
    }

    // MARK: - App management

    func addApp(_ app: AppInfo) {
        selectedApps.append(app)
        persistSelection()
    }

    func removeApp(at index: Int) {
        guard selectedApps.indices.contains(index) else { return }
        selectedApps.remove(at: index)
        persistSelection()
    }

    // MARK: - Commands

    func launchApp(_ app: AppInfo) {
        connection.send(.launchApp(bundleID: app.bundleID))
    }

    func sendMouseMove(dx: Double, dy: Double) {
        connection.send(.mouseMove(deltaX: dx, deltaY: dy))
    }

    func sendLeftClick()   { connection.send(.leftClick) }
    func sendRightClick()  { connection.send(.rightClick) }
    func sendDoubleClick() { connection.send(.doubleClick) }

    func sendScroll(dx: Double, dy: Double) {
        connection.send(.scroll(deltaX: dx, deltaY: dy))
    }

    func sendTextInput(_ text: String) { connection.send(.textInput(text: text)) }
    func sendDeleteBack()              { connection.send(.deleteBack) }
    func sendReturn()                  { connection.send(.keyPress(keyCode: 36, modifiers: 0)) }
    func sendShortcut(_ s: ShortcutCommand) { connection.send(.shortcut(s)) }
    func sendVolumeUp()    { connection.send(.volumeUp) }
    func sendVolumeDown()  { connection.send(.volumeDown) }
    func sendPlayPause()   { connection.send(.playPause) }

    func sendZoomIn()           { connection.send(.zoomIn) }
    func sendZoomOut()          { connection.send(.zoomOut) }
    func sendSmartZoom()        { connection.send(.smartZoom) }
    func sendSwitchSpaceLeft()  { connection.send(.switchSpaceLeft) }
    func sendSwitchSpaceRight() { connection.send(.switchSpaceRight) }
    func sendMissionControl()   { connection.send(.missionControl) }

    // MARK: - Persistence

    private func persistSelection() {
        UserDefaults.standard.set(selectedApps.map(\.bundleID), forKey: storageKey)
    }

    private func restoreSelectedApps(from available: [AppInfo]) {
        let savedIDs = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        guard !savedIDs.isEmpty else { return }
        selectedApps = savedIDs.compactMap { id in available.first { $0.bundleID == id } }
    }
}
