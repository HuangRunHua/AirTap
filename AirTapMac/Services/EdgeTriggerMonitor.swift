import AppKit

final class EdgeTriggerMonitor {

    enum State {
        case idle
        case detecting
        case cooldown
    }

    var onTrigger: (() -> Void)?
    var isEnabled: Bool = true

    private var state: State = .idle
    private var monitor: Any?
    private var delayTask: DispatchWorkItem?
    private var cooldownTask: DispatchWorkItem?

    private let hotZoneHeight: CGFloat = 2.0
    private let triggerDelay: TimeInterval = 0.15
    private let cooldownDuration: TimeInterval = 0.2

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.handleMouseMove()
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        cancelDelay()
        cancelCooldown()
        state = .idle
    }

    private func handleMouseMove() {
        guard isEnabled else { return }

        let mouseY = NSEvent.mouseLocation.y
        let inHotZone = mouseY <= hotZoneHeight

        switch state {
        case .idle:
            if inHotZone {
                state = .detecting
                scheduleDelay()
            }

        case .detecting:
            if !inHotZone {
                cancelDelay()
                state = .idle
            }

        case .cooldown:
            break
        }
    }

    private func scheduleDelay() {
        cancelDelay()
        let task = DispatchWorkItem { [weak self] in
            guard let self, self.state == .detecting else { return }
            self.state = .cooldown
            self.onTrigger?()
            self.scheduleCooldown()
        }
        delayTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + triggerDelay, execute: task)
    }

    private func cancelDelay() {
        delayTask?.cancel()
        delayTask = nil
    }

    private func scheduleCooldown() {
        let task = DispatchWorkItem { [weak self] in
            self?.state = .idle
        }
        cooldownTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + cooldownDuration, execute: task)
    }

    private func cancelCooldown() {
        cooldownTask?.cancel()
        cooldownTask = nil
    }
}
