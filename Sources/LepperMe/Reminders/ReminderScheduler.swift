import Foundation
import Combine

enum OverlayOutcome {
    case completed
    case skipped
    case snoozed
}

enum SchedulerState: Equatable {
    case running
    case pausedManually(until: Date)
    case inMeeting
    case idle
    case away
    case showingReminder(ReminderKind)
}

/// Owns the three timers, their priorities and the queue of reminders collected during meetings.
///
/// Timers only advance while the user is active: they stop during manual pauses, inactivity,
/// screen lock/sleep and while an overlay is showing. Elapsed time is measured in active seconds.
@MainActor
final class ReminderScheduler: ObservableObject {
    @Published private(set) var state: SchedulerState = .running
    @Published private(set) var elapsed: [ReminderKind: TimeInterval] = [:]
    @Published private(set) var pending: Set<ReminderKind> = []

    private let settings: SettingsStore
    private let meetings: MeetingDetector
    private let activity: ActivityMonitor
    private let overlay: OverlayController

    private var pausedUntil: Date?
    private var preWarnedKind: ReminderKind?
    private var wasIdle = false
    private var wasInMeeting = false
    private var meetingEndedAt: Date?
    /// Pause between the "Willkommen zurück" notice and the combined reminder after a meeting.
    static let afterMeetingDelay: TimeInterval = 6
    private var lastIdleSeconds: TimeInterval = 0
    private var lastTick = Date()
    private var timer: AnyCancellable?

    init(settings: SettingsStore, meetings: MeetingDetector, activity: ActivityMonitor, overlay: OverlayController) {
        self.settings = settings
        self.meetings = meetings
        self.activity = activity
        self.overlay = overlay
        resetAll()
    }

    func start() {
        activity.onReturn = { [weak self] awayFor in
            self?.userReturned(afterBeingAwayFor: awayFor)
        }
        lastTick = Date()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in self?.tick(now: now) }
    }

    // MARK: - Public actions (menu bar)

    /// The next enabled reminder and the active seconds left until it is due.
    var nextReminder: (kind: ReminderKind, remaining: TimeInterval)? {
        let s = settings.settings
        return ReminderKind.byPriority
            .filter { s.config(for: $0).isEnabled }
            .map { ($0, max(0, s.config(for: $0).intervalSeconds - (elapsed[$0] ?? 0))) }
            .min { $0.1 < $1.1 }
            .map { (kind: $0.0, remaining: $0.1) }
    }

    /// 0…1 progress towards the next reminder, for the menu bar ring.
    var nextReminderProgress: Double {
        guard let next = nextReminder else { return 0 }
        let interval = settings.settings.config(for: next.kind).intervalSeconds
        return interval > 0 ? 1 - next.remaining / interval : 0
    }

    func takeBreakNow() {
        show(.rest, afterMeeting: false)
    }

    /// "Testen" in the settings: shows the overlay without touching any timer.
    func preview(_ kind: ReminderKind) {
        show(kind, afterMeeting: false, isPreview: true)
    }

    func pause(for duration: TimeInterval) {
        pause(until: Date().addingTimeInterval(duration))
    }

    func pauseUntilTomorrow() {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        pause(until: tomorrow)
    }

    func resume() {
        pausedUntil = nil
        state = .running
    }

    var isPausedManually: Bool { pausedUntil != nil }

    // MARK: - Tick

    private func tick(now: Date) {
        // Cap dt so a missed tick (e.g. after sleep) never counts as a long active stretch.
        let dt = min(now.timeIntervalSince(lastTick), 5)
        lastTick = now
        let s = settings.settings

        if let until = pausedUntil {
            if now >= until { resume() } else { state = .pausedManually(until: until); return }
        }
        if let kind = activeReminder {
            state = .showingReminder(kind)
            return
        }
        if activity.isAway {
            state = .away
            overlay.hidePreWarning()
            return
        }

        let idleSeconds = activity.secondsSinceLastInput
        if idleSeconds >= TimeInterval(s.idleThresholdMinutes * 60) {
            wasIdle = true
            lastIdleSeconds = idleSeconds
            state = .idle
            overlay.hidePreWarning()
            return
        } else if wasIdle {
            wasIdle = false
            userReturned(afterBeingAwayFor: lastIdleSeconds)
        }

        // Advance the timers of all enabled reminders.
        for kind in ReminderKind.allCases where s.config(for: kind).isEnabled {
            elapsed[kind, default: 0] += dt
        }
        let due = ReminderKind.allCases.filter {
            let config = s.config(for: $0)
            return config.isEnabled && (elapsed[$0] ?? 0) >= config.intervalSeconds
        }

        if meetings.isInMeeting {
            meetingEndedAt = nil
            wasInMeeting = true
            state = .inMeeting
            overlay.hidePreWarning()
            preWarnedKind = nil
            pending.formUnion(due)
            // Don't keep counting past due while we wait for the meeting to end.
            for kind in due { elapsed[kind] = s.config(for: kind).intervalSeconds }
            return
        }

        state = .running
        if wasInMeeting {
            wasInMeeting = false
            meetingEndedAt = now
        }

        // After a meeting: one combined reminder instead of several in a row. It waits a few
        // seconds so the "Willkommen zurück" notice is seen first.
        if !pending.isEmpty {
            if let ended = meetingEndedAt, now.timeIntervalSince(ended) < Self.afterMeetingDelay {
                return
            }
            let kind = highestPriority(pending.union(due))
            pending.removeAll()
            show(kind, afterMeeting: true)
            return
        }

        if !due.isEmpty {
            show(highestPriority(due), afterMeeting: false)
            return
        }

        updatePreWarning(settings: s)
    }

    private func updatePreWarning(settings s: AppSettings) {
        guard s.preWarningEnabled else { return }
        let lead = TimeInterval(s.preWarningSeconds)
        // Posture is a quick hint itself, so it gets no pre-warning.
        let upcoming = ReminderKind.allCases.filter { $0 != .posture }.filter {
            let config = s.config(for: $0)
            return config.isEnabled && config.intervalSeconds - (elapsed[$0] ?? 0) <= lead
        }
        guard !upcoming.isEmpty else { return }
        let kind = highestPriority(upcoming)
        guard preWarnedKind != kind else { return }
        preWarnedKind = kind
        overlay.showPreWarning(kind: kind, seconds: s.preWarningSeconds, playSound: s.soundEnabled)
    }

    // MARK: - Showing reminders

    private var activeReminder: ReminderKind?

    private func show(_ kind: ReminderKind, afterMeeting: Bool, isPreview: Bool = false) {
        guard activeReminder == nil else { return }
        let s = settings.settings
        activeReminder = kind
        state = .showingReminder(kind)
        overlay.hidePreWarning()
        overlay.show(
            kind: kind,
            message: afterMeeting ? kind.afterMeetingMessage : kind.message,
            duration: TimeInterval(s.config(for: kind).durationSeconds),
            dimming: s.dimming,
            allowSnooze: s.snoozeEnabled,
            snoozeMinutes: s.snoozeMinutes,
            nextInMinutes: s.config(for: kind).intervalMinutes,
            playSound: s.soundEnabled
        ) { [weak self] outcome in
            guard let self else { return }
            if isPreview {
                self.activeReminder = nil
                self.state = .running
            } else {
                self.finish(kind, outcome: outcome)
            }
        }
    }

    private func finish(_ kind: ReminderKind, outcome: OverlayOutcome) {
        let s = settings.settings
        switch outcome {
        case .completed, .skipped:
            // A bigger reminder covers the smaller ones: reset this timer and all lower-priority ones.
            for other in ReminderKind.allCases where other.priority <= kind.priority {
                elapsed[other] = 0
            }
        case .snoozed:
            let snooze = TimeInterval(s.snoozeMinutes * 60)
            for other in ReminderKind.allCases {
                let interval = s.config(for: other).intervalSeconds
                elapsed[other] = min(elapsed[other] ?? 0, max(0, interval - snooze))
            }
        }
        activeReminder = nil
        preWarnedKind = nil
        overlay.hidePreWarning()
        state = .running
    }

    // MARK: - Helpers

    private func pause(until date: Date) {
        pausedUntil = date
        state = .pausedManually(until: date)
        overlay.hidePreWarning()
        preWarnedKind = nil
    }

    /// Being away longer than a full break counts as a break: reset all timers.
    private func userReturned(afterBeingAwayFor seconds: TimeInterval) {
        let breakDuration = TimeInterval(settings.settings.config(for: .rest).durationSeconds)
        if seconds >= breakDuration {
            resetAll()
        }
        lastTick = Date()
    }

    private func resetAll() {
        for kind in ReminderKind.allCases { elapsed[kind] = 0 }
        pending.removeAll()
        preWarnedKind = nil
    }

    private func highestPriority(_ kinds: some Collection<ReminderKind>) -> ReminderKind {
        kinds.max { $0.priority < $1.priority } ?? .eyes
    }
}
