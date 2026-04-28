# iOS / Xcode Build Readiness Report — Match Vibe (`zztherapy` Flutter app)

**Audit date:** 2026-04-28
**Project:** `D:\zztherapy\frontend`
**App name:** Match Vibe
**Bundle id (iOS):** `com.matchvibe.app`
**Pubspec version:** `1.0.0+28`
**Flutter SDK constraint:** `^3.10.7`
**iOS deployment target:** `13.0`

---

## 1. TL;DR / Verdict

**Status: NOT READY to build in Xcode for iOS as-is.**

The Dart/Flutter side of the project is in good shape and the iOS host project (`ios/Runner.xcodeproj`, `Runner.xcworkspace`, `AppDelegate.swift`, `Info.plist`, `Assets.xcassets`) exists and is mostly wired correctly. However, several **hard blockers** must be resolved before `flutter build ios` or an Xcode archive will succeed:

1. The CocoaPods `Podfile` is **missing** from `ios/`.
2. `ios/Runner/GoogleService-Info.plist` is **missing** (Firebase iOS will not initialize).
3. There is **no `Runner.entitlements`** file (push notifications, background modes, VoIP all rely on it).
4. The current build host is **Windows** — iOS builds require macOS + Xcode 15+ + CocoaPods.

Once a Mac developer runs `flutter pub get` (which auto-generates the Podfile) and adds the Firebase plist + entitlements + a few Info.plist keys, the project should compile. There are also several **medium-priority** items (Google Sign-In URL scheme, `LSApplicationQueriesSchemes`, write-to-photos description, `permission_handler` Pod flags, bumped iOS deployment target, code signing team) that are not strictly build-breaking but will cause silent runtime breakage of features that the app actively uses.

Estimated time on a Mac to get a first **debug build to a real iPhone**: ~30–60 minutes (mostly waiting on `pod install` to fetch ~150MB of WebRTC frameworks).
Estimated time to a **TestFlight-uploadable archive**: half a day, plus Apple Developer Program enrollment if not already done.

---

## 2. Environment & host requirements

You **cannot** build this app on Windows. iOS toolchain is macOS-only.

| Requirement                  | Minimum                                                  | Why                                                   |
| ---------------------------- | -------------------------------------------------------- | ----------------------------------------------------- |
| macOS                        | 13 Ventura or later (14 Sonoma recommended)              | Xcode 15+ requires it                                 |
| Xcode                        | 15.x or later                                            | App Store submissions, iOS 17 SDK, modern Swift       |
| Command Line Tools           | Latest                                                   | `xcode-select --install`                              |
| CocoaPods                    | 1.13+                                                    | `sudo gem install cocoapods` (or via Homebrew)        |
| Flutter SDK                  | matching `^3.10.7` (project pubspec)                     | Re-running `flutter pub get` regenerates Pod plumbing |
| Ruby                         | 3.0+ (system Ruby 2.6 may need workaround)               | CocoaPods runs on Ruby                                |
| Apple Developer Program      | $99/yr for distribution + push                           | Required for code signing on a real device + APNs key |
| Physical iPhone (recommended) | iOS 13+                                                  | Many plugins (camera, mic, push, calls) don't work fully on simulator |
| `git` + access to this repo  | —                                                        | Project is currently on Windows; transfer via git     |

The `Generated.xcconfig` currently points to `FLUTTER_ROOT=C:\Users\user\flutter1\flutter` — this Windows path will be **automatically overwritten** when you run `flutter pub get` on the Mac. No manual fix needed.

---

## 3. Inventory of what was checked

The following project artifacts were inspected during this audit:

**Flutter / Dart side**

- [`pubspec.yaml`](../pubspec.yaml) — 33+ runtime plugins, dependency overrides, asset list, launcher icon config.
- [`pubspec.lock`](../pubspec.lock) — resolved transitive plugins.
- [`.flutter-plugins-dependencies`](../.flutter-plugins-dependencies) — final list of native plugins per platform.
- [`lib/main.dart`](../lib/main.dart) — entry point, Firebase init, FCM background handler, dotenv, security-service init.
- [`lib/firebase_options.dart`](../lib/firebase_options.dart) — FlutterFire-generated options with `iosBundleId: 'com.matchvibe.app'`.
- [`lib/features/video/services/security_service.dart`](../lib/features/video/services/security_service.dart) — method channel `com.zztherapy/security` used by both Android and iOS.
- `.env.development`, `.env.production`, `.env.example` — environment files (loaded at runtime via `flutter_dotenv`).

**iOS host project**

- [`ios/Runner/Info.plist`](../ios/Runner/Info.plist)
- [`ios/Runner/AppDelegate.swift`](../ios/Runner/AppDelegate.swift)
- [`ios/Runner/GeneratedPluginRegistrant.h`](../ios/Runner/GeneratedPluginRegistrant.h) / [`.m`](../ios/Runner/GeneratedPluginRegistrant.m)
- [`ios/Runner/Runner-Bridging-Header.h`](../ios/Runner/Runner-Bridging-Header.h)
- [`ios/Runner/Assets.xcassets/AppIcon.appiconset/`](../ios/Runner/Assets.xcassets/AppIcon.appiconset/) (full icon set 20→1024)
- [`ios/Runner/Assets.xcassets/LaunchImage.imageset/`](../ios/Runner/Assets.xcassets/LaunchImage.imageset/)
- [`ios/Runner/Base.lproj/LaunchScreen.storyboard`](../ios/Runner/Base.lproj/LaunchScreen.storyboard)
- [`ios/Runner/Base.lproj/Main.storyboard`](../ios/Runner/Base.lproj/Main.storyboard)
- [`ios/Runner.xcodeproj/project.pbxproj`](../ios/Runner.xcodeproj/project.pbxproj)
- [`ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`](../ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme)
- [`ios/Runner.xcworkspace/contents.xcworkspacedata`](../ios/Runner.xcworkspace/contents.xcworkspacedata)
- [`ios/Flutter/AppFrameworkInfo.plist`](../ios/Flutter/AppFrameworkInfo.plist)
- [`ios/Flutter/Debug.xcconfig`](../ios/Flutter/Debug.xcconfig), [`Release.xcconfig`](../ios/Flutter/Release.xcconfig), [`Generated.xcconfig`](../ios/Flutter/Generated.xcconfig)
- [`ios/RunnerTests/RunnerTests.swift`](../ios/RunnerTests/RunnerTests.swift)
- [`ios/.gitignore`](../ios/.gitignore)

**Android side (cross-checked for parity)**

- [`android/app/build.gradle.kts`](../android/app/build.gradle.kts)
- [`android/app/src/main/AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml)
- [`android/app/google-services.json`](../android/app/google-services.json) — exists (iOS equivalent does NOT)

**Files notably missing from the iOS host project**

- `ios/Podfile` (auto-generated by Flutter on first run, but absent from VCS)
- `ios/Podfile.lock`
- `ios/Pods/` (correctly gitignored)
- `ios/Runner/GoogleService-Info.plist`
- `ios/Runner/Runner.entitlements`
- `ios/Runner/RunnerDebug.entitlements` / Release entitlements (optional split)

---

## 4. Hard blockers (project will not build / app will not run on iOS)

### 4.1 Missing `ios/Podfile`

**Impact:** Without a Podfile, CocoaPods cannot resolve any of the 33+ iOS-side native plugins (Firebase, WebRTC, Stream Video/Chat, secure storage, photo manager, etc.). `flutter build ios` will fail at the linking stage. Xcode itself will refuse to build because the workspace cannot resolve `Pods.framework`.

**Why it's missing:** `ios/Podfile` is normally created by Flutter the first time `flutter pub get` runs on a Mac. Because this project has only ever been touched on Windows, the file was never generated. The `.gitignore` does **not** ignore `Podfile` itself (only `Pods/`), so once it exists it should be committed.

**Resolution (on Mac):**

1. `cd frontend && flutter pub get` — generates `ios/Podfile` automatically.
2. Edit the generated file to:
   - Set `platform :ios, '14.0'` (see §5.6 — 13.0 will not satisfy several pods).
   - Add a `post_install` block that injects `permission_handler` preprocessor flags (see §5.5).
3. `cd ios && pod install --repo-update`.
4. Commit `Podfile` and `Podfile.lock` (do NOT commit `Pods/`).

### 4.2 Missing `ios/Runner/GoogleService-Info.plist`

**Impact:** Firebase iOS SDK requires this plist at runtime. Without it:

- `firebase_core` will throw on startup (currently caught and logged in [`lib/main.dart`](../lib/main.dart) line 110-121, but the app will run in a degraded "auth-broken" state).
- `firebase_auth` (Google Sign-In, phone auth) will not work.
- `firebase_messaging` (push) cannot register an APNs token.
- `firebase_storage` uploads/downloads will fail.

The Android side has [`android/app/google-services.json`](../android/app/google-services.json), confirming the Firebase project is `matchvibe-d55f9` (project number `911372372113`). The iOS counterpart is required.

**Resolution:**

1. Open Firebase Console → project `matchvibe-d55f9` → **Add app** → iOS.
2. Bundle id: **`com.matchvibe.app`** (must match exactly).
3. Download `GoogleService-Info.plist`.
4. Drag it into Xcode → `Runner` group → check "Copy items if needed" + add to `Runner` target.
5. Verify it lives at `ios/Runner/GoogleService-Info.plist` and the file ref appears in `project.pbxproj`.
6. (Required for FCM push) Upload an **APNs Authentication Key** (`.p8`) under Firebase Console → Project Settings → Cloud Messaging → Apple app configuration. Without this, no push tokens will reach Firebase even if the app registers correctly.

### 4.3 Missing `Runner.entitlements`

**Impact:** Multiple plugins in this app rely on entitlements that don't exist yet:

| Plugin                              | Required entitlement                                                                            |
| ----------------------------------- | ----------------------------------------------------------------------------------------------- |
| `firebase_messaging`                | `aps-environment` = `development` / `production`                                                |
| `flutter_local_notifications`       | (none, but needs notification permission flow)                                                  |
| `stream_video_push_notification`    | `aps-environment` + Background Modes (`voip`, `audio`, `remote-notification`) + PushKit/CallKit |
| `stream_video_flutter` (calls)      | Background Modes (`audio`, `voip`)                                                              |
| `just_audio` (background ringtones) | Background Modes (`audio`)                                                                      |
| `app_links` (custom-scheme deep links) | none required (URL types in Info.plist suffice — already present)                            |
| Future Universal Links (https://)   | `com.apple.developer.associated-domains`                                                        |
| Sign In with Apple (if added)       | `com.apple.developer.applesignin`                                                               |

**Resolution:** Create `ios/Runner/Runner.entitlements` and add it to the Runner target's "Signing & Capabilities" tab in Xcode. At minimum, for this app:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>development</string>
</dict>
</plist>
```

Plus add the following to `Info.plist` (these are plist keys, NOT entitlements, but live on the same Capabilities screen):

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>voip</string>
    <string>remote-notification</string>
    <string>fetch</string>
</array>
```

For Release/TestFlight, change `aps-environment` to `production` in a separate `RunnerRelease.entitlements` (or rely on Xcode's auto-managed signing to set it).

### 4.4 Build host is Windows

**Impact:** Hard requirement — iOS toolchain (Xcode, simulator, codesign, lipo, otool, security, plutil, xcrun, xcodebuild) is macOS-only. Cross-compilation from Windows is not supported by Apple.

**Resolution options:**

1. **Use a Mac** (preferred) — local development.
2. **Mac mini in Apple's data center** via [MacinCloud](https://www.macincloud.com/) or [MacStadium](https://www.macstadium.com/). Roughly $20–30/mo.
3. **CI with a macOS runner** — GitHub Actions (`macos-14` / `macos-15`), Codemagic, Bitrise, or Xcode Cloud. Useful for automated TestFlight uploads but more setup.

If you only need an occasional build, the simplest path is GitHub Actions + a `.github/workflows/ios.yml` that runs `flutter build ipa`.

---

## 5. High-priority gaps (build may succeed but features will silently break)

### 5.1 Google Sign-In URL scheme missing

The Dart code uses `google_sign_in` (pubspec line 30), which on iOS requires the `REVERSED_CLIENT_ID` from `GoogleService-Info.plist` to be registered as a `CFBundleURLSchemes` entry in [`Info.plist`](../ios/Runner/Info.plist). Currently only `zztherapy` and `app` schemes are present.

**Symptom if not fixed:** Tapping "Sign in with Google" opens Safari/Chrome, the OAuth flow completes, but iOS doesn't know which app to return to → user is stuck on a Google page indefinitely.

**Fix:** Add a third dict to the existing `CFBundleURLTypes` array with `CFBundleURLSchemes = ["com.googleusercontent.apps.911372372113-XXXXXXXX"]` (the value comes from `GoogleService-Info.plist` once it's downloaded — open the plist and copy the `REVERSED_CLIENT_ID` value verbatim).

### 5.2 No PushKit / CallKit wiring for Stream Video

The pubspec includes `stream_video_push_notification: ^1.3.1` (line 73), but a search of `lib/` for `PushKit`, `CallKit`, `VoIP`, or `StreamVideoPush` returns **no matches**. iOS specifically requires:

- A PushKit registry registered in `AppDelegate` (or via the plugin's setup helper).
- A CallKit `CXProvider` so the system can render the native incoming-call UI.
- The `voip` background mode + `aps-environment` entitlement.
- A separate **VoIP push certificate** uploaded to Stream's dashboard.

**Symptom if not fixed:** Incoming calls when the app is killed or backgrounded simply don't ring. Foreground calls (while the app is open) may still work because they ride on the websocket connection.

**Fix:** Follow the official Stream Video iOS push setup guide — usually involves adding `StreamVideoPushNotificationManager.setup(...)` in [`lib/main.dart`](../lib/main.dart), uploading a VoIP push cert, and adding `import PushKit` glue in `AppDelegate.swift`. See the Stream docs ([streamVideoDocs.md](../streamVideoDocs.md) which is committed in this repo) for specifics.

### 5.3 Missing `LSApplicationQueriesSchemes`

`url_launcher: ^6.3.1` is used to open external apps/URLs. On iOS 9+, attempting to query whether a scheme can be opened (`canLaunchUrl`) for any scheme NOT in `LSApplicationQueriesSchemes` returns `false` and logs a warning, even when the target app is installed.

**Add to `Info.plist`** the schemes the app actually uses (review `lib/` for `launchUrl`/`launchUrlString` calls). Common ones for this kind of app:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>tel</string>
    <string>mailto</string>
    <string>https</string>
    <string>http</string>
    <string>sms</string>
    <string>whatsapp</string>
</array>
```

### 5.4 Missing `NSPhotoLibraryAddUsageDescription`

The pubspec includes `gal: ^...` (transitively, via stream/photo plugins) and `image_picker`/`photo_manager`. iOS distinguishes between:

- `NSPhotoLibraryUsageDescription` — **read** (already present in [`Info.plist`](../ios/Runner/Info.plist) line 68).
- `NSPhotoLibraryAddUsageDescription` — **write** (saving to camera roll). **Missing.**

**Symptom if not fixed:** App crashes the first time `Gal.putImage(...)` (or any "save" call) is invoked, with a console message about a missing privacy description. App Store review will reject the build.

### 5.5 `permission_handler` requires Pod preprocessor flags

`permission_handler_apple` ships every permission's native code in a single pod. To opt-in to specific permissions, you set preprocessor flags inside `Podfile`'s `post_install`:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_CAMERA=1',
        'PERMISSION_MICROPHONE=1',
        'PERMISSION_PHOTOS=1',
        'PERMISSION_NOTIFICATIONS=1',
      ]
    end
  end
end
```

**Symptom if omitted:** `Permission.camera.request()` returns `denied` on first call without ever showing the system prompt. Same for microphone, photos, etc. — the very permissions this app needs for video calls.

### 5.6 iOS deployment target = 13.0 is likely too low

[`Generated.xcconfig`](../ios/Flutter/Generated.xcconfig) and [`AppFrameworkInfo.plist`](../ios/Flutter/AppFrameworkInfo.plist) both declare `MinimumOSVersion = 13.0`. Several pods used by this project demand higher minimums:

- `firebase_core 4.x` / `firebase_auth 6.x` / `firebase_messaging 16.x` — typically need iOS 13 or 15.
- `stream_webrtc_flutter 2.2.6` — iOS 13 (works) but the underlying `WebRTC.framework` slice is large and ships only modern targets.
- `flutter_local_notifications 18.x` — iOS 12+ but communication notifications need iOS 15.
- `record_ios`, `photo_manager`, `gal` — generally iOS 13+.

When `pod install` runs, CocoaPods will print warnings and **bump** the minimum to whatever the strictest pod requires (often 14 or 15). Be prepared to set `IPHONEOS_DEPLOYMENT_TARGET = 14.0` in:

1. `Podfile` first line: `platform :ios, '14.0'`.
2. `Runner.xcodeproj` Build Settings → `iOS Deployment Target` → `14.0` (Debug + Release + Profile, plus the project-level setting).
3. `ios/Flutter/AppFrameworkInfo.plist` → `MinimumOSVersion` → `14.0`.

---

## 6. Medium-priority observations

### 6.1 Code signing is not pre-configured

`project.pbxproj` for the Runner target has only `"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "iPhone Developer"`. There is no `DEVELOPMENT_TEAM`, no `CODE_SIGN_STYLE = Automatic`, and no provisioning profile reference. This is normal for an open-source/cross-developer Flutter project but means the **first** Xcode build on a new Mac will fail with:

> Signing for "Runner" requires a development team.

**Resolution:** Open `Runner.xcworkspace` in Xcode → select the `Runner` target → **Signing & Capabilities** → check **Automatically manage signing** → pick the Apple ID team. Xcode will then write `DEVELOPMENT_TEAM` into `pbxproj`. Whether to commit that change depends on whether all developers share a team.

### 6.2 Custom "secure window" hack in AppDelegate

[`AppDelegate.swift`](../ios/Runner/AppDelegate.swift) lines 101–125 implement an unusual technique: it creates an off-screen `UITextField` with `isSecureTextEntry = true`, inserts the app's `UIWindow.layer` as a sublayer of the secure text field's layer, and relies on iOS treating that whole subtree as DRM-protected content (so screen recording / screenshots show a black frame).

This is a common community trick but it is **undocumented Apple behavior** and could break in any future iOS release. Recommendations:

- QA-test on iOS 17 and iOS 18 specifically. If it stops working, fall back to listening for `UIScreen.capturedDidChangeNotification` (already done at line 81) and showing the existing `captureShieldView`.
- Be aware that App Store review has occasionally flagged similar techniques — keep a non-Secure fallback path ready.

### 6.3 Bundle identifier registration

`com.matchvibe.app` must exist as an **App ID** in [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list) before you can:

- Generate a development/distribution provisioning profile.
- Enable Push Notifications, Sign In with Apple, Associated Domains, etc.

If "Match Vibe" is the brand and you may want a more polished id (`io.matchvibe.app` or `app.matchvibe.ios`), now is the time — once it's on the App Store the bundle id is permanent.

### 6.4 Orientations include landscape

[`Info.plist`](../ios/Runner/Info.plist) lines 31-43 declare both portrait AND landscape support. This is fine for a video-call app, but only if every screen actually handles landscape. If the UI is portrait-only in practice, drop:

```xml
<string>UIInterfaceOrientationLandscapeLeft</string>
<string>UIInterfaceOrientationLandscapeRight</string>
```

…to avoid layout bugs. App Store review has rejected apps that "support" landscape with broken layouts.

### 6.5 Launch screen uses legacy LaunchImage

[`LaunchScreen.storyboard`](../ios/Runner/Base.lproj/LaunchScreen.storyboard) renders the `LaunchImage` asset (the README in `LaunchImage.imageset/` notes these are the default Flutter placeholders). It works, but for a polished App Store listing consider:

- Replacing the storyboard with a branded layout (logo + brand color background).
- The `flutter_launcher_icons` config (pubspec line 113-120) doesn't currently regenerate the launch screen — only the app icon.

### 6.6 App icon is in good shape

[`Assets.xcassets/AppIcon.appiconset/`](../ios/Runner/Assets.xcassets/AppIcon.appiconset/) contains a complete set (20→1024) and the `pubspec.yaml` config sets `remove_alpha_ios: true` (App Store requires opaque icons). No action needed unless you change the source `lib/assets/app_logo.png`.

### 6.7 Test target exists and is configured

`RunnerTests` target has correct `BUNDLE_LOADER` / `TEST_HOST` and uses `Automatic` signing. No iOS-specific tests are written, but the scaffolding is fine.

### 6.8 Generated paths point to Windows

`ios/Flutter/Generated.xcconfig` line 2 (`FLUTTER_ROOT=C:\Users\user\flutter1\flutter`) and `ios/Flutter/flutter_export_environment.sh` are auto-generated by Flutter. They will be **rewritten** on the Mac the moment you run `flutter pub get`. Do not edit them manually; they are correctly listed in `ios/.gitignore`.

---

## 7. What IS already in good shape

- Folder structure is canonical: `ios/Flutter/`, `ios/Runner/`, `ios/Runner.xcodeproj/`, `ios/Runner.xcworkspace/`, `ios/RunnerTests/`.
- [`Runner.xcscheme`](../ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme) is shared — clones won't lose it.
- [`AppDelegate.swift`](../ios/Runner/AppDelegate.swift) calls `GeneratedPluginRegistrant.register(with: self)` and sets up the security method channel correctly.
- Bundle id parity: `lib/firebase_options.dart` `iosBundleId = 'com.matchvibe.app'` matches `PRODUCT_BUNDLE_IDENTIFIER` in [`project.pbxproj`](../ios/Runner.xcodeproj/project.pbxproj).
- App version `1.0.0+28` (pubspec) matches `FLUTTER_BUILD_NAME=1.0.0` / `FLUTTER_BUILD_NUMBER=28` (Generated.xcconfig).
- Privacy strings present: `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, `NSPhotoLibraryUsageDescription`.
- URL types for `zztherapy://` and `app://` deep links are configured (parity with Android intent filters).
- `LSRequiresIPhoneOS = true`, `CADisableMinimumFrameDurationOnPhone = true`, `UIApplicationSupportsIndirectInputEvents = true` — all modern best-practice flags.
- `ENABLE_BITCODE = NO` (Bitcode was removed in Xcode 14).
- `EXCLUDED_ARCHS[sdk=iphonesimulator*] = i386` (correct for arm64 Macs).
- `TARGETED_DEVICE_FAMILY = "1,2"` (iPhone + iPad supported).
- Full `AppIcon.appiconset` from 20pt @1x up to 1024×1024 marketing icon.
- The generated `GeneratedPluginRegistrant.m` registers all 33 iOS plugins correctly.
- `ios/.gitignore` correctly excludes `Pods/`, `xcuserdata/`, `.symlinks/`, `Flutter/Flutter.framework`, `Flutter/Generated.xcconfig`, `Flutter/flutter_export_environment.sh`, `Flutter/ephemeral/`, etc.

---

## 8. Plugin-by-plugin iOS impact matrix

Derived from [`.flutter-plugins-dependencies`](../.flutter-plugins-dependencies) (all plugins listed under the `"ios"` array) and the matching imports in [`GeneratedPluginRegistrant.m`](../ios/Runner/GeneratedPluginRegistrant.m).

Legend:

- ✅ = no extra iOS config needed
- 🟡 = needs Info.plist key, entitlement, or Pod flag
- 🔴 = needs significant native setup (entitlement + AppDelegate code + provisioning)

| Plugin                              | Status | iOS-side requirement                                                                                          |
| ----------------------------------- | :----: | ------------------------------------------------------------------------------------------------------------- |
| `app_links`                         |   🟡   | URL types in Info.plist (✅ already present for `zztherapy`/`app`). For https Universal Links, add `com.apple.developer.associated-domains` entitlement. |
| `audio_session`                     |   ✅   | Auto-configures `AVAudioSession` at runtime.                                                                  |
| `battery_plus`                      |   ✅   | None.                                                                                                         |
| `connectivity_plus`                 |   ✅   | None.                                                                                                         |
| `device_info_plus`                  |   ✅   | None (does NOT require `NSUserTrackingUsageDescription` unless you call IDFA APIs).                           |
| `file_picker`                       |   🟡   | If using documents/iCloud, add `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` keys.            |
| `file_selector_ios`                 |   ✅   | None for basic file picking.                                                                                  |
| `firebase_auth`                     |   🔴   | `GoogleService-Info.plist` (§4.2). Sign In with Apple needs entitlement if used. Phone auth needs a reCAPTCHA URL scheme. |
| `firebase_core`                     |   🔴   | `GoogleService-Info.plist` (§4.2).                                                                            |
| `firebase_messaging`                |   🔴   | APS entitlement, APNs auth key uploaded in Firebase, background mode `remote-notification`, explicit notification permission flow. |
| `firebase_storage`                  |   ✅   | None beyond core Firebase setup.                                                                              |
| `flutter_local_notifications`       |   🟡   | iOS 12+ permission flow at runtime; for "communication" / categories add the `Notification Service Extension` (optional). |
| `flutter_secure_storage`            |   ✅   | Uses Keychain; works out of the box. (Optional: enable Keychain Sharing entitlement for app-group access.)    |
| `gal`                               |   🟡   | **`NSPhotoLibraryAddUsageDescription` required** (§5.4).                                                      |
| `get_thumbnail_video`               |   ✅   | None.                                                                                                         |
| `google_sign_in_ios`                |   🔴   | **Requires `REVERSED_CLIENT_ID` URL scheme in Info.plist** (§5.1) AND `GoogleService-Info.plist` present.     |
| `image_picker_ios`                  |   🟡   | Uses `NSCameraUsageDescription` (✅) + `NSPhotoLibraryUsageDescription` (✅). Add `NSPhotoLibraryAddUsageDescription` if saving. |
| `just_audio`                        |   🟡   | For background audio (ringtones), enable `audio` background mode + configure `AVAudioSession.category = .playback`. |
| `media_kit_video`                   |   🟡   | Uses native AVPlayer — add `NSAppTransportSecurity` if your media URLs are HTTP (the project already gates this on Android via `usesCleartextTraffic`). |
| `package_info_plus`                 |   ✅   | None.                                                                                                         |
| `path_provider_foundation`          |   ✅   | None.                                                                                                         |
| `permission_handler_apple`          |   🔴   | **Pod preprocessor flags required** (§5.5). Without them, every `.request()` call returns `.denied`.          |
| `photo_manager`                     |   🟡   | `NSPhotoLibraryUsageDescription` (✅) + `NSPhotoLibraryAddUsageDescription` (missing) for write access.       |
| `record_ios`                        |   🟡   | `NSMicrophoneUsageDescription` (✅). Background recording needs `audio` background mode.                      |
| `share_plus`                        |   ✅   | None.                                                                                                         |
| `shared_preferences_foundation`     |   ✅   | None.                                                                                                         |
| `sqflite_darwin`                    |   ✅   | None.                                                                                                         |
| `stream_video_flutter`              |   🔴   | `audio` and `voip` background modes; pulls in `WebRTC.framework`. Bumps min iOS target.                       |
| `stream_video_push_notification`    |   🔴   | **Full PushKit + CallKit setup required** (§5.2). Separate VoIP push cert. `voip` background mode. AppDelegate glue. |
| `stream_webrtc_flutter`             |   🟡   | `NSCameraUsageDescription` + `NSMicrophoneUsageDescription` (both ✅). Large pod (~150MB on first install).   |
| `thermal`                           |   ✅   | None.                                                                                                         |
| `url_launcher_ios`                  |   🟡   | **`LSApplicationQueriesSchemes` recommended** (§5.3).                                                         |
| `video_player_avfoundation`         |   ✅   | None (uses AVPlayer).                                                                                         |
| `wakelock_plus`                     |   ✅   | None.                                                                                                         |

**Summary:** of 33 iOS plugins, **6 are red** (need real native work) and **10 are yellow** (need a plist key, entitlement, or Pod flag).

---

## 9. Step-by-step "what to do on the Mac" sequence

This is the path from a fresh checkout on a Mac to a working `Runner.app` on a real iPhone.

### 9.1 One-time machine setup

```bash
# Xcode (App Store) and Command Line Tools
xcode-select --install
sudo xcodebuild -license accept

# CocoaPods
sudo gem install cocoapods
pod --version    # expect 1.13+

# Flutter (matching ^3.10.7)
git clone https://github.com/flutter/flutter.git -b stable ~/flutter
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
flutter doctor -v
```

`flutter doctor` should show ✓ for **Xcode**, **CocoaPods**, and **iOS toolchain**. Resolve any ✗ before continuing.

### 9.2 Get the project on the Mac

```bash
cd ~/code
git clone <this-repo-url> zztherapy
cd zztherapy/frontend
```

### 9.3 Generate Flutter+CocoaPods plumbing

```bash
flutter pub get
# This regenerates:
#   ios/Flutter/Generated.xcconfig (FLUTTER_ROOT now points at ~/flutter)
#   ios/Flutter/flutter_export_environment.sh
#   ios/Podfile (NEW — does not exist on disk yet)
#   ios/Runner/GeneratedPluginRegistrant.m (already up-to-date)
```

### 9.4 Edit the generated `ios/Podfile`

After step 9.3, open `ios/Podfile` and:

1. Set `platform :ios, '14.0'` at the top.
2. Add the `permission_handler` flags inside `post_install` (see §5.5).

Then:

```bash
cd ios
pod install --repo-update
cd ..
```

The first `pod install` will download ~150MB (`WebRTC.framework`) and may take 5–15 minutes.

### 9.5 Add Firebase iOS plist

1. In Firebase Console, register an iOS app for project `matchvibe-d55f9` with bundle id `com.matchvibe.app`.
2. Download `GoogleService-Info.plist`.
3. Open `ios/Runner.xcworkspace` (NOT `.xcodeproj`) in Xcode.
4. Drag the plist into the `Runner` group → check "Copy items if needed" + "Runner" target.
5. Confirm the file lives at `ios/Runner/GoogleService-Info.plist`.

### 9.6 Update `Info.plist`

Add (manually or via Xcode's plist editor):

- `NSPhotoLibraryAddUsageDescription` — "We save photos and clips you capture in calls to your library."
- `LSApplicationQueriesSchemes` — array with `tel`, `mailto`, `https`, `http`, `sms`, plus any others your code launches.
- `UIBackgroundModes` — array with `audio`, `voip`, `remote-notification`, `fetch`.
- A new dict in `CFBundleURLTypes` with `CFBundleURLSchemes = ["com.googleusercontent.apps.911372372113-XXXXXXXX"]` (copy `REVERSED_CLIENT_ID` from `GoogleService-Info.plist` verbatim).

### 9.7 Add capabilities in Xcode

In Xcode → `Runner` target → **Signing & Capabilities**:

1. Set **Team** (Apple ID team).
2. Click **+ Capability** → add **Push Notifications** (creates `Runner.entitlements` automatically with `aps-environment = development`).
3. Add **Background Modes** → check `Audio, AirPlay, and Picture in Picture`, `Voice over IP`, `Background fetch`, `Remote notifications`.
4. (Optional) **Sign In with Apple** if you plan to use it.
5. (Optional) **Associated Domains** if you plan to use Universal Links.

### 9.8 Wire Stream Video VoIP (if you want background ringing)

This is the biggest piece of work. Follow the [Stream docs](https://getstream.io/video/docs/flutter/advanced/push-notifications/) — at a high level:

1. Generate a VoIP services certificate in Apple Developer portal.
2. Upload it to Stream's dashboard.
3. Add `import PushKit` + `PKPushRegistry` setup to `AppDelegate.swift`.
4. Call `StreamVideoPushNotificationManager.setup(...)` from Dart in `lib/main.dart` after Firebase init.
5. Test with a real device (CallKit doesn't work on simulator).

### 9.9 First debug build

Plug in an iPhone, unlock it, trust the Mac, then:

```bash
cd ~/code/zztherapy/frontend
flutter devices            # confirm iPhone shows up
flutter run -d <iphone-id>
```

Expected first-run log lines:

- `Running pod install...` (skipped if cache is warm)
- `Building Runner for iPhone...`
- `Xcode build done.`
- `Configuring iPhone for development...` (one-time per device)
- App launches, you see the env-loaded debug print, Firebase initializes, login screen renders.

### 9.10 Release archive (TestFlight)

```bash
flutter build ipa --release
# Output: build/ios/ipa/Runner.ipa
```

Or via Xcode: `Product` → `Archive` → `Distribute App` → `App Store Connect`.

Before uploading you will need:

- App Store Connect record for `com.matchvibe.app`.
- Distribution provisioning profile (auto-created by Xcode if Team is set).
- Production APNs cert/key uploaded to Firebase.
- All App Store metadata (icon, screenshots, privacy policy URL, age rating).

---

## 10. Open questions / things that could not be verified from Windows

These items require human input or access outside of the local repo:

1. **Apple Developer Program membership** — Do you (or your team) already have an active enrollment? Required for any device deployment beyond the simulator.
2. **Bundle id reservation** — Has `com.matchvibe.app` been registered as an App ID in Apple Developer Portal? If not, decide on the final bundle id BEFORE TestFlight.
3. **Firebase iOS app** — There is no iOS app registered in the Firebase project yet (no `GoogleService-Info.plist` in the repo). Even though `lib/firebase_options.dart` contains an iOS API key, the runtime SDK still needs the plist file.
4. **APNs Auth Key (.p8)** — Has one been generated and uploaded to Firebase Cloud Messaging settings? Required for FCM push to actually deliver to iOS devices.
5. **VoIP Services Certificate** — Does one exist for `com.matchvibe.app`? Required for Stream Video background-ring CallKit notifications.
6. **App Store Connect record** — Has the app been created in App Store Connect?
7. **Sign In with Apple** — App Store Review Guideline 4.8 may force this if Google Sign-In is offered as the only social login. Worth deciding now.
8. **Stream Video / Stream Chat iOS-specific tokens** — Does the backend issue iOS-tagged push tokens? Some Stream setups require platform-specific configuration on the server.
9. **Universal Links vs custom-scheme deep links** — The current setup uses custom `zztherapy://` schemes (works, but less polished). If https-based deep links are wanted, an `apple-app-site-association` file must be hosted on the website plus the Associated Domains entitlement added.
10. **Razorpay / wallet checkout flow** — `razorpay_flutter_documentation.md` is committed but the package isn't in `pubspec.yaml`. Confirm whether iOS payments are required for v1; if so, an additional pod and Info.plist URL scheme entries will be needed.
11. **Privacy manifest (`PrivacyInfo.xcprivacy`)** — As of 2024, App Store submissions require a privacy manifest declaring "Required Reason API" usage. Some plugins (e.g., `device_info_plus`, `path_provider_foundation`, `package_info_plus`) ship their own manifest; you'll likely need a top-level manifest for the Runner app too.
12. **Test devices** — Is there at least one iPhone available to test on? CallKit, push, and many camera/mic flows do not work on the simulator.

---

## Appendix A: One-page action checklist

Print and tick off:

- [ ] Get a Mac (or cloud Mac) with Xcode 15+.
- [ ] `xcode-select --install`, `sudo gem install cocoapods`, install Flutter.
- [ ] `git clone` and `cd frontend && flutter pub get`.
- [ ] Edit generated `ios/Podfile`: `platform :ios, '14.0'` + `permission_handler` flags.
- [ ] `cd ios && pod install --repo-update`.
- [ ] Register Firebase iOS app, download `GoogleService-Info.plist`, drop into `ios/Runner/`.
- [ ] Upload APNs `.p8` to Firebase Cloud Messaging.
- [ ] Add to `Info.plist`: `NSPhotoLibraryAddUsageDescription`, `LSApplicationQueriesSchemes`, `UIBackgroundModes`, Google `REVERSED_CLIENT_ID` URL scheme.
- [ ] Open `Runner.xcworkspace` in Xcode → set Team → add Push Notifications + Background Modes capabilities.
- [ ] Bump `IPHONEOS_DEPLOYMENT_TARGET` to 14 (or whatever pods require).
- [ ] (Optional but needed for background calls) Stream Video PushKit/CallKit setup + VoIP cert.
- [ ] `flutter run -d <iphone>` on a real device.
- [ ] Test camera, mic, push, Google Sign-In, Stream chat, Stream video call.
- [ ] `flutter build ipa --release` → upload to TestFlight.

---

## Appendix B: File reference index

Relative paths assume this report is at `frontend/docs/IOS_BUILD_READINESS.md`.

| What                          | Path                                                                                                |
| ----------------------------- | --------------------------------------------------------------------------------------------------- |
| Pubspec                       | [`../pubspec.yaml`](../pubspec.yaml)                                                                |
| Firebase options (iOS+Android) | [`../lib/firebase_options.dart`](../lib/firebase_options.dart)                                     |
| App entry point               | [`../lib/main.dart`](../lib/main.dart)                                                              |
| Security service (MethodChannel) | [`../lib/features/video/services/security_service.dart`](../lib/features/video/services/security_service.dart) |
| iOS Info.plist                | [`../ios/Runner/Info.plist`](../ios/Runner/Info.plist)                                              |
| iOS AppDelegate               | [`../ios/Runner/AppDelegate.swift`](../ios/Runner/AppDelegate.swift)                                |
| Generated plugin registrant   | [`../ios/Runner/GeneratedPluginRegistrant.m`](../ios/Runner/GeneratedPluginRegistrant.m)            |
| Xcode project file            | [`../ios/Runner.xcodeproj/project.pbxproj`](../ios/Runner.xcodeproj/project.pbxproj)                |
| Xcode shared scheme           | [`../ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`](../ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme) |
| Generated.xcconfig            | [`../ios/Flutter/Generated.xcconfig`](../ios/Flutter/Generated.xcconfig)                            |
| AppFrameworkInfo.plist        | [`../ios/Flutter/AppFrameworkInfo.plist`](../ios/Flutter/AppFrameworkInfo.plist)                    |
| Plugin dependency manifest    | [`../.flutter-plugins-dependencies`](../.flutter-plugins-dependencies)                              |
| Android counterpart manifest  | [`../android/app/src/main/AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml)        |
| Android `google-services.json` | [`../android/app/google-services.json`](../android/app/google-services.json)                        |

---

*End of report.*
