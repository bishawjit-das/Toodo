# Android plugin patches

After `flutter pub get`, the following patches are applied under the pub cache so the Android build succeeds. If you clean the cache or the plugin is updated, re-apply as needed.

**Plugin:** `flutter_native_timezone` 2.0.0  
**Path:** `$(flutter pub cache path)/hosted/pub.dev/flutter_native_timezone-2.0.0/android/`

## 1. Namespace (AGP 8+)

In `android/build.gradle`, inside the `android { }` block, add as the first line:

```groovy
namespace 'com.whelksoft.flutter_native_timezone'
```

## 2. JVM target alignment

In the same `android { }` block, add:

```groovy
compileOptions {
    sourceCompatibility JavaVersion.VERSION_1_8
    targetCompatibility JavaVersion.VERSION_1_8
}
kotlinOptions {
    jvmTarget = '1.8'
}
```

## 3. Remove deprecated v1 embedding

In `android/src/main/kotlin/.../FlutterNativeTimezonePlugin.kt`:

- Remove the line: `import io.flutter.plugin.common.PluginRegistry.Registrar`
- Remove the entire `companion object { ... registerWith(registrar: Registrar) ... }` block (the backward-compatibility with Flutter API v1).

## 4. App: core library desugaring

Already in the project: `android/app/build.gradle.kts` has `isCoreLibraryDesugaringEnabled = true` and `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")` for `flutter_local_notifications`.

## Optional: re-apply script

From project root after `flutter pub get`:

```bash
chmod +x scripts/patch_android_plugins.sh
./scripts/patch_android_plugins.sh
```

Then fix any remaining steps manually if the script doesn’t apply them (e.g. the Kotlin Registrar removal).
