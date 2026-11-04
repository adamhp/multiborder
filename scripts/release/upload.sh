#!/bin/bash
# Archives the app and its extensions and uploads the build to App Store Connect, where it
# appears in TestFlight once processed. Submitting for review stays a manual step.
#
#   ./scripts/release/upload.sh        # build number from the project (CURRENT_PROJECT_VERSION)
#   ./scripts/release/upload.sh 2      # a later upload of the same version needs a higher number
#
# Uses the Xcode account signed in on this Mac (automatic signing, team 3BF23L96N2).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="$repo/build/release"
archive="$out/multiborder.xcarchive"
build_args=()
if [ $# -gt 0 ]; then
  build_args=("CURRENT_PROJECT_VERSION=$1")
fi

if [ -n "$(git -C "$repo" status --porcelain)" ]; then
  echo "Commit or stash your changes first, so the upload matches a commit." >&2
  exit 1
fi
echo "Archiving $(git -C "$repo" rev-parse --abbrev-ref HEAD) at $(git -C "$repo" rev-parse --short HEAD)"

mkdir -p "$out"
xcodebuild archive -quiet -project "$repo/multiborder.xcodeproj" -scheme multiborder -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$archive" -allowProvisioningUpdates "${build_args[@]}"

xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist "$here/ExportOptions.plist" \
  -exportPath "$out/export" -allowProvisioningUpdates

plist="$archive/Info.plist"
echo "Uploaded multiborder $(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleShortVersionString' "$plist")" \
  "($(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleVersion' "$plist")). It shows in TestFlight once processed."
