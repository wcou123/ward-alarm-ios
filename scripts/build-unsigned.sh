#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

xcodebuild -version
python3 scripts/render-gradual-sound.py --verify
plutil -lint WardAlarm/Info.plist WardAlarm.xcodeproj/project.pbxproj

xcodebuild \
  -project WardAlarm.xcodeproj \
  -scheme WardAlarm \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/device \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
  CURRENT_PROJECT_VERSION="${BUILD_NUMBER:-2}" \
  build

mkdir -p dist/Payload
ditto build/device/Build/Products/Release-iphoneos/WardAlarm.app dist/Payload/WardAlarm.app

python3 - <<'PY'
from pathlib import Path
import plistlib

app = Path('dist/Payload/WardAlarm.app')
with (app / 'Info.plist').open('rb') as f:
    info = plistlib.load(f)
assert info['CFBundleIdentifier'] == 'be.wardcoucke.alarm'
assert info['CFBundleDisplayName'] == 'BeutAlarm'
assert info['NSAlarmKitUsageDescription']
assert info['MinimumOSVersion'] == '26.0'
assert (app / info['CFBundleExecutable']).stat().st_size > 0
assert not (app / 'embedded.mobileprovision').exists(), 'The cloud output must be unsigned.'
sound = app / 'windows-alarm.wav'
assert sound.read_bytes() == Path('scripts/windows-alarm-source.wav').read_bytes()
assert (app / 'crescendo-alarm.wav').read_bytes() == Path('WardAlarm/crescendo-alarm.wav').read_bytes()
print('Unsigned BeutAlarm app and 60-second crescendo sound checked.')
PY

(cd dist && /usr/bin/zip -qry BeutAlarm.ipa Payload)
(cd dist && shasum -a 256 BeutAlarm.ipa > BeutAlarm.ipa.sha256)
