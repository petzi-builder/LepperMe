import AppKit
import Combine
import SwiftUI

/// Menu bar icon and menu. The icon is a small ring that fills up towards the next reminder.
/// The menu is rebuilt each time it opens so the remaining time is current.
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let scheduler: ReminderScheduler
    private let openSettings: () -> Void
    private var cancellables = Set<AnyCancellable>()
    private var lastIconKey = ""

    init(scheduler: ReminderScheduler, openSettings: @escaping () -> Void) {
        self.scheduler = scheduler
        self.openSettings = openSettings
        super.init()

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.toolTip = "LepperMe"

        scheduler.$elapsed
            .combineLatest(scheduler.$state)
            .sink { [weak self] _, _ in self?.updateIcon() }
            .store(in: &cancellables)
    }

    // MARK: - Icon

    private func updateIcon() {
        let state = scheduler.state
        // "8" = revel8 mark; otherwise an SF Symbol for special states.
        let glyph: String
        switch state {
        case .inMeeting:
            glyph = "video.fill"
        case .pausedManually:
            glyph = "pause.fill"
        default:
            glyph = "8"
        }
        let progress: Double
        if case .showingReminder = state { progress = 1 } else { progress = scheduler.nextReminderProgress }
        // Only redraw when something visible changes (36 steps around the ring).
        let step = Int((progress * 36).rounded())
        let key = "\(glyph)-\(step)"
        guard key != lastIconKey else { return }
        lastIconKey = key

        statusItem.button?.image = Self.icon(glyph: glyph, progress: Double(step) / 36)
    }

    private static func icon(glyph: String, progress: Double?) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let symbolConfig = NSImage.SymbolConfiguration(pointSize: 7, weight: .bold)
            if let progress {
                let inset = rect.insetBy(dx: 1.5, dy: 1.5)
                let track = NSBezierPath(ovalIn: inset)
                track.lineWidth = 1.6
                NSColor.black.withAlphaComponent(0.3).setStroke()
                track.stroke()

                if progress > 0 {
                    let arc = NSBezierPath()
                    let center = NSPoint(x: rect.midX, y: rect.midY)
                    arc.appendArc(
                        withCenter: center, radius: inset.width / 2,
                        startAngle: 90, endAngle: 90 - 360 * progress, clockwise: true
                    )
                    arc.lineWidth = 1.8
                    arc.lineCapStyle = .round
                    NSColor.black.setStroke()
                    arc.stroke()
                }
            }
            if glyph == "8" {
                drawEight(in: NSRect(x: rect.midX - 3.6, y: rect.midY - 5.2, width: 7.2, height: 10.4))
            } else if let symbol = NSImage(systemSymbolName: glyph, accessibilityDescription: nil)?
                .withSymbolConfiguration(symbolConfig) {
                let s = symbol.size
                symbol.draw(in: NSRect(x: rect.midX - s.width / 2, y: rect.midY - s.height / 2, width: s.width, height: s.height))
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "LepperMe"
        return image
    }

    /// The revel8 "8" as a template drawing: solid front stroke, half-transparent back stroke.
    private static func drawEight(in rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        // Flip into SVG's top-left coordinate space.
        context.saveGState()
        context.translateBy(x: 0, y: rect.minY * 2 + rect.height)
        context.scaleBy(x: 1, y: -1)
        let back = SVGShape(Brand.eightBack, viewBox: Brand.eightViewBox).path(in: rect).cgPath
        let front = SVGShape(Brand.eightFront, viewBox: Brand.eightViewBox).path(in: rect).cgPath
        context.setFillColor(NSColor.black.withAlphaComponent(0.45).cgColor)
        context.addPath(back)
        context.fillPath()
        context.setFillColor(NSColor.black.cgColor)
        context.addPath(front)
        context.fillPath()
        context.restoreGState()
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        for line in statusLines() {
            let item = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(.separator())

        menu.addItem(item("Jetzt Pause machen", #selector(takeBreak), symbol: "cup.and.saucer"))

        if scheduler.isPausedManually {
            menu.addItem(item("Fortsetzen", #selector(resume), symbol: "play"))
        } else {
            let pauseItem = NSMenuItem(title: "Pausieren", action: nil, keyEquivalent: "")
            pauseItem.image = NSImage(systemSymbolName: "pause", accessibilityDescription: nil)
            let submenu = NSMenu()
            submenu.addItem(item("30 Minuten", #selector(pause30)))
            submenu.addItem(item("1 Stunde", #selector(pause60)))
            submenu.addItem(item("Bis morgen", #selector(pauseTomorrow)))
            pauseItem.submenu = submenu
            menu.addItem(pauseItem)
        }

        menu.addItem(.separator())
        menu.addItem(item("Einstellungen …", #selector(settings), key: ",", symbol: "gearshape"))
        menu.addItem(item("LepperMe beenden", #selector(quit), key: "q", symbol: "power"))
    }

    private func statusLines() -> [String] {
        var lines: [String] = []
        switch scheduler.state {
        case .pausedManually(let until):
            let formatter = DateFormatter()
            formatter.dateStyle = Calendar.current.isDateInToday(until) ? .none : .short
            formatter.timeStyle = .short
            lines.append("Pausiert bis \(formatter.string(from: until))")
        case .inMeeting:
            lines.append("Meeting erkannt. Erinnerungen pausiert.")
        case .idle, .away:
            lines.append("Inaktiv. Timer angehalten.")
        case .showingReminder(let kind):
            lines.append("\(kind.title) läuft")
        case .running:
            break
        }

        if case .pausedManually = scheduler.state {
            // No countdown while paused.
        } else if let next = scheduler.nextReminder {
            let minutes = Int(ceil(next.remaining / 60))
            lines.append(minutes <= 1 ? "\(next.kind.title) in unter 1 Min." : "\(next.kind.title) in \(minutes) Min.")
        } else {
            lines.append("Alle Erinnerungen sind aus")
        }

        if !scheduler.pending.isEmpty {
            let titles = ReminderKind.byPriority.filter(scheduler.pending.contains).map(\.title)
            lines.append("Nach dem Meeting: \(titles.joined(separator: ", "))")
        }
        return lines
    }

    private func item(_ title: String, _ action: Selector, key: String = "", symbol: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        if let symbol {
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        return item
    }

    // MARK: - Actions

    @objc private func takeBreak() { scheduler.takeBreakNow() }
    @objc private func resume() { scheduler.resume() }
    @objc private func pause30() { scheduler.pause(for: 30 * 60) }
    @objc private func pause60() { scheduler.pause(for: 60 * 60) }
    @objc private func pauseTomorrow() { scheduler.pauseUntilTomorrow() }
    @objc private func settings() { openSettings() }
    @objc private func quit() { NSApp.terminate(nil) }
}
