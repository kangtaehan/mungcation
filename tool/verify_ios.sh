#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS verification requires macOS and Xcode." >&2
  exit 1
fi
xcodebuild -version
flutter pub get
flutter analyze
flutter test --concurrency=1
plutil -lint ios/Runner/Info.plist
pod install --project-directory=ios
python3 tool/build_release.py ios-simulator
xcodebuild build-for-testing \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
