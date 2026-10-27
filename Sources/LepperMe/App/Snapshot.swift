import AppKit
import SwiftUI

/// Dev helper: `LepperMe --snapshot <dir>` renders the main screens to PNG files and quits.
/// Useful for design reviews without screen-recording permission.
@MainActor
enum Snapshot {
    static func run(into directory: URL, settings: SettingsStore) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for kind in ReminderKind.allCases where kind != .posture {
            let model = OverlayModel(kind: kind, message: kind.message,
                                     duration: TimeInterval(kind.defaultConfig.durationSeconds),
                                     allowSnooze: true, snoozeMinutes: 5)
            write(OverlayView(model: model, dimming: settings.settings.dimming, screenSize: CGSize(width: 1440, height: 900), snapshot: true)
                    .background(fakeDesktop),
                  size: CGSize(width: 1440, height: 900), to: directory.appendingPathComponent("overlay-\(kind.rawValue).png"))
        }

        // Typical display shapes for multi-monitor setups: small, laptop, 1440p, 5K, portrait.
        let screens: [(String, CGSize)] = [
            ("1280x720", CGSize(width: 1280, height: 720)),
            ("1470x956", CGSize(width: 1470, height: 956)),
            ("2560x1440", CGSize(width: 2560, height: 1440)),
            ("2560x1600", CGSize(width: 2560, height: 1600)),
            ("1080x1920", CGSize(width: 1080, height: 1920))
        ]
        for (name, size) in screens {
            let model = OverlayModel(kind: .rest, message: ReminderKind.rest.message, duration: 300,
                                     allowSnooze: true, snoozeMinutes: 5)
            write(OverlayView(model: model, dimming: settings.settings.dimming, screenSize: size, snapshot: true)
                    .background(fakeDesktop),
                  size: size, scale: 1, to: directory.appendingPathComponent("screen-\(name).png"))
        }

        let done = OverlayModel(kind: .eyes, message: ReminderKind.eyes.message, duration: 20,
                                allowSnooze: true, snoozeMinutes: 5)
        done.completedMessage = "Nächste Augenpause in 20 Min."
        done.phase = .completed
        write(OverlayView(model: done, dimming: settings.settings.dimming, screenSize: CGSize(width: 1440, height: 900), snapshot: true).background(fakeDesktop),
              size: CGSize(width: 1440, height: 900), to: directory.appendingPathComponent("overlay-completed.png"))

        let posture = PostureHUDModel(message: ReminderKind.posture.message)
        posture.visible = true
        posture.start = Date().addingTimeInterval(-2.4)
        write(PostureHUDView(model: posture).frame(maxWidth: .infinity, maxHeight: .infinity).background(fakeDesktop),
              size: CGSize(width: 1000, height: 640), to: directory.appendingPathComponent("posture-hud.png"))

        let toast = ToastModel(symbol: "video.fill", title: "Meeting erkannt", message: "Keine Erinnerungen, bis es vorbei ist.")
        toast.visible = true
        write(ToastView(model: toast).background(fakeDesktop),
              size: CGSize(width: 420, height: 120), to: directory.appendingPathComponent("meeting-toast.png"))

        let warning = PreWarningModel(kind: .eyes, seconds: 10)
        warning.visible = true
        write(PreWarningView(model: warning).background(fakeDesktop),
              size: CGSize(width: 300, height: 100), to: directory.appendingPathComponent("prewarning.png"))

        for tab in SettingsView.Tab.allCases {
            write(SettingsView(store: settings, initialTab: tab, snapshot: true, previewBreak: { _ in }, previewSound: {}),
                  size: CGSize(width: 600, height: 1000), to: directory.appendingPathComponent("settings-\(tab).png"))
        }
    }

    /// 1024 × 1024 app icon (macOS grid: 824 pt tile with 100 pt margin), used by `make icon`.
    static func renderIcon(to url: URL) {
        let icon = ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(Theme.backgroundCanvas)
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(Theme.brandGradient)
                .opacity(0.85)
                .mask(
                    RadialGradient(colors: [.white, .clear], center: .bottomTrailing, startRadius: 40, endRadius: 820)
                )
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 4)
            RevelEight()
                .frame(height: 470)
                .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
        }
        .frame(width: 824, height: 824)
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .frame(width: 1024, height: 1024)

        let renderer = ImageRenderer(content: icon)
        renderer.scale = 1
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }

    private static var fakeDesktop: some View {
        LinearGradient(colors: [Color(hex: 0xC9D6DF), Color(hex: 0x8FA6B5)], startPoint: .top, endPoint: .bottom)
    }

    private static func write<V: View>(_ view: V, size: CGSize, scale: CGFloat = 2, to url: URL) {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height, alignment: .top)
            .environment(\.colorScheme, .dark))
        renderer.scale = scale
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            NSLog("LepperMe: snapshot failed for \(url.lastPathComponent)")
            return
        }
        try? png.write(to: url)
    }
}
