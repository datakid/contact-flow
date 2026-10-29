#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
aapt="$(find "$sdk/build-tools" -name aapt -type f 2>/dev/null | sort | tail -n 1)"
if [ -z "$aapt" ]; then
  echo "aapt not found under $sdk/build-tools"
  exit 2
fi

lite="${1:-build/app/outputs/flutter-apk/app-lite-debug.apk}"
full="${2:-build/app/outputs/flutter-apk/app-full-debug.apk}"

lite_perms="$("$aapt" dump permissions "$lite")"
full_perms="$("$aapt" dump permissions "$full")"

if grep -q "READ_CALL_LOG" <<<"$lite_perms"; then
  echo "lite requests READ_CALL_LOG"
  exit 1
fi
if ! grep -q "READ_CALL_LOG" <<<"$full_perms"; then
  echo "full does not request READ_CALL_LOG"
  exit 1
fi
for dir in main lite full; do
  manifest="android/app/src/$dir/AndroidManifest.xml"
  if [ -f "$manifest" ] && grep -q "android.permission.INTERNET" "$manifest"; then
    echo "$manifest requests INTERNET"
    exit 1
  fi
done

echo "permissions ok"
