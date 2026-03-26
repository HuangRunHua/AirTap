import Foundation
import Network
import AppKit
import Combine

@MainActor
class CommandServer: ObservableObject {
    @Published var isRunning = false
    @Published var connectedDevice: String?

    private var listener: NWListener?
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.remotecontrol.server")

    let inputSimulator = InputSimulator()
    let accessibilityMonitor = AccessibilityMonitor()

    func start() {
        do {
            let params = NWParameters.tcp
            listener = try NWListener(using: params)
            listener?.service = NWListener.Service(
                name: Host.current().localizedName ?? "Mac",
                type: BonjourConfig.serviceType,
                domain: BonjourConfig.serviceDomain
            )

            listener?.newConnectionHandler = { [weak self] conn in
                Task { @MainActor [weak self] in
                    self?.accept(conn)
                }
            }

            listener?.stateUpdateHandler = { state in
                Task { @MainActor [weak self] in
                    self?.isRunning = (state == .ready)
                }
            }

            listener?.start(queue: queue)

            accessibilityMonitor.onFocusChanged = { [weak self] focused in
                Task { @MainActor [weak self] in
                    self?.sendResponse(.textFieldFocused(focused))
                }
            }
            accessibilityMonitor.start()
        } catch {
            print("Server start failed: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        connection?.cancel()
        accessibilityMonitor.stop()
        isRunning = false
        connectedDevice = nil
    }

    // MARK: - Connection

    private func accept(_ newConnection: NWConnection) {
        connection?.cancel()
        connection = newConnection

        connection?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .ready:
                    self.connectedDevice = "iOS"
                    let macName = Host.current().localizedName ?? "Mac"
                    self.sendResponse(.connectionAck(macName: macName))
                    self.receiveNext()
                case .failed, .cancelled:
                    self.connectedDevice = nil
                default: break
                }
            }
        }

        connection?.start(queue: queue)
    }

    // MARK: - Send / Receive

    private func sendResponse(_ response: RemoteResponse) {
        guard let data = try? NetworkFraming.encode(response) else { return }
        connection?.send(content: data, completion: .contentProcessed { _ in })
    }

    private func receiveNext() {
        guard let conn = connection else { return }
        conn.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] header, _, isComplete, _ in
            guard let header, header.count == 4 else {
                if !isComplete {
                    Task { @MainActor [weak self] in self?.receiveNext() }
                }
                return
            }

            let length = header.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

            conn.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { [weak self] data, _, isComplete, _ in
                Task { @MainActor [weak self] in
                    if let data, let cmd = try? NetworkFraming.decode(RemoteCommand.self, from: data) {
                        self?.execute(cmd)
                    }
                    if !isComplete {
                        self?.receiveNext()
                    }
                }
            }
        }
    }

    // MARK: - Command execution

    private func execute(_ command: RemoteCommand) {
        switch command {
        case .requestAppList:
            let apps = AppManager.shared.installedApps()
            sendResponse(.appList(apps))

        case .launchApp(let bundleID):
            AppManager.shared.launch(bundleID: bundleID)

        case .mouseMove(let dx, let dy):
            inputSimulator.moveMouse(dx: dx, dy: dy)

        case .leftClick:    inputSimulator.leftClick()
        case .rightClick:   inputSimulator.rightClick()
        case .doubleClick:  inputSimulator.doubleClick()

        case .scroll(let dx, let dy):
            inputSimulator.scroll(dx: dx, dy: dy)

        case .keyPress(let code, let mods):
            inputSimulator.keyPress(keyCode: code, modifiers: mods)

        case .textInput(let text):
            inputSimulator.typeText(text)

        case .deleteBack:
            inputSimulator.deleteBack()

        case .shortcut(let s):
            inputSimulator.executeShortcut(s)

        case .volumeUp:   inputSimulator.volumeUp()
        case .volumeDown: inputSimulator.volumeDown()
        case .playPause:  inputSimulator.playPause()

        case .zoomIn:           inputSimulator.zoomIn()
        case .zoomOut:          inputSimulator.zoomOut()
        case .smartZoom:        inputSimulator.smartZoom()
        case .switchSpaceLeft:
            print("[CommandServer] switchSpaceLeft received")
            inputSimulator.switchSpaceLeft()
        case .switchSpaceRight:
            print("[CommandServer] switchSpaceRight received")
            inputSimulator.switchSpaceRight()
        case .missionControl:
            print("[CommandServer] missionControl received")
            inputSimulator.missionControl()
        }
    }
}
