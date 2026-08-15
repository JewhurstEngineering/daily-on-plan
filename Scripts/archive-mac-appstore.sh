#!/usr/bin/env bash
# Archive the Mac app for Mac App Store / App Store Connect (Universal Purchase).
# This is Apple Distribution signing — not Developer ID / notarize.
# Create the macOS platform on the Daily On Plan App Store Connect record first
# (bundle com.dailyonplan.macos).
set -euo pipefail
cd "$(dirname "$0")/.."

DIST="${PWD}/dist/mac-appstore"
ARCHIVE="${DIST}/DailyOnPlan.xcarchive"
EXPORT="${DIST}/export"

mkdir -p "${DIST}"
xcodegen generate

echo "Archiving Mac Release for App Store Connect…"
xcodebuild \
  -project DailyOnPlan.xcodeproj \
  -scheme DailyOnPlan \
  -destination 'generic/platform=macOS' \
  -configuration Release \
  -archivePath "${ARCHIVE}" \
  archive \
  -allowProvisioningUpdates

echo "Exporting Mac App Store pkg…"
xcodebuild \
  -exportArchive \
  -archivePath "${ARCHIVE}" \
  -exportPath "${EXPORT}" \
  -exportOptionsPlist Scripts/export-options-mac-appstore.plist \
  -allowProvisioningUpdates

echo "Export at ${EXPORT}"
echo "Upload in Xcode Organizer or Transporter. Do not use Scripts/notarize — that is Developer ID, not the store."
