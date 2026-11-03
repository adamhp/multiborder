#!/bin/bash
# Sourced by record.sh and screenshots.sh: sets $repo and $udid to an erased, booted
# "Multiborder Demo" Simulator (iPhone 17 Pro Max, iOS 26.5) with the sample photos loaded,
# photo saving pre-granted and a 9:41 status bar.
#
# Every run starts from an erased Simulator, because each run saves bordered copies back into
# the photo library, and the next run would pick those instead of the samples.

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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
# Saving to Photos would otherwise show a permission alert mid-run.
xcrun simctl privacy "$udid" grant photos-add com.adamhp.multiborder
xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3
# Dark appearance, so Photos draws its own chrome around the Multiborder extension (its "multiborder"
# title and buttons) to match the app, as it does for anyone using dark mode.
xcrun simctl ui "$udid" appearance dark
