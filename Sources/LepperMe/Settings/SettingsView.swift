import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    let previewBreak: (ReminderKind) -> Void
    let previewSound: () -> Void

    enum Tab: Hashable, CaseIterable { case reminders, overlay, meetings, general }
    @State private var tab: Tab

    /// Dev snapshots: ImageRenderer can't draw ScrollView content.
    var snapshot = false

    init(store: SettingsStore, initialTab: Tab = .reminders, snapshot: Bool = false,
         previewBreak: @escaping (ReminderKind) -> Void, previewSound: @escaping () -> Void) {
        self.store = store
        self.snapshot = snapshot
        self.previewBreak = previewBreak
        self.previewSound = previewSound
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if snapshot {
                tabContent.padding(.horizontal, Theme.Space.s24)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    tabContent
                        .padding(.horizontal, Theme.Space.s24)
                        .padding(.bottom, Theme.Space.s24)
                        .transition(.opacity.combined(with: .offset(y: 6)))
                        .id(tab)
                }
                .scrollIndicators(.never)
            }
        }
        .frame(width: 600, height: snapshot ? nil : 620)
        .background(Theme.backgroundCanvas)
        .environment(\.colorScheme, .dark)
        .tint(Theme.accent)
        .toggleStyle(RToggleStyle())
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .reminders: RemindersTab(store: store, previewBreak: previewBreak)
        case .overlay: OverlayTab(settings: $store.settings, previewSound: previewSound)
        case .meetings: MeetingsTab(settings: $store.settings)
        case .general: GeneralTab(store: store)
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Space.s16) {
            HStack(spacing: Theme.Space.s12) {
                AppMark().frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("LepperMe")
                        .font(Theme.headingLarge)
                        .tracking(-0.96)
                        .foregroundStyle(Theme.contentPrimary)
                    Text("Pausen für Augen, Haltung und Kopf")
                        .font(Theme.bodyMedium)
                        .foregroundStyle(Theme.contentSubdued)
                }
                Spacer()
            }
            PillTabs(tabs: [
                (Tab.reminders, "Erinnerungen", "bell"),
                (Tab.overlay, "Overlay", "sparkles"),
                (Tab.meetings, "Meetings", "video"),
                (Tab.general, "Allgemein", "gearshape")
            ], selection: $tab)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Theme.Space.s24)
        .padding(.top, 36) // room for the transparent title bar
        .padding(.bottom, Theme.Space.s16)
    }
}

/// Small brand mark: gradient tile with the eye glyph.
struct AppMark: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Theme.brandGradient)
            .overlay(RevelEight().padding(8))
            .shadow(color: Theme.purple600.opacity(0.45), radius: 10, y: 4)
    }
}

// MARK: - Erinnerungen

private struct RemindersTab: View {
    @ObservedObject var store: SettingsStore
    let previewBreak: (ReminderKind) -> Void

    var body: some View {
        VStack(spacing: Theme.Space.s16) {
            ForEach(ReminderKind.allCases) { kind in
                Card(kind.title, systemImage: kind.symbol) {
                    SettingRow(label: "Aktiv") {
                        Toggle("", isOn: binding(kind, \.isEnabled)).labelsHidden()
                    }
                    RowDivider()
                    SettingRow(label: "Intervall", hint: "Empfohlen: \(kind.defaultConfig.intervalMinutes) Min.") {
                        ValueStepper(value: binding(kind, \.intervalMinutes), range: 1...240) { "\($0) Min." }
                    }
                    .disabled(!config(kind).isEnabled)
                    RowDivider()
                    SettingRow(label: "Dauer", hint: "Empfohlen: \(Self.duration(kind.defaultConfig.durationSeconds))") {
                        durationStepper(kind)
                    }
                    .disabled(!config(kind).isEnabled)
                    RowDivider()
                    HStack {
                        Spacer()
                        Button("\(kind.title) testen") { previewBreak(kind) }
                            .buttonStyle(RButtonStyle(kind: .ghost))
                    }
                    .padding(.horizontal, Theme.Space.s8)
                    .padding(.vertical, 6)
                }
                .opacity(config(kind).isEnabled ? 1 : 0.6)
                .animation(.easeOut(duration: 0.2), value: config(kind).isEnabled)
            }

            Button("Empfohlene Werte wiederherstellen") {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    for kind in ReminderKind.allCases {
                        store.settings.reminders[kind] = kind.defaultConfig
                    }
                }
            }
            .buttonStyle(RButtonStyle(kind: .secondary))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func durationStepper(_ kind: ReminderKind) -> some View {
        if kind == .rest {
            // Breaks are configured in minutes.
            ValueStepper(value: Binding(
                get: { config(kind).durationSeconds / 60 },
                set: { store.settings.reminders[kind, default: kind.defaultConfig].durationSeconds = $0 * 60 }
            ), range: 1...30) { "\($0) Min." }
        } else if kind == .posture {
            // A quick hint, not a break: a few seconds are enough.
            ValueStepper(value: binding(kind, \.durationSeconds), range: 3...30) { "\($0) Sek." }
        } else {
            ValueStepper(value: binding(kind, \.durationSeconds), range: 5...120, step: 5) { "\($0) Sek." }
        }
    }

    private func config(_ kind: ReminderKind) -> ReminderConfig {
        store.settings.config(for: kind)
    }

    private func binding<T>(_ kind: ReminderKind, _ keyPath: WritableKeyPath<ReminderConfig, T>) -> Binding<T> {
        Binding(
            get: { store.settings.config(for: kind)[keyPath: keyPath] },
            set: { store.settings.reminders[kind, default: kind.defaultConfig][keyPath: keyPath] = $0 }
        )
    }

    static func duration(_ seconds: Int) -> String {
        seconds >= 60 ? "\(seconds / 60) Min." : "\(seconds) Sek."
    }
}

// MARK: - Overlay

private struct OverlayTab: View {
    @Binding var settings: AppSettings
    let previewSound: () -> Void

    var body: some View {
        VStack(spacing: Theme.Space.s16) {
            Card("Darstellung", systemImage: "circle.lefthalf.filled") {
                SettingRow(label: "Abdunklung") {
                    RSlider(value: $settings.dimming, range: 0.4...0.95, width: 200)
                }
            }

            Card("Töne", systemImage: "speaker.wave.2") {
                SettingRow(label: "Töne abspielen", hint: "Beim Start, am Ende und bei der Vorwarnung") {
                    Toggle("", isOn: $settings.soundEnabled).labelsHidden()
                }
                RowDivider()
                SettingRow(label: "Lautstärke") {
                    HStack(spacing: Theme.Space.s8) {
                        RSlider(value: $settings.soundVolume, range: 0.05...1, width: 160)
                        Button("Anhören", action: previewSound)
                            .buttonStyle(RButtonStyle(kind: .ghost))
                    }
                }
                .disabled(!settings.soundEnabled)
            }

            Card("Vorwarnung", systemImage: "bell.badge") {
                SettingRow(label: "Kurz vorher ankündigen") {
                    Toggle("", isOn: $settings.preWarningEnabled).labelsHidden()
                }
                RowDivider()
                SettingRow(label: "Vorlauf") {
                    ValueStepper(value: $settings.preWarningSeconds, range: 3...60) { "\($0) Sek." }
                }
                .disabled(!settings.preWarningEnabled)
            }

            Card("Später erinnern", systemImage: "clock.arrow.circlepath") {
                SettingRow(label: "Verschieben erlauben") {
                    Toggle("", isOn: $settings.snoozeEnabled).labelsHidden()
                }
                RowDivider()
                SettingRow(label: "Verschieben um") {
                    ValueStepper(value: $settings.snoozeMinutes, range: 1...30) { "\($0) Min." }
                }
                .disabled(!settings.snoozeEnabled)
            }
        }
    }
}

// MARK: - Meetings

private struct MeetingsTab: View {
    @Binding var settings: AppSettings
    @State private var newBundleID = ""

    var body: some View {
        VStack(spacing: Theme.Space.s16) {
            Card("Erkennung", systemImage: "waveform") {
                SettingRow(label: "Mikrofon in Benutzung") {
                    Toggle("", isOn: $settings.detectMicrophone).labelsHidden()
                }
                RowDivider()
                SettingRow(label: "Kamera in Benutzung") {
                    Toggle("", isOn: $settings.detectCamera).labelsHidden()
                }
                RowDivider()
                SettingRow(label: "Puffer nach Meeting-Ende", hint: "Kurzes Stummschalten beendet kein Meeting") {
                    ValueStepper(value: $settings.meetingBufferSeconds, range: 0...300, step: 10) { "\($0) Sek." }
                }
                RowDivider()
                SettingRow(label: "Hinweis bei Meeting-Beginn und -Ende", hint: "Kurz und ohne Ton, oben auf dem Bildschirm") {
                    Toggle("", isOn: $settings.meetingNoticeEnabled).labelsHidden()
                }
            }

            Card("Meeting-Apps", systemImage: "app.badge") {
                ForEach(settings.meetingApps, id: \.self) { bundleID in
                    HStack(spacing: Theme.Space.s12) {
                        if let icon = Self.icon(for: bundleID) {
                            Image(nsImage: icon).resizable().frame(width: 22, height: 22)
                        } else {
                            Image(systemName: "app.dashed")
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.contentDisabled)
                                .frame(width: 22, height: 22)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(Self.name(for: bundleID) ?? bundleID)
                                .font(Theme.bodyMedium)
                                .foregroundStyle(Theme.contentPrimary)
                            Text(Self.name(for: bundleID) == nil ? "Nicht installiert" : bundleID)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Theme.contentSubdued)
                        }
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                settings.meetingApps.removeAll { $0 == bundleID }
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.contentSubdued)
                        .accessibilityLabel("\(bundleID) entfernen")
                    }
                    .padding(.horizontal, Theme.Space.s16)
                    .padding(.vertical, 6)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                    RowDivider()
                }
                HStack(spacing: Theme.Space.s8) {
                    TextField("com.example.meeting", text: $newBundleID)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .fill(Theme.backgroundElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .strokeBorder(Theme.borderPrimary, lineWidth: 1)
                        )
                        .onSubmit(addBundleID)
                    Button("App hinzufügen", action: addBundleID)
                        .buttonStyle(RButtonStyle(kind: .secondary))
                        .disabled(newBundleID.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(Theme.Space.s16)
            }

            Text("LepperMe nimmt nichts auf. Die App fragt nur ab, ob Mikrofon oder Kamera gerade benutzt werden. Kein Kalenderzugriff.")
                .font(Theme.caption)
                .foregroundStyle(Theme.contentSubdued)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private static func appURL(for bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    static func name(for bundleID: String) -> String? {
        guard let url = appURL(for: bundleID) else { return nil }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    static func icon(for bundleID: String) -> NSImage? {
        appURL(for: bundleID).map { NSWorkspace.shared.icon(forFile: $0.path) }
    }

    private func addBundleID() {
        let id = newBundleID.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty, !settings.meetingApps.contains(id) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            settings.meetingApps.append(id)
        }
        newBundleID = ""
    }
}

// MARK: - Allgemein

private struct GeneralTab: View {
    @ObservedObject var store: SettingsStore
    @State private var confirmReset = false

    var body: some View {
        VStack(spacing: Theme.Space.s16) {
            Card("Start", systemImage: "power") {
                SettingRow(label: "Bei Anmeldung starten") {
                    Toggle("", isOn: $store.settings.launchAtLogin).labelsHidden()
                }
            }
            Card("Aktivität", systemImage: "cursorarrow.motionlines") {
                SettingRow(label: "Inaktiv nach", hint: "Wer länger als eine Pause weg war, startet mit frischen Timern") {
                    ValueStepper(value: $store.settings.idleThresholdMinutes, range: 1...60) { "\($0) Min." }
                }
            }
            Button("Alle Einstellungen zurücksetzen") { confirmReset = true }
                .buttonStyle(RButtonStyle(kind: .secondary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .confirmationDialog(
                    "Alle Einstellungen zurücksetzen?",
                    isPresented: $confirmReset
                ) {
                    Button("Zurücksetzen", role: .destructive) { store.resetToDefaults() }
                } message: {
                    Text("Intervalle, Overlay, Meetings und Meeting-Apps gehen auf die Standardwerte zurück.")
                }
        }
    }
}
