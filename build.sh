#!/bin/bash
set -euo pipefail

echo "=== Running tests ==="
( cd JanetKit && swift test )
swift test

echo "=== Building archive ==="
SCHEME="cliptool"
xcodebuild clean -scheme "$SCHEME" -configuration Release -quiet

BUILD_DIR="$PWD/.xcbuild"
xcodebuild \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    build 2>&1 | grep -E '(BUILD|error:)'
# Surface a non-zero exit if the build itself failed (the grep pipe above
# would otherwise mask it).
if [ ! -d "$BUILD_DIR/Build/Products/Release/cliptool.app" ]; then
  echo "error: Release build did not produce cliptool.app" >&2
  exit 1
fi

cp -r "$BUILD_DIR/Build/Products/Release/cliptool.app" .
zip -r cliptool.zip cliptool.app

echo "=== Done: cliptool.zip ==="
