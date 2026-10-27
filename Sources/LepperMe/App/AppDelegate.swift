import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private let sounds = SoundEngine()
    private lazy var meetings = MeetingDetector(settings: settings)
    private let activity = ActivityMonitor()
    private lazy var overlay = OverlayController(sounds: sounds)
    private lazy var scheduler = ReminderScheduler(
        settings: settings,
        meetings: meetings,
        activity: activity,
        overlay: overlay
    )
    private var statusBar: StatusBarController?
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only, no Dock icon (also set via LSUIElement in Info.plist).
        NSApp.setActivationPolicy(.accessory)
        FontLoader.registerBundledFonts()

        settings.$settings
            .map { Float($0.soundEnabled ? $0.soundVolume : 0) }
            .removeDuplicates()
            .sink { [weak self] volume in self?.sounds.volume = volume }
            .store(in: &cancellables)

        meetings.start()
        activity.start()
        scheduler.start()
        observeMeetings()

        statusBar = StatusBarController(scheduler: scheduler) { [weak self] in
            self?.showSettings()
        }
        handleDevArguments()
    }

    /// Dev helpers: `--preview eyes|posture|rest` shows an overlay right away, `--settings` opens the settings.
    private func handleDevArguments() {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--render-icon"), i + 1 < args.count {
            Snapshot.renderIcon(to: URL(fileURLWithPath: args[i + 1]))
            NSApp.terminate(nil)
            return
        }
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            Snapshot.run(into: URL(fileURLWithPath: args[i + 1]), settings: settings)
            NSApp.terminate(nil)
            return
        }
        if let i = args.firstIndex(of: "--preview"), i + 1 < args.count,
           let kind = ReminderKind(rawValue: args[i + 1]) {
            scheduler.preview(kind)
        }
        if args.contains("--prewarning") {
            let s = settings.settings
            overlay.showPreWarning(kind: .eyes, seconds: s.preWarningSeconds, playSound: s.soundEnabled)
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(s.preWarningSeconds) * 1_000_000_000)
                self?.overlay.hidePreWarning()
            }
        }
        if args.contains("--meeting-toast") {
            overlay.showToast(symbol: "video.fill", title: "Meeting erkannt", message: "Keine Erinnerungen, bis es vorbei ist.")
        }
        if args.contains("--play-sounds") {
            Task { @MainActor in
                for cue in SoundEngine.Cue.allCases {
                    sounds.play(cue)
                    try? await Task.sleep(nanoseconds: 2_200_000_000)
                }
            }
        }
        if args.contains("--settings") {
            showSettings()
        }
    }

    /// Tell the user when a meeting is detected, so they know they won't be interrupted.
    private func observeMeetings() {
        meetings.$isInMeeting
            .removeDuplicates()
            .dropFirst() // initial value, not a change
            .sink { [weak self] inMeeting in
                guard let self, self.settings.settings.meetingNoticeEnabled else { return }
                if inMeeting {
                    self.overlay.showToast(
                        symbol: "video.fill",
                        title: "Meeting erkannt",
                        message: "Keine Erinnerungen, bis es vorbei ist."
                    )
                } else if self.scheduler.pending.isEmpty {
                    // With reminders waiting, the combined reminder itself shows up right away instead.
                    self.overlay.showToast(
                        symbol: "checkmark",
                        title: "Meeting beendet",
                        message: "Erinnerungen laufen wieder."
                    )
                }
            }
            .store(in: &cancellables)
    }

    private func showSettings() {
        if settingsWindow == nil {
            let view = SettingsView(
                store: settings,
                previewBreak: { [weak self] kind in
                    self?.settingsWindow?.orderOut(nil)
                    self?.scheduler.preview(kind)
                },
                previewSound: { [weak self] in self?.sounds.play(.breakEnd) }
            )
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Einstellungen"
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.backgroundColor = NSColor(Theme.backgroundCanvas)
            window.appearance = NSAppearance(named: .darkAqua)
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
