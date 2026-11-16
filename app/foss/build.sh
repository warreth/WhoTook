#!/usr/bin/env bash
# Build a dependency-clean FOSS WhoTook APK.
#
# The normal --dart-define=FOSS_BUILD=true run already disables billing at
# runtime, but in_app_purchase remains a pubspec dependency and its native
# plugin is registered. This script copies the app, removes the billing
# dependencies and overlays the FOSS purchase service, then tests and builds.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP="$ROOT/app"
WORK="${TMPDIR:-/tmp}/whotook-foss-build"

rm -rf "$WORK"
mkdir -p "$WORK"
cp -a "$APP/." "$WORK/"
rm -rf "$WORK/build" "$WORK/.dart_tool" "$WORK/ios/Pods" "$WORK/android/.gradle" "$WORK/test/ui/store_raw"

cp "$APP/foss/purchase_service.dart" "$WORK/lib/core/party_pass/purchase_service.dart"
python3 - "$WORK/pubspec.yaml" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
lines = path.read_text().splitlines()
kept = []
for line in lines:
    stripped = line.strip()
    if stripped.startswith("in_app_purchase:"):
        continue
    if stripped.startswith("in_app_purchase_storekit:"):
        continue
    kept.append(line)
path.write_text("\n".join(kept) + "\n")
PY

cd "$WORK"
flutter pub get
flutter test --dart-define=FOSS_BUILD=true

if [[ "${1:-}" != "--test-only" ]]; then
  flutter build apk --debug \
    --target-platform android-arm64 \
    --dart-define=FOSS_BUILD=true
fi
