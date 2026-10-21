#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$MOBILE_ROOT"

if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
fi

DEVICE_NAME="${FLUTTER_IOS_SIMULATOR:-iPhone 17 Pro Max}"

if flutter devices 2>/dev/null | grep -qF "$DEVICE_NAME (mobile)"; then
  exec flutter run -d "$DEVICE_NAME" --no-dds "$@"
fi

if command -v xcrun >/dev/null 2>&1; then
  LINE=$(xcrun simctl list devices 2>/dev/null | grep -F "$DEVICE_NAME" | grep -v "unavailable" | head -1 || true)
  if [[ -n "${LINE:-}" ]]; then
    UDID=$(echo "$LINE" | awk -F '[()]' '{print $2}')
    if [[ -n "${UDID:-}" ]]; then
      if ! echo "$LINE" | grep -q Booted; then
        xcrun simctl boot "$UDID" 2>/dev/null || true
        open -a Simulator 2>/dev/null || true
        for _ in $(seq 1 45); do
          flutter devices 2>/dev/null | grep -qF "$DEVICE_NAME (mobile)" && break
          sleep 1
        done
      fi
      exec flutter run -d "$UDID" --no-dds "$@"
    fi
  fi
fi

echo "Could not find simulator: $DEVICE_NAME" >&2
echo "Open Simulator, pick that device, then retry." >&2
exit 1
