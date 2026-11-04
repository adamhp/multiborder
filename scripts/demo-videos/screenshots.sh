#!/bin/bash
# Captures the ten raw App Store screenshots (DemoRecordingUITests.testScreenshots) into
# build/demo-videos/shots-raw/NN-name.png. render.sh then frames them with their headlines.
# Run from a normal terminal: ./scripts/demo-videos/screenshots.sh
set -euo pipefail

source "$(dirname "$0")/prepare-simulator.sh"
out="$repo/build/demo-videos/shots-raw"
work="$(mktemp -d)"
results="$work/screenshots.xcresult"

# Screen 8 shows "Save to album" on, which needs full photo library access.
xcrun simctl privacy "$udid" grant photos com.adamhp.multiborder

xcodebuild test -quiet -project "$repo/multiborder.xcodeproj" -scheme AppStoreScreenshots \
  -destination "platform=iOS Simulator,id=$udid" -parallel-testing-enabled NO -resultBundlePath "$results"
xcrun simctl shutdown "$udid" 2>/dev/null || true

# The test saves each screen as an attachment named "NN-name"; keep those under their names.
mkdir -p "$out" "$work/attachments"
rm -f "$out"/*.png
xcrun xcresulttool export attachments --path "$results" --output-path "$work/attachments" >/dev/null
python3 - "$work/attachments" "$out" <<'EOF'
import json, re, shutil, sys
attachments, out = sys.argv[1], sys.argv[2]
for test in json.load(open(f"{attachments}/manifest.json")):
    for a in test["attachments"]:
        name = a["suggestedHumanReadableName"]
        if re.match(r"\d\d-", name) and a["exportedFileName"].endswith(".png"):
            shutil.copy(f"{attachments}/{a['exportedFileName']}", f"{out}/{name.split('_')[0]}.png")
EOF
ls "$out"
