#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="LibrarySeatWidget.app"
SOURCE_APP="$ROOT_DIR/dist/$APP_NAME"
TARGET_APP="$HOME/Desktop/$APP_NAME"

if [ ! -d "$SOURCE_APP" ]; then
  "$ROOT_DIR/Scripts/build_app.sh" >/dev/null
fi

rm -rf "$TARGET_APP"
cp -R "$SOURCE_APP" "$TARGET_APP"

echo "$TARGET_APP"
