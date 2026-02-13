#!/usr/bin/env bash
# Re-apply flutter_native_timezone namespace patch after `flutter pub get`.
# Full steps: see docs/ANDROID_PLUGIN_PATCHES.md

set -e
CACHE="${PUB_CACHE:-$(cd "$(dirname "$0")/.." && flutter pub cache path 2>/dev/null)}"
[ -z "$CACHE" ] && CACHE="$HOME/.pub-cache"
PLUGIN="$CACHE/hosted/pub.dev/flutter_native_timezone-2.0.0/android/build.gradle"

if [ ! -f "$PLUGIN" ]; then
  echo "Run 'flutter pub get' first. Not found: $PLUGIN"
  exit 1
fi

if grep -q "namespace 'com.whelksoft" "$PLUGIN"; then
  echo "Namespace already present."
else
  # macOS sed: add line after "android {"
  sed -i '' 's/^android {/android {\n    namespace '\''com.whelksoft.flutter_native_timezone'\''/' "$PLUGIN"
  echo "Added namespace."
fi

echo "If build still fails (JVM target, Registrar), see docs/ANDROID_PLUGIN_PATCHES.md"
