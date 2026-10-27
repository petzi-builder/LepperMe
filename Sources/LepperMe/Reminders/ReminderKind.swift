import Foundation

/// The three reminder types. Higher `priority` wins when several are due at once.
enum ReminderKind: String, CaseIterable, Codable, CodingKeyRepresentable, Identifiable {
    case eyes
    case posture
    case rest

    var id: String { rawValue }

    /// Pause > Augenpause > Haltung
    var priority: Int {
        switch self {
        case .rest: return 3
        case .eyes: return 2
        case .posture: return 1
        }
    }

    var title: String {
        switch self {
        case .eyes: return "Augenpause"
        case .posture: return "Haltung"
        case .rest: return "Pause"
        }
    }

    /// "Nächste Augenpause", "Nächster Haltungscheck" (German needs the right article form).
    var nextLabel: String {
        switch self {
        case .eyes: return "Nächste Augenpause"
        case .posture: return "Nächster Haltungscheck"
        case .rest: return "Nächste Pause"
        }
    }

    /// Short context label shown above the break ring.
    var badge: String {
        switch self {
        case .eyes: return "20-20-20-Regel"
        case .posture: return "Haltungscheck"
        case .rest: return "Bewegungspause"
        }
    }

    var message: String {
        switch self {
        case .eyes: return "Schau 20 Sekunden auf etwas, das etwa 6 Meter entfernt ist."
        case .posture: return "Richte dich auf: Schultern zurück, Füße flach, Bildschirm auf Augenhöhe."
        case .rest: return "Steh auf, beweg dich, trink etwas Wasser."
        }
    }

    var afterMeetingMessage: String {
        switch self {
        case .eyes: return "Dein Meeting ist vorbei. Gönn deinen Augen eine kurze Pause."
        case .posture: return "Dein Meeting ist vorbei. Zeit, die Haltung zu korrigieren."
        case .rest: return "Dein Meeting ist vorbei. Zeit für eine kurze Pause."
        }
    }

    /// SF Symbol name.
    var symbol: String {
        switch self {
        case .eyes: return "eye"
        case .posture: return "figure.stand"
        case .rest: return "cup.and.saucer"
        }
    }

    /// Recommended defaults. All values are user-configurable in the settings.
    var defaultConfig: ReminderConfig {
        switch self {
        case .eyes: return ReminderConfig(isEnabled: true, intervalMinutes: 20, durationSeconds: 20)
        case .posture: return ReminderConfig(isEnabled: true, intervalMinutes: 30, durationSeconds: 10)
        case .rest: return ReminderConfig(isEnabled: true, intervalMinutes: 60, durationSeconds: 5 * 60)
        }
    }

    static var byPriority: [ReminderKind] {
        allCases.sorted { $0.priority > $1.priority }
    }
}

struct ReminderConfig: Codable, Equatable {
    var isEnabled: Bool
    var intervalMinutes: Int
    var durationSeconds: Int

    var intervalSeconds: TimeInterval { TimeInterval(intervalMinutes * 60) }
}
