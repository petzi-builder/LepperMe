import AppKit
import Combine
import CoreGraphics

/// Tracks whether the user is actually at the computer:
/// input idle time, screen lock and system sleep.
@MainActor
final class ActivityMonitor {
    private(set) var isScreenLocked = false
    private(set) var isAsleep = false

    /// Called when the user comes back after being away (lock, sleep).
    /// The argument is how long they were away.
    var onReturn: ((TimeInterval) -> Void)?

    private var awaySince: Date?
    private var cancellables = Set<AnyCancellable>()

    var isAway: Bool { isScreenLocked || isAsleep }

    /// Seconds since the last keyboard/mouse/trackpad event in this login session.
    var secondsSinceLastInput: TimeInterval {
        // kCGAnyInputEventType == ~0
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    func start() {
        let distributed = DistributedNotificationCenter.default()
        distributed.publisher(for: Notification.Name("com.apple.screenIsLocked"))
            .sink { [weak self] _ in self?.wentAway { $0.isScreenLocked = true } }
            .store(in: &cancellables)
        distributed.publisher(for: Notification.Name("com.apple.screenIsUnlocked"))
            .sink { [weak self] _ in self?.cameBack { $0.isScreenLocked = false } }
            .store(in: &cancellables)

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.publisher(for: NSWorkspace.willSleepNotification)
            .sink { [weak self] _ in self?.wentAway { $0.isAsleep = true } }
            .store(in: &cancellables)
        workspace.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in self?.cameBack { $0.isAsleep = false } }
            .store(in: &cancellables)
    }

    private func wentAway(_ update: (ActivityMonitor) -> Void) {
        if !isAway { awaySince = Date() }
        update(self)
    }

    private func cameBack(_ update: (ActivityMonitor) -> Void) {
        update(self)
        guard !isAway, let since = awaySince else { return }
        awaySince = nil
        onReturn?(Date().timeIntervalSince(since))
    }
}
