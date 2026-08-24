#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

command -v swift >/dev/null || { echo "swift is required" >&2; exit 1; }
python3 - <<'PY'
import plistlib
with open("Sources/EmberTodo/Resources/Info.plist", "rb") as handle:
    plistlib.load(handle)
PY
python3 -m json.tool Sources/EmberTodo/Resources/Assets.xcassets/Contents.json >/dev/null
python3 -m json.tool Sources/EmberTodo/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json >/dev/null
ruby -e 'require "yaml"; data = YAML.safe_load_file("project.yml"); abort "unexpected bundle identifier" unless data.dig("targets", "EmberTodo", "settings", "base", "PRODUCT_BUNDLE_IDENTIFIER") == "com.peteradams.embertodo"'
swift test

if [[ "$(uname -s)" == "Darwin" ]]; then
  command -v xcodegen >/dev/null || { echo "xcodegen is required on macOS" >&2; exit 1; }
  xcodegen generate
fi

if ! command -v xtool >/dev/null; then
  echo "xtool is required for the full iPhone cross-build" >&2
  exit 1
fi
timeout 30 xtool sdk status
xtool dev build
APP="$ROOT/xtool/EmberTodo.app"
test -d "$APP"
test -f "$APP/Info.plist"
file "$APP/EmberTodo" | grep -q 'Mach-O 64-bit.*arm64'
echo "Linux gate passed: $APP"
