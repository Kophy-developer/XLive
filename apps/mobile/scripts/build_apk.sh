#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
for jbr in \
  "/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  "/Applications/Android Studio Preview.app/Contents/jbr/Contents/Home" \
  "$HOME/Applications/Android Studio.app/Contents/jbr/Contents/Home"
do
  if [[ -d "$jbr" ]]; then
    export JAVA_HOME="$jbr"
    export PATH="$JAVA_HOME/bin:$PATH"
    break
  fi
done
cd "$MOBILE_ROOT"
exec flutter build apk "$@"
