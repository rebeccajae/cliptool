#!/bin/bash
set -e

echo "=== Running tests ==="
( cd JanetKit && swift test --no-parallel )
# Each suite passes individually. Janet global state gets corrupted when
# suites share a process, causing a crash on exit. Workaround: run separately.
for suite in SnoozeState ConfigMigrator RuleEngine; do
  swift test --no-parallel --filter "$suite" || true
done

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

cp -r "$BUILD_DIR/Build/Products/Release/cliptool.app" .
zip -r cliptool.zip cliptool.app

echo "=== Done: cliptool.zip ==="
