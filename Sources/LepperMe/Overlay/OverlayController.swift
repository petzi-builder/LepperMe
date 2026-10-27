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
    private var preWarningFollow: AnyCancellable?

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

        // Posture is a quick, non-blocking hint, not a break.
        if kind == .posture {
            showPostureHUD(message: message, duration: duration)
            return
        }

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

    // MARK: - Posture HUD

    private var postureHUD: NSPanel?

    /// Small card in the middle of the screen the user is working on. Click-through, auto-dismissing.
    private func showPostureHUD(message: String, duration: TimeInterval) {
        let model = PostureHUDModel(message: message)
        let host = NSHostingView(rootView: PostureHUDView(model: model))
        // Measure first, then freeze the size (sizingOptions = [] makes fittingSize report zero).
        let size = host.fittingSize
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: size)

        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true // never in the way of the user's work
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        if let screen = NSScreen.underMouse ?? NSScreen.main {
            let frame = screen.frame
            panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2))
        }
        panel.orderFrontRegardless()
        postureHUD = panel

        DispatchQueue.main.async { model.visible = true }
        if playSound { sounds.play(.posture) }

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(1, duration) * 1_000_000_000))
            model.visible = false
            try? await Task.sleep(nanoseconds: 450_000_000)
            panel.orderOut(nil)
            guard let self else { return }
            if self.postureHUD === panel { self.postureHUD = nil }
            let completion = self.completion
            self.completion = nil
            completion?(.completed)
        }
    }

    // MARK: - Toast (status messages like "Meeting erkannt")

    private var toastPanel: NSPanel?

    /// Silent pill at the top of the screen the user is working on. Click-through, auto-hiding.
    func showToast(symbol: String, title: String, message: String, duration: TimeInterval = 4) {
        toastPanel?.orderOut(nil)
        let model = ToastModel(symbol: symbol, title: title, message: message)
        let host = NSHostingView(rootView: ToastView(model: model))
        let size = host.fittingSize
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: size)

        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        if let screen = NSScreen.underMouse ?? NSScreen.main {
            let frame = screen.visibleFrame
            let inset = ToastView.shadowPadding
            panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.maxY - size.height + inset - 12))
        }
        panel.orderFrontRegardless()
        toastPanel = panel
        DispatchQueue.main.async { model.visible = true }

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            model.visible = false
            try? await Task.sleep(nanoseconds: 450_000_000)
            panel.orderOut(nil)
            if self?.toastPanel === panel { self?.toastPanel = nil }
        }
    }

    // MARK: - Pre-warning

    func showPreWarning(kind: ReminderKind, seconds: Int, playSound: Bool) {
        hidePreWarning(animated: false)
        let model = PreWarningModel(kind: kind, seconds: seconds)
        preWarningModel = model

        let host = NSHostingView(rootView: PreWarningView(model: model))
        let size = host.fittingSize
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: size)
        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false // the SwiftUI view draws its own soft shadow
        panel.ignoresMouseEvents = true // it travels with the pointer, so it must never catch clicks
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        var origin = Self.originAtMouse(panelSize: size, inset: PreWarningView.shadowPadding)
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
        preWarningPanel = panel

        // Follow the pointer with a slight, smooth lag (polling needs no permissions).
        preWarningFollow = Timer.publish(every: 1.0 / 60, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                let target = Self.originAtMouse(panelSize: size, inset: PreWarningView.shadowPadding)
                let dx = target.x - origin.x, dy = target.y - origin.y
                // Jump when switching displays, glide otherwise.
                if abs(dx) > 600 || abs(dy) > 600 {
                    origin = target
                } else {
                    origin = NSPoint(x: origin.x + dx * 0.35, y: origin.y + dy * 0.35)
                }
                panel.setFrameOrigin(origin)
            }

        // Next run loop pass, so SwiftUI animates from hidden to visible.
        DispatchQueue.main.async { model.visible = true }
        if playSound { sounds.play(.preWarning) }
    }

    /// The card's top-left corner sits just below and right of the pointer tip, like a tooltip.
    /// Near the right or bottom edge it flips to the other side; it always stays on screen.
    static func originAtMouse(panelSize size: NSSize, inset: CGFloat) -> NSPoint {
        let mouse = NSEvent.mouseLocation
        let bounds = (NSScreen.underMouse ?? NSScreen.main)?.visibleFrame ?? NSRect(origin: .zero, size: size)
        let card = NSSize(width: size.width - 2 * inset, height: size.height - 2 * inset)
        let offset = NSPoint(x: 14, y: 24) // clears the arrow cursor

        var cardX = mouse.x + offset.x
        if cardX + card.width > bounds.maxX { cardX = mouse.x - offset.x - card.width }
        var cardTop = mouse.y - offset.y
        if cardTop - card.height < bounds.minY { cardTop = mouse.y + card.height + 8 }

        cardX = min(max(cardX, bounds.minX + 4), bounds.maxX - card.width - 4)
        cardTop = min(max(cardTop, bounds.minY + card.height + 4), bounds.maxY - 4)
        return NSPoint(x: cardX - inset, y: cardTop - card.height - inset)
    }

    func hidePreWarning(animated: Bool = true) {
        preWarningFollow = nil
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

/// Borderless panel for hints (pre-warning, posture, toasts). Its frame includes transparent
/// shadow padding, so AppKit must not nudge it away from screen edges.
final class FloatingPanel: NSPanel {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

extension NSScreen {
    /// The display the user is working on right now (where the mouse pointer is).
    static var underMouse: NSScreen? {
        let location = NSEvent.mouseLocation
        return screens.first { NSMouseInRect(location, $0.frame, false) }
    }
}
