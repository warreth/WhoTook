#!/usr/bin/env bash
# Runs the real Demo Mode gate on a connected phone, emulator or simulator.
# Pick the target explicitly so a laptop with several devices cannot test the
# wrong one:
#
#   ./tool/playtest/run_device_demo_test.sh -d <device-id>
#
# `flutter devices` lists the available ids.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT/app"

if [[ $# -eq 0 ]]; then
  echo "Pick a target: $0 -d <device-id>" >&2
  echo "Connected devices:" >&2
  flutter devices >&2
  exit 2
fi

exec flutter test integration_test/demo_mode_test.dart "$@"
