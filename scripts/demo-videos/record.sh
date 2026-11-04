#!/bin/bash
# Records the App Store preview storyboard (DemoRecordingUITests.testStoryboard) into
# build/demo-videos/raw.mov. Run from a normal terminal: ./scripts/demo-videos/record.sh
set -euo pipefail

source "$(dirname "$0")/prepare-simulator.sh"
out="$repo/build/demo-videos/raw.mov"

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
