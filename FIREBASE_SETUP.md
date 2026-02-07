powershell -ExecutionPolicy Bypass -File .\setup-adb-tunnels.ps1












# Firebase Setup Instructions

## The Error You're Seeing

If you see: `[core/no-app] No Firebase App '[DEFAULT]' has been created`, it means Firebase hasn't been configured yet.

## Quick Fix

Run this command in the `frontend` directory:

```bash
cd frontend
flutterfire configure
```

This will:
1. Connect to your Firebase project
2. Generate `lib/firebase_options.dart` file
3. Configure Android and iOS apps

## Manual Setup (if flutterfire CLI doesn't work)

1. **Create a Firebase project** at https://console.firebase.google.com

2. **Add Android app** to your Firebase project:
   - Package name: `com.example.zztherapy` (check `android/app/build.gradle.kts` for actual package name)
   - Download `google-services.json`
   - Place it in `android/app/`

3. **Add iOS app** (if needed):
   - Bundle ID: Check `ios/Runner.xcodeproj`
   - Download `GoogleService-Info.plist`
   - Place it in `ios/Runner/`

4. **Create `lib/firebase_options.dart`** manually or use:
   ```bash
   flutterfire configure
   ```

## Verify Setup

After running `flutterfire configure`, restart your app:

```bash
flutter run
```

The Firebase initialization error should be resolved.
