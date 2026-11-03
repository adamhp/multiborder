#!/bin/bash
# Records the App Store preview storyboard (DemoRecordingUITests) into build/demo-videos/raw.mov.
# Run from a normal terminal: ./scripts/demo-videos/record.sh
#
# Each take starts from an erased "Multiborder Demo" Simulator, because every take saves bordered
# copies back into the photo library, and the next take would pick those instead of the samples.
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
out="$repo/build/demo-videos/raw.mov"
name="Multiborder Demo"

udid=$(xcrun simctl list devices available | sed -n "s/^ *$name (\([0-9A-F-]*\)).*/\1/p" | head -1)
if [ -z "$udid" ]; then
  udid=$(xcrun simctl create "$name" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max com.apple.CoreSimulator.SimRuntime.iOS-26-5)
fi
echo "Simulator: $name ($udid)"

xcrun simctl shutdown "$udid" 2>/dev/null || true
xcrun simctl erase "$udid"
xcrun simctl boot "$udid"
xcrun simctl addmedia "$udid" "$repo"/sample-photos/*.JPG
# Saving to Photos would otherwise show a permission alert mid-take.
xcrun simctl privacy "$udid" grant photos-add com.adamhp.multiborder
xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3

mkdir -p "$(dirname "$out")"
xcrun simctl io "$udid" recordVideo --codec h264 --force "$out" &
recorder=$!
sleep 2

xcodebuild test -quiet -project "$repo/multiborder.xcodeproj" -scheme DemoRecording \
  -destination "platform=iOS Simulator,id=$udid" -parallel-testing-enabled NO

# recordVideo only writes a playable file when it is interrupted or its Simulator shuts down.
kill -INT "$recorder" 2>/dev/null || xcrun simctl shutdown "$udid"
wait "$recorder" || true
xcrun simctl shutdown "$udid" 2>/dev/null || true

ffprobe -v error -show_entries format=duration -of default=nw=1 "$out"
echo "Recorded $out"
