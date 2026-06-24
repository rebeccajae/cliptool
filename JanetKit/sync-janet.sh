#!/bin/bash
set -e

JANET_VERSION="v1.41.2"
BASE_URL="https://github.com/janet-lang/janet/releases/download/${JANET_VERSION}"
DEST="Sources/CJanet"

mkdir -p "$DEST"
curl -L "${BASE_URL}/janet.c" -o "${DEST}/janet.c"
curl -L "${BASE_URL}/janet.h" -o "${DEST}/janet.h"

echo "Janet ${JANET_VERSION} synced to ${DEST}"

