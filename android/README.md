# Android build

This is the Android host project for the Bevy 0.19 client. Bevy 0.19 uses the explicit `android-game-activity` feature for GameActivity builds, and current Bevy guidance uses `cargo ndk` to produce `jniLibs` before Gradle builds. The Android Games SDK documents GameActivity as the recommended modern game entry point.

## Build native library

From repository root:

```powershell
./scripts/build-android.ps1 -ServerUrl "http://10.0.2.2:8765"
```

The script builds all common ABIs by default and copies the client assets into `android/app/src/main/assets`.

## Build APK

Open `android/` with Android Studio and run the `app` configuration, or use a locally installed Gradle/Android Studio toolchain:

```powershell
cd android
gradle assembleDebug
```

The repository intentionally does not commit Gradle wrapper binaries or generated `jniLibs`/APK output.
