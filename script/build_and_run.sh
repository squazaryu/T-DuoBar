#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-run}"
BUILD_DIR="${TMPDIR:-/tmp}/T-DuoBar-DerivedData"
INSTALL_APP="/Applications/DuoBar.app"
BACKUP_DIR="$HOME/Library/Application Support/T-DuoBar/Backups"
case "$MODE" in run|--debug|--logs|--telemetry|--verify) ;; *) echo "Usage: $0 [--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;; esac
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
CONFIGURATION=Release
[[ "$MODE" != --debug ]] || CONFIGURATION=Debug

# Keep the current app running until its replacement has built successfully.
xcodebuild -quiet -project "$ROOT_DIR/DuoBar.xcodeproj" -scheme DuoBar \
    -configuration "$CONFIGURATION" -destination 'platform=macOS' \
    -derivedDataPath "$BUILD_DIR" CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM= MARKETING_VERSION=1.12.2 CURRENT_PROJECT_VERSION=39 build
BUILT_APP="$BUILD_DIR/Build/Products/$CONFIGURATION/DuoBar.app"
codesign --verify --deep --strict "$BUILT_APP"

if [[ "$MODE" == --debug ]]; then
    pkill -x DuoBar >/dev/null 2>&1 || true
    exec lldb -- "$BUILT_APP/Contents/MacOS/DuoBar"
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
STAGED_APP="/Applications/.DuoBar-$STAMP.app"
# Stage and verify before touching the installed copy.
ditto "$BUILT_APP" "$STAGED_APP"
codesign --verify --deep --strict "$STAGED_APP"
pkill -x DuoBar >/dev/null 2>&1 || true
for attempt in {1..30}; do
    pgrep -x DuoBar >/dev/null || break
    sleep 0.1
done
if pgrep -x DuoBar >/dev/null; then
    echo "DuoBar did not stop. The installed app was preserved; staged build: $STAGED_APP" >&2
    exit 1
fi

BACKUP_APP=""
if [[ -d "$INSTALL_APP" ]]; then
    mkdir -p "$BACKUP_DIR"
    BACKUP_APP="$BACKUP_DIR/DuoBar-$STAMP.app"
    mv "$INSTALL_APP" "$BACKUP_APP"
fi
if ! mv "$STAGED_APP" "$INSTALL_APP"; then
    [[ -z "$BACKUP_APP" ]] || mv "$BACKUP_APP" "$INSTALL_APP"
    exit 1
fi

/usr/bin/open -n "$INSTALL_APP"
VERIFIED_PID=""
for attempt in {1..30}; do
    for candidate_pid in $(pgrep -x DuoBar || true); do
        process_path="$(ps -p "$candidate_pid" -o command= || true)"
        if [[ "$process_path" == "$INSTALL_APP/Contents/MacOS/DuoBar" ]]; then
            VERIFIED_PID="$candidate_pid"
            break
        fi
    done
    [[ -z "$VERIFIED_PID" ]] || break
    sleep 0.2
done
if [[ -z "$VERIFIED_PID" ]]; then
    echo "Launch verification failed. Previous app is saved at: $BACKUP_APP" >&2
    exit 1
fi
printf 'Installed and running: %s (PID %s)\nBackup: %s\n' "$INSTALL_APP" "$VERIFIED_PID" "$BACKUP_APP"
case "$MODE" in
    --logs|--telemetry) exec /usr/bin/log stream --info --style compact --predicate 'process == "DuoBar"' ;;
esac
