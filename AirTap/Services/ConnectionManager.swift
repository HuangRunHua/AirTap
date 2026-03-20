import Foundation
import Network
import Combine

@MainActor
class ConnectionManager: ObservableObject {
    @Published var isConnected = false
    @Published var isSearching = false
    @Published var macName: String?
    @Published var availableApps: [AppInfo] = []
    @Published var isTextFieldFocused = false

    private var browser: NWBrowser?
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.remotecontrol.network")

    func startBrowsing() {
        stopBrowsing()
        isSearching = true

        let descriptor = NWBrowser.Descriptor.bonjour(
            type: BonjourConfig.serviceType,
            domain: nil
        )
        browser = NWBrowser(for: descriptor, using: .tcp)

        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            guard let endpoint = results.first?.endpoint else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                self.browser?.cancel()
                self.connect(to: endpoint)
            }
        }

        browser?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                guard let self else { return }
                switch state {
                case .failed:
                    self.isSearching = false
                    self.startBrowsing()
                case .cancelled:
                    self.isSearching = false
                default:
                    break
                }
            }
        }

        browser?.start(queue: queue)
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        isSearching = false
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        isConnected = false
        macName = nil
        availableApps = []
    }

    func send(_ command: RemoteCommand) {
        guard let connection, let data = try? NetworkFraming.encode(command) else { return }
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    // MARK: - Private

    private func connect(to endpoint: NWEndpoint) {
        let conn = NWConnection(to: endpoint, using: .tcp)
        connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                guard let self else { return }
                switch state {
                case .ready:
                    self.isConnected = true
                    self.isSearching = false
                    self.startReceiving(on: conn)
                    self.send(.requestAppList)
                case .failed:
                    self.isConnected = false
                    self.macName = nil
                    self.startBrowsing()
                case .cancelled:
                    self.isConnected = false
                    self.macName = nil
                default:
                    break
                }
            }
        }

        conn.start(queue: queue)
    }

    nonisolated private func startReceiving(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] header, _, isComplete, _ in
            guard let header, header.count == 4 else {
                if !isComplete { self?.startReceiving(on: conn) }
                return
            }

            let length = header.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

            conn.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { [weak self] data, _, isComplete, _ in
                if let data {
                    DispatchQueue.main.async {
                        guard let self else { return }
                        if let response = try? NetworkFraming.decode(RemoteResponse.self, from: data) {
                            self.handleResponse(response)
                        }
                    }
                }
                if !isComplete { self?.startReceiving(on: conn) }
            }
        }
    }

    private func handleResponse(_ response: RemoteResponse) {
        switch response {
        case .appList(let apps):
            availableApps = apps.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .textFieldFocused(let focused):
            isTextFieldFocused = focused
        case .connectionAck(let name):
            macName = name
        }
    }
}
