#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f gradlew ]]; then
  echo "gradlew not found at repo root"
  exit 1
fi

chmod +x gradlew

./gradlew --no-daemon :app:ndkBuildAll :app:assembleDebug :app:assembleRelease

echo "Build complete. APK outputs:"
find app/build/outputs/apk -type f -name "*.apk" -print
