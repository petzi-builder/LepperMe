import AppKit
import Combine
import SwiftUI

enum OverlayPhase: Equatable {
    case running
    case completed
    case leaving
}

/// State shared by the overlay windows on all screens.
@MainActor
final class OverlayModel: ObservableObject {
    let kind: ReminderKind
    let message: String
    let duration: TimeInterval
    let allowSnooze: Bool
    let snoozeMinutes: Int
    let reduceMotion: Bool
    let endDate: Date
    /// Shown once the countdown is done, e.g. "Nächste Augenpause in 20 Min."
    var completedMessage = ""
    @Published var phase: OverlayPhase = .running

    var onSkip: () -> Void = {}
    var onSnooze: () -> Void = {}

    init(kind: ReminderKind, message: String, duration: TimeInterval, allowSnooze: Bool, snoozeMinutes: Int) {
        self.kind = kind
        self.message = message
        self.duration = duration
        self.allowSnooze = allowSnooze
        self.snoozeMinutes = snoozeMinutes
        self.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        self.endDate = Date().addingTimeInterval(duration)
    }

    func remaining(at date: Date) -> TimeInterval {
        max(0, endDate.timeIntervalSince(date))
    }

    func progress(at date: Date) -> Double {
        duration > 0 ? 1 - remaining(at: date) / duration : 1
    }
}

/// Shows the full-screen break overlay on every connected display, plus the small pre-warning banner.
@MainActor
final class OverlayController {
    private let sounds: SoundEngine
    private var windows: [OverlayWindow] = []
    private var model: OverlayModel?
    private var countdown: AnyCancellable?
    private var completion: ((OverlayOutcome) -> Void)?
    private var previousApp: NSRunningApplication?
    private var playSound = true
    private var dimming = 0.8
    private var screenObserver: AnyCancellable?

    private var preWarningPanel: NSPanel?
    private var preWarningModel: PreWarningModel?

    init(sounds: SoundEngine) {
        self.sounds = sounds
    }

    // MARK: - Overlay

    func show(
        kind: ReminderKind,
        message: String,
        duration: TimeInterval,
        dimming: Double,
        allowSnooze: Bool,
        snoozeMinutes: Int,
        nextInMinutes: Int,
        playSound: Bool,
        completion: @escaping (OverlayOutcome) -> Void
    ) {
        dismiss(animated: false)
        self.completion = completion
        self.playSound = playSound

        let model = OverlayModel(
            kind: kind, message: message, duration: duration,
            allowSnooze: allowSnooze, snoozeMinutes: snoozeMinutes
        )
        model.completedMessage = "\(kind.nextLabel) in \(nextInMinutes) Min."
        model.onSkip = { [weak self] in self?.finish(.skipped) }
        model.onSnooze = { [weak self] in self?.finish(.snoozed) }
        self.model = model

        self.dimming = dimming
        previousApp = NSWorkspace.shared.frontmostApplication
        buildWindows(for: model, fadeIn: true)
        if playSound { sounds.play(.breakStart) }

        countdown = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                guard let self, let model = self.model, model.phase == .running else { return }
                if model.remaining(at: now) <= 0 { self.complete() }
            }

        if let dir = ProcessInfo.processInfo.environment["LEPPERME_DEBUG_LAYOUT"] {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self?.dumpLayout(to: URL(fileURLWithPath: dir))
            }
        }
    }

    /// Dev aid: logs window vs. screen frames and saves what each overlay window really draws.
    private func dumpLayout(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (i, window) in windows.enumerated() {
            let screen = window.screen
            NSLog("LepperMe layout: window \(i): frame=\(window.frame) screen=\(screen?.frame ?? .zero) visible=\(screen?.visibleFrame ?? .zero) scale=\(screen?.backingScaleFactor ?? 0) content=\(window.contentView?.frame ?? .zero)")
            guard let view = window.contentView,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("window-\(i).png"))
        }
    }

    /// One overlay window per connected screen. The key window (for Escape) is the one under the mouse.
    private func buildWindows(for model: OverlayModel, fadeIn: Bool) {
        for screen in NSScreen.screens {
            let window = OverlayWindow(screen: screen)
            window.onEscape = { [weak self] in self?.finish(.skipped) }
            let host = NSHostingView(rootView: OverlayView(model: model, dimming: dimming, screenSize: screen.frame.size))
            // Never let SwiftUI resize the window: it must cover exactly this screen.
            host.sizingOptions = []
            host.frame = NSRect(origin: .zero, size: screen.frame.size)
            window.contentView = host
            window.setFrame(screen.frame, display: true)
            window.alphaValue = fadeIn ? 0 : 1
            window.orderFrontRegardless()
            windows.append(window)
        }
        // Become active so Escape reaches us. Focus goes back to `previousApp` afterwards.
        NSApp.activate(ignoringOtherApps: true)
        let active = NSScreen.underMouse
        (windows.first { $0.screen == active } ?? windows.first)?.makeKeyAndOrderFront(nil)

        if fadeIn {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.8
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
                windows.forEach { $0.animator().alphaValue = 1 }
            }
        }

        // Displays plugged in, removed or rearranged mid-break: rebuild for the new layout.
        screenObserver = NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildForScreenChange() }
    }

    private func rebuildForScreenChange() {
        guard let model, model.phase != .leaving else { return }
        windows.forEach { $0.orderOut(nil) }
        windows = []
        buildWindows(for: model, fadeIn: false)
    }

    /// Countdown ran out: show the check mark for a moment, then fade out.
    private func complete() {
        guard let model else { return }
        countdown = nil
        model.phase = .completed
        if playSound { sounds.play(.breakEnd) }
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            self?.finish(.completed)
        }
    }

    private func finish(_ outcome: OverlayOutcome) {
        guard let completion else { return }
        self.completion = nil
        switch outcome {
        case .skipped where playSound: sounds.play(.skip)
        case .snoozed where playSound: sounds.play(.snooze)
        default: break
        }
        dismiss(animated: true)
        completion(outcome)
    }

    private func dismiss(animated: Bool) {
        countdown = nil
        screenObserver = nil
        model?.phase = .leaving
        model = nil
        let closing = windows
        windows = []
        guard !closing.isEmpty else { return }

        if animated {
            let fade = 0.55
            NSAnimationContext.runAnimationGroup { context in
                context.duration = fade
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                closing.forEach { $0.animator().alphaValue = 0 }
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(fade * 1_000_000_000))
                closing.forEach { $0.orderOut(nil) }
            }
        } else {
            closing.forEach { $0.orderOut(nil) }
        }
        previousApp?.activate()
        previousApp = nil
    }

    // MARK: - Pre-warning

    func showPreWarning(
        kind: ReminderKind,
        seconds: Int,
        allowSnooze: Bool,
        snoozeMinutes: Int,
        playSound: Bool,
        onSkip: @escaping () -> Void,
        onSnooze: @escaping () -> Void
    ) {
        hidePreWarning(animated: false)
        let model = PreWarningModel(kind: kind, seconds: seconds, allowSnooze: allowSnooze, snoozeMinutes: snoozeMinutes)
        model.onSkip = { [weak self] in self?.hidePreWarning(); onSkip() }
        model.onSnooze = { [weak self] in self?.hidePreWarning(); onSnooze() }
        preWarningModel = model

        let host = FirstMouseHostingView(rootView: PreWarningView(model: model))
        let size = host.fittingSize
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false // the SwiftUI view draws its own soft shadow
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        if let screen = NSScreen.underMouse ?? NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.maxY - size.height))
        }
        panel.orderFrontRegardless()
        preWarningPanel = panel

        // Next run loop pass, so SwiftUI animates from hidden to visible.
        DispatchQueue.main.async { model.visible = true }
        if playSound { sounds.play(.preWarning) }
    }

    func hidePreWarning(animated: Bool = true) {
        guard let panel = preWarningPanel else { return }
        preWarningPanel = nil
        let model = preWarningModel
        preWarningModel = nil
        guard animated else { panel.orderOut(nil); return }
        model?.visible = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            panel.orderOut(nil)
        }
    }
}

// MARK: - Windows

/// Borderless window above everything, on all Spaces and over full-screen apps.
final class OverlayWindow: NSWindow {
    var onEscape: (() -> Void)?

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = false
        appearance = NSAppearance(named: .darkAqua)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// AppKit would push the window below the menu bar; it has to cover the whole screen.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape?() } else { super.keyDown(with: event) }
    }
}

/// Lets buttons in a non-activating panel react to the first click.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

extension NSScreen {
    /// The display the user is working on right now (where the mouse pointer is).
    static var underMouse: NSScreen? {
        let location = NSEvent.mouseLocation
        return screens.first { NSMouseInRect(location, $0.frame, false) }
    }
}
