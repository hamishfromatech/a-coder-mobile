#!/usr/bin/env bash
# Build the iOS app.
#
#   ./scripts/build_ios.sh unsigned   # .ipa ready for Sideloadly/AltStore signing
#   ./scripts/build_ios.sh ipa        # signed .ipa (needs an Apple Developer team)
#   ./scripts/build_ios.sh simulator  # .app for the iOS Simulator
#
# Requires a full Xcode installation:
#   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
#   sudo xcodebuild -runFirstLaunch
set -euo pipefail
cd "$(dirname "$0")/../app"

mode="${1:-unsigned}"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Xcode is required. Install it from the App Store, then run:" >&2
  echo "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer" >&2
  echo "  sudo xcodebuild -runFirstLaunch" >&2
  exit 1
fi

flutter pub get
( cd ios && pod install )

case "$mode" in
  simulator)
    flutter build ios --simulator
    echo "Simulator app: app/build/ios/iphonesimulator/Runner.app"
    ;;
  ipa)
    flutter build ipa --release
    echo "Signed IPA: app/build/ios/ipa/"
    ;;
  unsigned)
    flutter build ios --release --no-codesign
    rm -rf build/ios/unsigned build/ios/unsigned.ipa
    mkdir -p build/ios/unsigned/Payload
    cp -R build/ios/iphoneos/Runner.app build/ios/unsigned/Payload/
    ( cd build/ios/unsigned && zip -qry ../unsigned.ipa Payload )
    echo "Unsigned IPA: app/build/ios/unsigned.ipa"
    echo "Sign it with Sideloadly/AltStore using your Apple ID, then install."
    ;;
  *)
    echo "unknown mode: $mode" >&2
    exit 2
    ;;
esac
