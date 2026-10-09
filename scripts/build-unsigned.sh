#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

xcodebuild -version
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
  CURRENT_PROJECT_VERSION="${BUILD_NUMBER:-1}" \
  build

mkdir -p dist/Payload
ditto build/device/Build/Products/Release-iphoneos/WardAlarm.app dist/Payload/WardAlarm.app

python3 - <<'PY'
from pathlib import Path
import hashlib
import plistlib
import wave

app = Path('dist/Payload/WardAlarm.app')
with (app / 'Info.plist').open('rb') as f:
    info = plistlib.load(f)
assert info['CFBundleIdentifier'] == 'be.wardcoucke.alarm'
assert info['NSAlarmKitUsageDescription']
assert info['MinimumOSVersion'] == '26.0'
assert (app / info['CFBundleExecutable']).stat().st_size > 0
assert not (app / 'embedded.mobileprovision').exists(), 'The cloud output must be unsigned.'
sound = app / 'windows-alarm.wav'
assert hashlib.sha256(sound.read_bytes()).hexdigest() == '46c758f03534be1a2247413e7e5d92bcfdae1986f8f7f9fcaeabd3a72d131a2b'
with wave.open(str(sound)) as f:
    assert 5 < f.getnframes() / f.getframerate() < 6
print('Unsigned app and Windows sound checked.')
PY

(cd dist && /usr/bin/zip -qry WardAlarm.ipa Payload)
(cd dist && shasum -a 256 WardAlarm.ipa > WardAlarm.ipa.sha256)
