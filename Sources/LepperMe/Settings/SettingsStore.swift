import Foundation
import Combine

struct AppSettings: Codable, Equatable {
    var reminders: [ReminderKind: ReminderConfig] = Dictionary(
        uniqueKeysWithValues: ReminderKind.allCases.map { ($0, $0.defaultConfig) }
    )

    // Overlay
    var dimming: Double = 0.8
    var preWarningEnabled = true
    var preWarningSeconds = 10
    var soundEnabled = true
    var soundVolume: Double = 0.7
    var snoozeEnabled = true
    var snoozeMinutes = 5

    // Meetings
    var detectMicrophone = true
    var detectCamera = true
    var meetingBufferSeconds = 30
    var meetingNoticeEnabled = true
    var meetingApps: [String] = [
        "us.zoom.xos",                 // Zoom
        "com.microsoft.teams2",        // Microsoft Teams (neu)
        "com.microsoft.teams",         // Microsoft Teams (klassisch)
        "com.cisco.webexmeetingsapp",  // Webex
        "Cisco-Systems.Spark",         // Webex App
        "com.tinyspeck.slackmacgap",   // Slack (Huddles)
        "com.apple.FaceTime"           // FaceTime
    ]

    // General
    var launchAtLogin = false
    var idleThresholdMinutes = 5

    func config(for kind: ReminderKind) -> ReminderConfig {
        reminders[kind] ?? kind.defaultConfig
    }

    init() {}

    // Tolerant decoding: missing keys (e.g. after an update adds a setting) fall back to defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        reminders = (try? c.decode([ReminderKind: ReminderConfig].self, forKey: .reminders)) ?? d.reminders
        dimming = (try? c.decode(Double.self, forKey: .dimming)) ?? d.dimming
        preWarningEnabled = (try? c.decode(Bool.self, forKey: .preWarningEnabled)) ?? d.preWarningEnabled
        preWarningSeconds = (try? c.decode(Int.self, forKey: .preWarningSeconds)) ?? d.preWarningSeconds
        soundEnabled = (try? c.decode(Bool.self, forKey: .soundEnabled)) ?? d.soundEnabled
        soundVolume = (try? c.decode(Double.self, forKey: .soundVolume)) ?? d.soundVolume
        snoozeEnabled = (try? c.decode(Bool.self, forKey: .snoozeEnabled)) ?? d.snoozeEnabled
        snoozeMinutes = (try? c.decode(Int.self, forKey: .snoozeMinutes)) ?? d.snoozeMinutes
        detectMicrophone = (try? c.decode(Bool.self, forKey: .detectMicrophone)) ?? d.detectMicrophone
        detectCamera = (try? c.decode(Bool.self, forKey: .detectCamera)) ?? d.detectCamera
        meetingBufferSeconds = (try? c.decode(Int.self, forKey: .meetingBufferSeconds)) ?? d.meetingBufferSeconds
        meetingNoticeEnabled = (try? c.decode(Bool.self, forKey: .meetingNoticeEnabled)) ?? d.meetingNoticeEnabled
        meetingApps = (try? c.decode([String].self, forKey: .meetingApps)) ?? d.meetingApps
        launchAtLogin = (try? c.decode(Bool.self, forKey: .launchAtLogin)) ?? d.launchAtLogin
        idleThresholdMinutes = (try? c.decode(Int.self, forKey: .idleThresholdMinutes)) ?? d.idleThresholdMinutes
    }
}

/// Loads and persists `AppSettings` in `UserDefaults`.
@MainActor
final class SettingsStore: ObservableObject {
    private static let key = "LepperMe.settings.v1"
    private let defaults: UserDefaults

    @Published var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            save()
            if settings.launchAtLogin != oldValue.launchAtLogin {
                LoginItem.setEnabled(settings.launchAtLogin)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = AppSettings()
        }
    }

    func resetToDefaults() {
        settings = AppSettings()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
