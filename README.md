# LepperMe

Eine schlanke Menüleisten-App für macOS, die dich in einstellbaren Abständen daran erinnert, vom Bildschirm wegzuschauen, deine Haltung zu korrigieren und Pausen zu machen. Sie stört dich nicht in Meetings und kommt ohne Kalenderzugriff, Konto, Cloud oder Telemetrie aus.

## Installation

### Für alle: fertige App herunterladen

1. Öffne die [neueste Version](https://github.com/petzi-builder/LepperMe/releases/latest) und lade **LepperMe.zip** herunter.
2. Öffne die heruntergeladene Datei per Doppelklick. Es erscheint **LepperMe**.
3. Ziehe **LepperMe** in den Ordner **Programme**.
4. Öffne LepperMe per Doppelklick. macOS meldet beim ersten Mal, dass die App nicht geprüft werden kann. Klicke auf **Fertig**.
5. Öffne **Systemeinstellungen → Datenschutz & Sicherheit**, scrolle nach unten und klicke bei LepperMe auf **Trotzdem öffnen** (unter macOS 13 und 14 heißt der Button **Dennoch öffnen**). Bestätige mit deinem Passwort oder Touch ID.

Danach erscheint die revel8-„8“ oben rechts in der Menüleiste. Über das Symbol erreichst du die Einstellungen; dort kannst du auch „Bei Anmeldung starten“ einschalten. Schritt 4 und 5 sind nur beim ersten Start nötig.

LepperMe läuft auf macOS 13 (Ventura) oder neuer, auf Macs mit Apple-Chip und mit Intel-Prozessor. Die App ist nicht von Apple notarisiert, deshalb der Umweg über die Systemeinstellungen.

### Für Entwickler: aus dem Quellcode bauen

Voraussetzungen: macOS 13 oder neuer und Swift, z. B. über die Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/petzi-builder/LepperMe.git
cd LepperMe
./run.sh          # oder: make run
```

Das Skript baut die App im Release-Modus, legt `build/LepperMe.app` an und startet sie. Den SwiftPM-Build-Cache legt das Skript unter `~/Library/Caches/LepperMe/build` ab, weil Ordner, die von Sync- oder Backup-Tools überwacht werden, die SQLite-Datenbank von SwiftPM beschädigen können; mit `LEPPERME_BUILD_PATH` lässt sich der Ort ändern.

| Befehl | Wirkung |
|---|---|
| `make run` | bauen und starten |
| `make build` | nur bauen |
| `make install` | nach `~/Applications` kopieren |
| `make zip` | Universal-App (Apple-Chip und Intel) als `build/LepperMe.zip` für GitHub Releases |
| `make preview KIND=rest` | App neu starten und sofort ein Overlay zeigen |
| `make icon` | App-Icon neu erzeugen |
| `make clean` | Build-Ordner löschen |

### Neue Version veröffentlichen

1. Version in `Resources/Info.plist` erhöhen (`CFBundleShortVersionString`, `CFBundleVersion`).
2. `make zip`
3. `gh release create vX.Y.Z build/LepperMe.zip --title "LepperMe X.Y.Z" --notes "…"`

## Erinnerungen

Die Standardwerte folgen gängigen Empfehlungen. Intervall, Dauer und An/Aus sind pro Typ in den Einstellungen frei konfigurierbar.

| Typ | Standard | Dauer |
|---|---|---|
| Augenpause (20-20-20-Regel) | alle 20 Min. | 20 Sek. |
| Haltung | alle 30 Min. | 5 Sek. |
| Pause | alle 60 Min. | 5 Min. |

- Sind mehrere gleichzeitig fällig, kommt nur die wichtigste (Pause > Augenpause > Haltung); die kleineren Timer werden mit zurückgesetzt.
- Vor Augenpause und Pause hängt eine Vorwarnung mit Countdown am Mauszeiger und wandert mit, bis die Pause beginnt. Sie fängt keine Klicks ab; „Später“ und „Überspringen“ gibt es im Overlay (auch per Esc).
- **Augenpause und Pause** sind Vollbild-Overlays auf allen Bildschirmen, auch über Vollbild-Apps. Jede hat ihre eigene Animation: ein blinzelndes Auge mit Ringen, die in die Tiefe ziehen, bzw. eine Atem-Kugel (4 Sek. ein, 4 Sek. aus). Überspringen geht per Button oder mit Esc.
- **Haltung** ist keine Pause, sondern ein kurzer Hinweis in der Mitte des Bildschirms mit dem Mauszeiger: Ein Pfeil steigt sanft auf und schwebt. Er blockiert nichts (Klicks gehen durch), verschwindet von selbst und kommt ohne Vorwarnung.

## Meetings, ohne Kalender

LepperMe fragt lokal ab, **ob** Mikrofon oder Kamera gerade von irgendeiner App benutzt werden (CoreAudio / CoreMediaIO). Dabei wird nichts aufgenommen, deshalb braucht die App auch keine Mikrofon- oder Kameraberechtigung. Laufende Meeting-Apps (Zoom, Teams, Webex, Slack, FaceTime) werden als Zusatzinfo erkannt; die Liste ist erweiterbar.

Erkennt LepperMe ein Meeting, erscheint oben kurz und ohne Ton „Meeting erkannt“, damit klar ist, dass keine Unterbrechung kommt; am Ende entsprechend „Meeting beendet“. Abschaltbar in den Einstellungen.

Während eines Meetings werden fällige Erinnerungen gesammelt. Nach dem Meeting (plus 30 Sek. Puffer) kommt **eine** zusammengefasste Erinnerung.

Außerdem pausieren die Timer bei Inaktivität, Bildschirmsperre und Ruhezustand. Wer länger als eine Pause weg war, startet mit frischen Timern.

## Design

LepperMe folgt dem revel8-Designsystem (Figma „revel8 - master file“): Navy `#051520` als Grundfläche, Graustufen und Blau-Skala aus den Global Tokens, der revel8-Verlauf (Blau, Rot, Lila) für Akzente, Radien 8 und 16, Schrift Geist 400/600. Alle Werte stehen zentral in `Sources/LepperMe/Design/Theme.swift`; neue Farben gehören dort hin, nicht in einzelne Views.

- **Overlay:** driftende Aurora im Markenverlauf, leuchtender Countdown-Ring, gestaffelter Auftritt, Häkchen-Animation am Ende. Bei „Bewegung reduzieren“ (macOS-Bedienungshilfen) steht der Hintergrund still.
- **Töne:** zur Laufzeit synthetisiert (glockenartige Obertöne plus Hall), keine Audiodateien. Lautstärke in den Einstellungen.
- **Menüleiste:** Der Ring um die revel8-„8“ füllt sich bis zur nächsten Erinnerung. Im Meeting zeigt das Symbol eine Kamera, bei manueller Pause ein Pause-Zeichen.

### Schrift, Logo, Icon

- **Geist** (Regular, SemiBold) liegt unter `Resources/Fonts/`, Lizenz SIL OFL 1.1 in `Resources/Fonts/Geist-OFL.txt`. Quelle: [vercel/geist-font](https://github.com/vercel/geist-font) v1.8.2.
- **revel8-Logo** und die „8“ sind als Vektorpfade in `Sources/LepperMe/Design/Brand.swift` hinterlegt: App-Icon, Menüleiste, Einstellungen und die Wortmarke im Overlay.
- **App-Icon:** `make icon` erzeugt `Resources/AppIcon.icns` neu.

### Mehrere Bildschirme

Das Overlay erscheint auf jedem angeschlossenen Bildschirm in exakt dessen Größe, der Inhalt skaliert mit (kleine Displays, 5K, Hochformat). Tastatur-Fokus (für Esc), Haltungs-Hinweis und Meeting-Hinweis landen auf dem Bildschirm mit dem Mauszeiger; die Vorwarnung folgt dem Zeiger auch über Bildschirmgrenzen. Wird während einer Pause ein Display an- oder abgesteckt, baut sich das Overlay neu auf.

### Entwicklung

| Argument | Wirkung |
|---|---|
| `--preview eyes\|posture\|rest` | zeigt sofort Overlay bzw. Haltungs-Hinweis |
| `--settings` | öffnet die Einstellungen |
| `--snapshot <ordner>` | rendert Overlay, Vorwarnung und Einstellungen als PNG und beendet sich |
| `--prewarning` | zeigt die Vorwarnung |
| `--meeting-toast` | zeigt den Hinweis „Meeting erkannt“ |
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
├── Overlay/        OverlayController (Fenster pro Bildschirm, Hinweise), OverlayView (Overlay, Vorwarnung),
│                   BreakAnimations (Auge, Atem-Kugel, Pfeil, Haltungs-Hinweis), ToastView (Meeting-Hinweis)
├── MenuBar/        StatusBarController (Symbol und Menü)
├── Settings/       SettingsStore (UserDefaults), SettingsView (SwiftUI), LoginItem (SMAppService)
├── Design/         Theme (revel8-Tokens, Schrift), Components (Buttons, Cards, Stepper, Slider, Toggle, Tabs),
│                   Brand (revel8-Logo als Vektor)
└── Sound/          SoundEngine (synthetisierte Töne)
Resources/           Info.plist, AppIcon.icns, Fonts/ (Geist + Lizenz)
```

## Datenschutz

Kein Kalenderzugriff, keine Audio- oder Videoaufnahme, keine Netzwerkverbindungen, keine Telemetrie. Einstellungen liegen lokal in `UserDefaults`.

## Lizenz

LepperMe steht unter der [MIT-Lizenz](LICENSE). Ausgenommen sind die Schrift Geist (SIL Open Font License 1.1, siehe `Resources/Fonts/Geist-OFL.txt`) sowie das revel8-Logo und die Marke revel8, die nicht unter die MIT-Lizenz fallen.
