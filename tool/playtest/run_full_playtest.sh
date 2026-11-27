#!/usr/bin/env bash
# One command for a future agent: Dart multi-peer simulation + four real
# browsers playing the actual Flutter app, with screenshots and a report.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP="$ROOT/app"
BUILD_DIR="${PLAYTEST_BUILD_DIR:-/tmp/opencode/whotook_playtest_build}"
WEB_DIR="${PLAYTEST_WEB_DIR:-$BUILD_DIR/build/web}"
MODE="all"
SKIP_BUILD=0
BUILD_ONLY=0
DART_ONLY=0
VISUAL_ONLY=0
PLAYTEST_OUTPUT_DIR="${PLAYTEST_OUTPUT_DIR:-/tmp/opencode/whotook_playtest}"
export PLAYTEST_OUTPUT_DIR

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="${2:?missing mode}"; shift 2 ;;
    --web-dir) WEB_DIR="${2:?missing web dir}"; shift 2 ;;
    --build-dir) BUILD_DIR="${2:?missing build dir}"; WEB_DIR="$BUILD_DIR/build/web"; shift 2 ;;
    --skip-build) SKIP_BUILD=1; shift ;;
    --build-only) BUILD_ONLY=1; shift ;;
    --dart-only) DART_ONLY=1; shift ;;
    --visual-only) VISUAL_ONLY=1; shift ;;
    -h|--help)
      cat <<'EOF'
Usage: ./tool/playtest/run_full_playtest.sh [options]

  --mode MODE       all | classic | meme | time | mixed | meme-zero
  --skip-build      reuse the existing temp Flutter web build
  --build-only      build the web playtest bundle and stop
  --dart-only       run only the Dart 4-6 peer simulation
  --visual-only     run only the Playwright browser match
  --web-dir DIR     serve an existing Flutter web build
EOF
      exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

command -v flutter >/dev/null || {
  echo "flutter is not on PATH" >&2
  exit 1
}
command -v node >/dev/null || {
  echo "node is not on PATH" >&2
  exit 1
}

if [[ "$DART_ONLY" -eq 0 ]]; then
  if [[ "$SKIP_BUILD" -eq 0 ]]; then
    echo "→ building the PLAYTEST_MODE web bundle in $BUILD_DIR"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    (
      cd "$APP"
      tar --exclude=build --exclude=.dart_tool --exclude=.idea -cf - .
    ) | tar -xf - -C "$BUILD_DIR"
    (
      cd "$BUILD_DIR"
      flutter create --platforms=web . >/dev/null
      flutter build web --release --no-tree-shake-icons --no-wasm-dry-run \
        --dart-define=PLAYTEST_MODE=true >/dev/null
    )
  elif [[ ! -f "$WEB_DIR/index.html" ]]; then
    echo "no web build at $WEB_DIR; rerun without --skip-build" >&2
    exit 1
  fi
fi

if [[ "$BUILD_ONLY" -eq 1 ]]; then
  echo "✓ web playtest bundle ready: $WEB_DIR"
  exit 0
fi

if [[ "$VISUAL_ONLY" -eq 0 ]]; then
  echo "→ Dart multi-peer simulation"
  (
    cd "$APP"
    flutter test test/multiplayer_simulation_test.dart
  )
fi

if [[ "$DART_ONLY" -eq 1 ]]; then
  echo "✓ Dart simulation passed"
  exit 0
fi

echo "→ Playwright four-browser match ($MODE)"
cd "$ROOT"
node tool/playtest/playtest_bot_match.mjs --web-dir "$WEB_DIR" --mode "$MODE"

echo
echo "Screenshots: $PLAYTEST_OUTPUT_DIR/auto_playtest/screenshots"
echo "Report:      $PLAYTEST_OUTPUT_DIR/auto_playtest/report.json"
