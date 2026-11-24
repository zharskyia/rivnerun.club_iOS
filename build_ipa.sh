#!/bin/zsh
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCHEME="RivneRunningClubApp"
ARCHIVE_PATH="$PROJECT_DIR/build/${SCHEME}.xcarchive"
EXPORT_PATH="$PROJECT_DIR/build/ipa"
EXPORT_OPTIONS="$PROJECT_DIR/ExportOptions.plist"

if [ ! -f "$EXPORT_OPTIONS" ]; then
  echo "Missing ExportOptions.plist"
  exit 1
fi

xcodebuild -project "$PROJECT_DIR/RivneRunningClubApp.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  archive

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -exportPath "$EXPORT_PATH"

echo "IPA ready: $EXPORT_PATH"
