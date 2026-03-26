import AppKit
import Combine
import SwiftUI

@MainActor
final class TouchBarController: ObservableObject {

    @Published var isEnabled: Bool = true {
        didSet { isEnabled ? start() : stop() }
    }

    private let panel = TouchBarPanel()
    private let edgeTrigger = EdgeTriggerMonitor()
    private var frontmostMonitor: FrontmostAppMonitor?
    private let pluginManager = PluginManager()
    private let actionExecutor = ActionExecutor()
    private let inputSimulator = InputSimulator()

    private var currentBundleID: String = ""
    private var currentAppName: String = ""
    private var dismissTask: DispatchWorkItem?
    private var stateTimer: Timer?
    private var isStarted = false

    private let dismissDelay: TimeInterval = 0.3

    init() {
        frontmostMonitor = FrontmostAppMonitor { [weak self] bundleID, appName in
            DispatchQueue.main.async {
                self?.handleAppChanged(bundleID: bundleID, appName: appName)
            }
        }
        setupCallbacks()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        edgeTrigger.isEnabled = true
        edgeTrigger.start()
        frontmostMonitor?.start()
    }

    func stop() {
        isStarted = false
        edgeTrigger.stop()
        frontmostMonitor?.stop()
        hideBar()
    }

    // MARK: - Setup

    private func setupCallbacks() {
        edgeTrigger.onTrigger = { [weak self] in
            DispatchQueue.main.async {
                self?.showBar()
            }
        }

        panel.onMouseEntered = { [weak self] in
            self?.cancelDismiss()
        }

        panel.onMouseExited = { [weak self] in
            self?.scheduleDismiss()
        }
    }

    // MARK: - App switching

    private func handleAppChanged(bundleID: String, appName: String) {
        guard bundleID != currentBundleID else { return }
        currentBundleID = bundleID
        currentAppName = appName

        if panel.isBarVisible {
            updateBarContent()
        }
    }

    // MARK: - Show / Hide

    private func showBar() {
        guard !panel.isBarVisible else { return }
        updateBarContent()
        panel.showBar()
        startStatePolling()
    }

    private func hideBar() {
        guard panel.isBarVisible else { return }
        cancelDismiss()
        stopStatePolling()
        panel.hideBar()
    }

    // MARK: - Content

    private func updateBarContent() {
        let actions = pluginManager.mergedActions(for: currentBundleID)
        let displayName: String
        let displayItems: [ActionItem]

        if actions.isEmpty {
            displayName = "通用"
            displayItems = DefaultActions.items
        } else {
            let plugins = pluginManager.plugins(for: currentBundleID)
            displayName = plugins.first?.plugin.name ?? currentAppName
            displayItems = actions
        }

        let contentView = TouchBarContentView(
            appName: displayName,
            items: displayItems,
            onAction: { [weak self] item, value in
                self?.executeAction(item, value: value)
            }
        )
        panel.setBarContent(contentView)
    }

    // MARK: - Action execution

    private func executeAction(_ item: ActionItem, value: Double?) {
        actionExecutor.execute(item.action, value: value, using: inputSimulator)
    }

    // MARK: - Auto-dismiss

    private func scheduleDismiss() {
        cancelDismiss()
        let task = DispatchWorkItem { [weak self] in
            self?.hideBar()
        }
        dismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay, execute: task)
    }

    private func cancelDismiss() {
        dismissTask?.cancel()
        dismissTask = nil
    }

    // MARK: - State polling

    private func startStatePolling() {
        stopStatePolling()

        let actions = currentActions()
        let statefulActions = actions.filter { $0.state != nil }
        guard !statefulActions.isEmpty else { return }

        stateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollStates(for: statefulActions)
            }
        }
        pollStates(for: statefulActions)
    }

    private func stopStatePolling() {
        stateTimer?.invalidate()
        stateTimer = nil
    }

    private func currentActions() -> [ActionItem] {
        let actions = pluginManager.mergedActions(for: currentBundleID)
        return actions.isEmpty ? DefaultActions.items : actions
    }

    private func pollStates(for actions: [ActionItem]) {
        for action in actions {
            guard let stateQuery = action.state, stateQuery.type == "appleScript" else { continue }

            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let script = NSAppleScript(source: stateQuery.script)
                let _ = script?.executeAndReturnError(&error)
            }
        }
    }
}
