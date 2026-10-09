#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p build
xcrun simctl list devices available --json > build/simulators.json

SIMULATOR_ID="$(python3 - <<'PY'
import json
from pathlib import Path

devices = json.loads(Path('build/simulators.json').read_text())['devices']
candidates = [
    (runtime, device['name'], device['udid'])
    for runtime, group in devices.items()
    if 'iOS-26-' in runtime
    for device in group
    if device.get('isAvailable') and 'iPhone' in device['name']
]
if not candidates:
    raise SystemExit('No available iOS 26 iPhone simulator on this runner.')
print(sorted(candidates, reverse=True)[0][2])
PY
)"

xcodebuild \
  -project WardAlarm.xcodeproj \
  -scheme WardAlarm \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=${SIMULATOR_ID}" \
  -derivedDataPath build/simulator \
  -resultBundlePath build/AlarmTests.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  test
