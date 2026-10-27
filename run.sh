#!/usr/bin/env bash
# Builds LepperMe in release mode, assembles build/LepperMe.app and starts it.
#   ./run.sh            build + start
#   ./run.sh --no-open  build only
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="LepperMe"
APP="build/${APP_NAME}.app"
# SwiftPM's build cache lives outside the repo: folders watched by sync/backup tools
# (hard-linking files) break SwiftPM's SQLite build database. Override with LEPPERME_BUILD_PATH.
SCRATCH_PATH="${LEPPERME_BUILD_PATH:-${HOME}/Library/Caches/${APP_NAME}/build}"

if ! command -v swift >/dev/null 2>&1; then
    echo "Swift wurde nicht gefunden. Installiere die Xcode Command Line Tools mit: xcode-select --install" >&2
    exit 1
fi

echo "==> Baue ${APP_NAME} (Release) …"
swift build -c release --scratch-path "${SCRATCH_PATH}"
BIN_DIR="$(swift build -c release --scratch-path "${SCRATCH_PATH}" --show-bin-path)"

echo "==> Erstelle ${APP} …"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "${BIN_DIR}/${APP_NAME}" "${APP}/Contents/MacOS/${APP_NAME}"
cp Resources/Info.plist "${APP}/Contents/Info.plist"
if [ -d Resources/Fonts ]; then
    cp -R Resources/Fonts "${APP}/Contents/Resources/Fonts"
fi
if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "${APP}/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc signature so macOS treats it as a proper bundle (needed e.g. for "Bei Anmeldung starten").
codesign --force --deep --sign - "${APP}" >/dev/null

if [ "${1:-}" != "--no-open" ]; then
    # Restart if an older instance is running. Wait until it is really gone,
    # otherwise LaunchServices still sees it and `open` fails with error -600.
    if pkill -x "${APP_NAME}" 2>/dev/null; then
        for _ in $(seq 1 50); do
            pgrep -x "${APP_NAME}" >/dev/null || break
            sleep 0.1
        done
        sleep 0.5
    fi
    echo "==> Starte ${APP_NAME} – das Symbol erscheint in der Menüleiste."
    open "${APP}"
fi
