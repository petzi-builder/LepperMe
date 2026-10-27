# LepperMe

Eine schlanke Menüleisten-App für macOS, die dich in einstellbaren Abständen daran erinnert, vom Bildschirm wegzuschauen, deine Haltung zu korrigieren und Pausen zu machen. Sie stört dich nicht in Meetings und kommt ohne Kalenderzugriff, Konto, Cloud oder Telemetrie aus.

## Installation

Voraussetzungen: macOS 13 (Ventura) oder neuer und Swift, z. B. über die Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone <repo-url> LepperMe
cd LepperMe
./run.sh          # oder: make run
```

Das Skript baut die App im Release-Modus, legt `build/LepperMe.app` an und startet sie. Das Symbol erscheint in der Menüleiste; ein Dock-Symbol gibt es nicht.

| Befehl | Wirkung |
|---|---|
| `make run` | bauen und starten |
| `make build` | nur bauen |
| `make install` | nach `~/Applications` kopieren |
| `make zip` | `build/LepperMe.zip` für GitHub Releases erzeugen |
| `make preview KIND=rest` | App neu starten und sofort ein Overlay zeigen |
| `make icon` | App-Icon neu erzeugen |
| `make clean` | Build-Ordner löschen |

### Vorgebaute App (GitHub Releases)

Lade `LepperMe.zip` herunter und entpacke es. Da die App nicht notarisiert ist, blockiert macOS den ersten Start: Klicke die App mit Rechtsklick an, wähle **Öffnen** und bestätige. Unter neueren macOS-Versionen musst du sie eventuell unter **Systemeinstellungen → Datenschutz & Sicherheit** mit **Trotzdem öffnen** freigeben.

## Erinnerungen

Die Standardwerte folgen gängigen Empfehlungen. Intervall, Dauer und An/Aus sind pro Typ in den Einstellungen frei konfigurierbar.

| Typ | Standard | Dauer |
|---|---|---|
| Augenpause (20-20-20-Regel) | alle 20 Min. | 20 Sek. |
| Haltung | alle 30 Min. | 10 Sek. |
| Pause | alle 60 Min. | 5 Min. |

- Sind mehrere gleichzeitig fällig, kommt nur die wichtigste (Pause > Augenpause > Haltung); die kleineren Timer werden mit zurückgesetzt.
- Kurz vorher erscheint oben eine Vorwarnung mit „Später“ und „Überspringen“.
- Das Overlay deckt alle Bildschirme ab, auch Vollbild-Apps. Überspringen geht per Button oder mit Esc.

## Meetings, ohne Kalender

LepperMe fragt lokal ab, **ob** Mikrofon oder Kamera gerade von irgendeiner App benutzt werden (CoreAudio / CoreMediaIO). Dabei wird nichts aufgenommen, deshalb braucht die App auch keine Mikrofon- oder Kameraberechtigung. Laufende Meeting-Apps (Zoom, Teams, Webex, Slack, FaceTime) werden als Zusatzinfo erkannt; die Liste ist erweiterbar.

Während eines Meetings werden fällige Erinnerungen gesammelt. Nach dem Meeting (plus 30 Sek. Puffer) kommt **eine** zusammengefasste Erinnerung.

Außerdem pausieren die Timer bei Inaktivität, Bildschirmsperre und Ruhezustand. Wer länger als eine Pause weg war, startet mit frischen Timern.

## Design

LepperMe folgt dem revel8-Designsystem (Figma „revel8 - master file“): Navy `#051520` als Grundfläche, Graustufen und Blau-Skala aus den Global Tokens, der revel8-Verlauf (Blau, Rot, Lila) für Akzente, Radien 8 und 16, Schrift Geist 400/600. Alle Werte stehen zentral in `Sources/LepperMe/Design/Theme.swift`; neue Farben gehören dort hin, nicht in einzelne Views.

- **Overlay:** driftende Aurora im Markenverlauf, leuchtender Countdown-Ring, gestaffelter Auftritt, Häkchen-Animation am Ende. Bei „Bewegung reduzieren“ (macOS-Bedienungshilfen) steht der Hintergrund still.
- **Töne:** zur Laufzeit synthetisiert (glockenartige Obertöne plus Hall), keine Audiodateien. Lautstärke in den Einstellungen.
- **Menüleiste:** Der Ring um das Auge füllt sich bis zur nächsten Erinnerung.

### Schrift, Logo, Icon

- **Geist** (Regular, SemiBold) liegt unter `Resources/Fonts/`, Lizenz SIL OFL 1.1 in `Resources/Fonts/Geist-OFL.txt`. Quelle: [vercel/geist-font](https://github.com/vercel/geist-font) v1.8.2.
- **revel8-Logo** und die „8“ sind als Vektorpfade in `Sources/LepperMe/Design/Brand.swift` hinterlegt: App-Icon, Menüleiste, Einstellungen und die Wortmarke im Overlay.
- **App-Icon:** `make icon` erzeugt `Resources/AppIcon.icns` neu.

### Mehrere Bildschirme

Das Overlay erscheint auf jedem angeschlossenen Bildschirm in exakt dessen Größe, der Inhalt skaliert mit (kleine Displays, 5K, Hochformat). Tastatur-Fokus und Vorwarnung landen auf dem Bildschirm mit dem Mauszeiger. Wird während einer Pause ein Display an- oder abgesteckt, baut sich das Overlay neu auf.

### Entwicklung

| Argument | Wirkung |
|---|---|
| `--preview eyes\|posture\|rest` | zeigt sofort ein Overlay |
| `--settings` | öffnet die Einstellungen |
| `--snapshot <ordner>` | rendert Overlay, Vorwarnung und Einstellungen als PNG und beendet sich |
| `--play-sounds` | spielt alle Töne nacheinander ab |
| `--render-icon <datei.png>` | rendert das App-Icon (1024 px) |

Mit `LEPPERME_DEBUG_LAYOUT=<ordner>` protokolliert die App beim Overlay die Fenster- und Bildschirmgrößen und speichert, was jedes Fenster tatsächlich zeichnet.

```bash
make preview KIND=eyes
```

`open … --args` wirkt nur, wenn LepperMe noch nicht läuft; `make preview` beendet die laufende Instanz vorher.

## Aufbau

```
Sources/LepperMe/
├── App/            main.swift, AppDelegate (Einstieg, verdrahtet alles), Snapshot (PNG-Export für Design-Reviews)
├── Reminders/      ReminderKind (Typen, Standardwerte), ReminderScheduler (Timer, Prioritäten, Meeting-Stau)
├── Detection/      MeetingDetector (Mikrofon, Kamera, Apps), ActivityMonitor (Inaktivität, Sperre, Ruhezustand)
├── Overlay/        OverlayController (Fenster pro Bildschirm, Vorwarnung), OverlayView (SwiftUI)
├── MenuBar/        StatusBarController (Symbol und Menü)
├── Settings/       SettingsStore (UserDefaults), SettingsView (SwiftUI), LoginItem (SMAppService)
├── Design/         Theme (revel8-Tokens, Schrift), Components (Buttons, Cards, Stepper, Slider, Toggle, Tabs)
└── Sound/          SoundEngine (synthetisierte Töne)
Resources/Info.plist, Resources/Fonts/ (optional, Geist)
```

## Datenschutz

Kein Kalenderzugriff, keine Audio- oder Videoaufnahme, keine Netzwerkverbindungen, keine Telemetrie. Einstellungen liegen lokal in `UserDefaults`.
