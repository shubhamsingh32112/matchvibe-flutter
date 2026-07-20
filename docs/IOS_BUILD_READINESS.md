# iOS / Xcode Build Readiness Report — Match Vibe (`zztherapy` Flutter app)

**Audit date:** 2026-07-20 (updated same day — Windows changes applied)  
**Project:** `frontend/` (monorepo path `D:\zztherapy\frontend`)  
**App name:** Match Vibe  
**Bundle id (iOS):** `com.matchvibe.app`  
**Pubspec version:** `1.0.0+80`  
**Flutter SDK constraint:** `^3.10.7`  
**iOS deployment target:** **14.0** (bumped in `AppFrameworkInfo.plist` + `project.pbxproj`; confirm in Podfile on Mac)  
**Firebase project:** `matchvibe-d55f9` (sender `911372372113`)  
**Firebase iOS appId (Dart):** `1:911372372113:ios:3a468aba52d72f1a4d1730`

**Mac-only checklist:** [`IOS_MAC_ONLY_CHANGES.md`](IOS_MAC_ONLY_CHANGES.md) (for MacBook Air M5)  
**Windows code changes (before/after):** [`IOS_WINDOWS_CODE_CHANGES.md`](IOS_WINDOWS_CODE_CHANGES.md)

---

## 1. TL;DR / Verdict

**Status: NOT READY to build or ship on iOS as-is** — remaining work is **Mac / Apple / Firebase** (see Mac checklist). Several Windows-safe items are already applied.

**You cannot build iOS from Windows.** Use your **MacBook Air M5** + Xcode 15+ + CocoaPods. `Generated.xcconfig` Windows `FLUTTER_ROOT` is rewritten on the first `flutter pub get` on the Mac.

| Goal | Estimate on Mac |
|------|-----------------|
| First debug build on a physical iPhone | ~30–60 min |
| Feature-complete (CallKit, etc.) | Half day – 1 day |
| TestFlight / store-ready | Multi-day + product decisions |
| UX polish (Dynamic Island, Live Activities, swipe-back) | Incremental after green build |

### Already done on Windows (2026-07-20)

| Item | Status |
|------|--------|
| `Info.plist` mic string (calls + voice messages) | Done |
| `NSPhotoLibraryAddUsageDescription` | Done |
| `LSApplicationQueriesSchemes` (`https`, `http`, `mailto`, `tel`, `sms`, `whatsapp`) | Done |
| `ITSAppUsesNonExemptEncryption` = false | Done |
| Deployment target 14.0 in pbxproj + AppFrameworkInfo | Done |
| `PrivacyInfo.xcprivacy` file created | Done — **still add to Runner target in Xcode on Mac** |
| Moment share App Store URL branch + `APP_STORE_URL` / `appStoreUrl` | Done |
| Photos `isLimited` treated as usable on iOS | Done |
| Stronger iOS chat haptics (`mediumImpact`) | Done |

### Still Mac-only

Podfile / pods, GoogleService-Info + REVERSED_CLIENT_ID, signing, Push entitlements, CallKit/PushKit, device QA, Sign in with Apple, TestFlight, Dynamic Island / Live Activities, Cupertino swipe-back migration — full list in [`IOS_MAC_ONLY_CHANGES.md`](IOS_MAC_ONLY_CHANGES.md).

---

## 2. What already works

| Item | Location |
|------|----------|
| Bundle id `com.matchvibe.app` | `ios/Runner.xcodeproj/project.pbxproj`, `lib/firebase_options.dart` |
| Display name “Match Vibe” | `ios/Runner/Info.plist` |
| Firebase Dart options for iOS | `lib/firebase_options.dart` (`iosBundleId`) |
| Custom URL schemes `zztherapy`, `app` | `Info.plist` `CFBundleURLTypes` |
| Camera / mic / photo read **and** photo-add usage strings | `Info.plist` |
| Expanded `LSApplicationQueriesSchemes` | `Info.plist` |
| Export compliance key | `Info.plist` `ITSAppUsesNonExemptEncryption` |
| Deep-link Dart handlers (wallet, vip, moments-plan, moment, signup) | `lib/app/widgets/app_lifecycle_wrapper.dart` |
| Security MethodChannel + capture shield | `ios/Runner/AppDelegate.swift`, `lib/features/video/services/security_service.dart` |
| Device fingerprint via `identifierForVendor` | `lib/core/services/device_fingerprint_service.dart` |
| Local notifications Darwin init (no auto-prompt) | `lib/main.dart` |
| FCM permission path on iOS onboarding | `lib/features/home/screens/home_screen.dart` |
| Full AppIcon set + `remove_alpha_ios: true` | `Assets.xcassets`, `pubspec.yaml` |
| Plugin registrant lists all iOS plugins | `ios/Runner/GeneratedPluginRegistrant.m` |
| Chat OS-tray push intentionally in-app-only (both platforms) | `lib/core/services/push_notification_service.dart` |
| Moment share platform-aware store URL | `lib/features/moments/services/moment_share_service.dart` |

---

## 3. Hard blockers (must fix before a real-device debug run)

### 3.1 Missing `ios/Podfile`

**Impact:** CocoaPods cannot resolve Firebase, WebRTC, Stream, permission_handler, etc. `flutter build ios` fails.

**Why missing:** Never generated on Windows. `.gitignore` ignores `Pods/` but not `Podfile`.

**Fix (on Mac):**

```bash
cd frontend
flutter pub get          # generates ios/Podfile
```

Then edit `ios/Podfile`:

1. Set `platform :ios, '14.0'` (see §3.4).
2. Add `permission_handler` flags in `post_install` (see §3.6).
3. Run:

```bash
cd ios && pod install --repo-update && cd ..
```

Commit `Podfile` and `Podfile.lock`. Do **not** commit `Pods/`.

---

### 3.2 Missing `ios/Runner/GoogleService-Info.plist` + APNs key

**Impact:** Firebase Auth, Messaging, and Storage will not initialize correctly on device. Dart options alone are not enough for the native SDK.

Android has `android/app/google-services.json`; iOS equivalent is missing.

**Fix:**

1. Firebase Console → project `matchvibe-d55f9` → add/confirm iOS app with bundle id **`com.matchvibe.app`**.
2. Download `GoogleService-Info.plist`.
3. Open **`ios/Runner.xcworkspace`** (not `.xcodeproj`, not `macos/`).
4. Drag plist into Runner group → Copy items if needed → Runner target.
5. Confirm path: `ios/Runner/GoogleService-Info.plist`.
6. Upload an **APNs Authentication Key** (`.p8`) under Project Settings → Cloud Messaging → Apple app. Required if any FCM/APNs delivery is used.

---

### 3.3 Missing `Runner.entitlements` / Push capability

**Impact:** No `aps-environment`; push and VoIP-related capabilities cannot work.

**Fix:** In Xcode → Runner → Signing & Capabilities → **+ Capability** → **Push Notifications**. That creates `ios/Runner/Runner.entitlements`, e.g.:

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

Use `production` for Release/TestFlight (or let Xcode manage via separate Debug/Release entitlements).

Also add **Background Modes** for modes you actually use (see §4.2) — **do not** add unused `fetch` or PiP.

---

### 3.4 iOS deployment target

**Done on Windows:** `IPHONEOS_DEPLOYMENT_TARGET` and `AppFrameworkInfo.plist` `MinimumOSVersion` set to **14.0**.

**Still on Mac:** Set `platform :ios, '14.0'` in the generated `Podfile` so CocoaPods matches.
---

### 3.5 Code signing / `DEVELOPMENT_TEAM`

`project.pbxproj` has no `DEVELOPMENT_TEAM`. First device build fails with “Signing for Runner requires a development team.”

**Fix:** Xcode → Runner → Signing & Capabilities → Automatically manage signing → select Team.

Requires **Apple Developer Program** for real-device + APNs.

---

### 3.6 `permission_handler` Pod preprocessor flags

Without these, `Permission.camera.request()` / mic / photos return **denied** without a system prompt — breaking video calls (`lib/features/video/services/permission_service.dart`) and gallery flows.

Add inside `Podfile` `post_install`:

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

---

### 3.7 Google Sign-In URL scheme (`REVERSED_CLIENT_ID`)

**Symptom:** OAuth completes in browser; app never receives the return URL.

**Fix:** After adding `GoogleService-Info.plist`, copy `REVERSED_CLIENT_ID` into `Info.plist` as a third `CFBundleURLTypes` entry:

```xml
<dict>
	<key>CFBundleURLSchemes</key>
	<array>
		<string>com.googleusercontent.apps.911372372113-XXXXXXXX</string>
	</array>
</dict>
```

Also create an **iOS OAuth client** in Google Cloud with bundle id `com.matchvibe.app` (see `GOOGLE_SIGNIN_SETUP.md`).

---

### 3.8 `GOOGLE_WEB_CLIENT_ID` / `serverClientId` (separate from URL scheme)

**This is distinct from §3.7.** Dart uses the **Web** OAuth client ID so Google returns a Firebase-usable `idToken`:

- `lib/core/services/google_sign_in_service.dart` → `serverClientId: AppConstants.googleWebClientId`
- `lib/core/constants/app_constants.dart` → `GOOGLE_WEB_CLIENT_ID` from dotenv
- `lib/features/auth/providers/auth_provider.dart` warns / fails when `idToken` is null

**Fix:**

1. Ensure `.env.development` / `.env.production` contain a non-empty `GOOGLE_WEB_CLIENT_ID` (Web client from Firebase/Google Cloud).
2. Rebuild the app after changing env assets.
3. Verify Google Sign-In produces a non-null `idToken` on a real iPhone.

Without this, the URL scheme can work and auth still fails.

---

## 4. Feature parity gaps (build may succeed; features break)

### 4.1 FCM chat push vs VoIP call ringing — do not conflate

| Concern | Current behavior | What iOS needs |
|---------|------------------|----------------|
| Chat OS-tray / Stream Chat device push | **Intentionally off** — `push_notification_service.dart` fetches FCM token then `_removeDeviceToken` when `enableOutsideAppNotifications: false` | No change for in-app previews; APNs wait only if re-enabled later |
| Incoming call while backgrounded/killed | Foreground WS + `just_audio` ringtone only; `stream_video_push_notification` is in pubspec but **unused in `lib/`** | CallKit + PushKit + VoIP push + Stream VoIP cert |

Regular FCM remote notifications ≠ VoIP PushKit. Background ringing requires the VoIP path.

---

### 4.2 Background / killed call ringing (CallKit + PushKit)

**Symptom:** Calls ring only while app is open / WS connected.

**Fix (high level):**

1. `Info.plist` → `UIBackgroundModes`: **`audio`**, **`voip`**. Add `remote-notification` **only if** you re-enable tray FCM.
2. **Do not** enable Background Fetch or “Audio, AirPlay, and Picture in Picture” unless you implement them — unused modes invite App Review questions (no BGTask/PiP in this app).
3. Generate VoIP Services certificate; upload to Stream dashboard.
4. Wire `stream_video_push_notification` / `StreamVideoPushNotificationManager.setup(...)` after Firebase init in Dart.
5. Add PushKit / CallKit glue in `AppDelegate.swift` (or plugin helpers).
6. Test on a **physical device** (CallKit does not work on simulator).

See Stream Video Flutter push docs and repo `streamVideoDocs.md`.

---

### 4.3 Chat voice notes + microphone usage string

`lib/features/chat/screens/chat_screen.dart` sets `enableVoiceRecording: true` → `record_ios` is live.

**Done on Windows:** `NSMicrophoneUsageDescription` updated to cover calls **and** voice messages.

---

### 4.4 Audio session / interruptions

Ringtone (`just_audio` / `call_ringtone_service.dart`) + WebRTC + voice notes can fight over `AVAudioSession`. There is no app-level interruption handler; `audio_session` is transitive only.

**Action:** QA — incoming cellular call during a Stream call; start/stop voice note around a call; document any Stream-recommended session config if issues appear.

---

### 4.5 Info.plist completeness

| Key | Status | Action |
|-----|--------|--------|
| `NSCameraUsageDescription` | Present | Keep |
| `NSMicrophoneUsageDescription` | **Updated** (calls + voice messages) | Keep |
| `NSPhotoLibraryUsageDescription` | Present (read) | Keep |
| `NSPhotoLibraryAddUsageDescription` | **Added** | Keep |
| `LSApplicationQueriesSchemes` | **Expanded** | Keep |
| `ITSAppUsesNonExemptEncryption` | **Added** (`false`) | Keep |
| `UIBackgroundModes` | Still missing | Add `audio` + `voip` **on Mac** when CallKit is wired (§4.2) |
| Google `REVERSED_CLIENT_ID` URL type | Still missing | §3.7 on Mac after plist download |

---

### 4.6 Checkout / deep-link reliability

Custom schemes are configured and handled:

| URI | Purpose |
|-----|---------|
| `zztherapy://wallet?...` | Razorpay / wallet return |
| `zztherapy://vip?...` | VIP checkout return |
| `zztherapy://moments-plan?...` | Moments Premium return |
| `zztherapy://moment?id=` | Moment open |
| `zztherapy://signup?ref=` / `app://signup?ref=` | Referral |

**Gap:** No Universal Links / Associated Domains / `apple-app-site-association`. Custom schemes work if Safari redirects correctly; Universal Links are more reliable for production checkout/share/referral.

---

### 4.7 Moment share is platform-aware

**Done on Windows:** `moment_share_service.dart` uses App Store URL on iOS (`MomentShareInfo.appStoreUrl` or `APP_STORE_URL` env) and Play Store on Android.

**Still needed:** Set `APP_STORE_URL` in `.env.*` once the App Store listing exists; optionally return `appStoreUrl` from the backend share API.

---

### 4.8 Debug HTTP / App Transport Security

Android debug can allow cleartext. iOS ATS blocks non-HTTPS by default.

Production HTTPS is fine. For LAN debug (`http://<LAN_IP>:3000`), add temporary `NSAppTransportSecurity` exceptions (prefer not shipping exceptions in Release). Physical devices cannot use `localhost` for the host machine.

---

### 4.9 Photos limited access (iOS 14+)

**Done on Windows:** `edit_profile_screen.dart` treats `PermissionStatus.isLimited` as usable after request.

**Still on Mac:** QA limited-library picker on a real iPhone.

---

### 4.10 HEIC → WebP upload

`flutter_image_compress` is used for EXIF strip / HEIC→JPEG/WebP. **Verify on a real iPhone** for profile and moments uploads (simulator is insufficient).

---

### 4.11 Sentry dSYM upload

- Dart Sentry works on iOS (`lib/core/services/sentry_service.dart`).
- Script exists: `frontend/scripts/sentry_release_upload.sh`.
- **Missing:** Xcode Release build phase / CI step; set Release **Debug Information Format** = `DWARF with dSYM File`.

---

### 4.12 APNs token wait (only if re-enabling tray push)

If you later set `enableOutsideAppNotifications: true` and register with Stream Chat, wait for `getAPNSToken()` before registering the FCM token on iOS.

---

### 4.13 iPad device family

`TARGETED_DEVICE_FAMILY = "1,2"` (iPhone + iPad) in `project.pbxproj`.

Either:

- QA all primary flows on iPad, **or**
- Set to `"1"` (iPhone only) before App Store submission.

---

### 4.14 Screen-capture shield on iOS 17/18

`AppDelegate.swift` uses the secure-`UITextField` layer trick plus `UIScreen.capturedDidChangeNotification`. Undocumented Apple behavior — can break or false-positive on iOS 18.

**Action:** Explicit QA; keep notification + black shield fallback if the secure layer fails. Be prepared to explain to App Review.

---

## 5. App Store / compliance

### 5.1 Guideline 4.8 — Sign in with Apple

Login UI is **Google Sign-In only** (`GOOGLE_SIGNIN_SETUP.md`; phone/OTP disabled). Offering Google as the only third-party login typically requires **Sign in with Apple**.

**Plan:** Apple Sign-In entitlement + Firebase Apple provider + UI button. Do **not** treat phone reCAPTCHA URL schemes as required unless phone auth is re-enabled.

### 5.2 Guideline 3.1.1 — IAP vs external Razorpay

Coins / VIP / Moments Premium use web Razorpay + deep-link return (`wallet_checkout_launcher.dart`, `vip_screen.dart`, `moments_premium_checkout.dart`). **High rejection risk** for digital goods without StoreKit IAP.

**Product/legal decision required** before App Store submission.

### 5.3 `PrivacyInfo.xcprivacy`

**File created** at `ios/Runner/PrivacyInfo.xcprivacy` (UserDefaults / file timestamp / disk space / boot time reasons).

**Still on Mac:** Add the file to the **Runner** target in Xcode (Copy Bundle Resources) so it ships in the archive.

### 5.4 `ITSAppUsesNonExemptEncryption`

**Done on Windows:** `Info.plist` sets `ITSAppUsesNonExemptEncryption` = `false` for typical HTTPS-only use.

### 5.5 Privacy Nutrition Labels

Declare: camera, microphone, photos, device ID (IDFV), purchase history / financial info as applicable. Do **not** claim tracking/IDFA while Meta stays Android-only and ATT is unused.

### 5.6 Background modes + capture hack

Justify only **used** modes (`audio`, `voip`). Document secure-window capture blocking if reviewers ask.

### 5.7 Orientations

`Info.plist` declares portrait + landscape. Ensure every screen handles landscape, or remove landscape orientations to avoid broken-layout rejection.

### 5.8 Mic privacy string accuracy

**Done** — see §4.3.

### 5.9 iPhone vs iPad

See §4.13.

---

## 5A. iOS-specific UX polish (not blockers)

Full Mac-device checklist: [`IOS_MAC_ONLY_CHANGES.md`](IOS_MAC_ONLY_CHANGES.md) §4.

| Topic | Status | Notes |
|-------|--------|--------|
| **Dynamic Island** | Not implemented | ActivityKit + Widget Extension on Mac; best for ongoing/incoming calls after CallKit |
| **Live Activities** | Not implemented | Lock Screen + Island; pairs with CallKit |
| **Haptic feedback** | Partial | Chat uses `mediumImpact` on iOS; expand CTA haptics + QA on device |
| **Safe Area** | Partial | Many screens use `SafeArea` / padding; audit notch + Island on device |
| **Keyboard animation** | Partial | Several forms use `viewInsets`; QA chat/composer/forms on device |
| **Navigation gestures** | Gap | Prefer Cupertino patterns for pushed screens |
| **Swipe back** | Gap | `go_router` uses Material `builder:` — migrate push routes to `CupertinoPage` after Mac visual QA |

These do **not** block the first debug build.

---

## 6. Intentionally Android-only (do not “fix”)

| Feature | Evidence | Notes |
|---------|----------|-------|
| Meta App Events | `meta_app_events_service.dart` → `Platform.isAndroid` | Dart gated. **`FacebookAppEventsPlugin` still registers on iOS** in `GeneratedPluginRegistrant.m` — watch for startup warnings / SKAdNetwork questionnaire noise; optionally exclude the pod from iOS |
| Play Install Referrer | `install_referrer_service.dart` | iOS referrals rely on deep links only |
| Android notification channels | `main.dart` | N/A on iOS |
| `Permission.notification` Android path | `home_screen.dart` | iOS uses `FirebaseMessaging.requestPermission` |
| Sentry `anrEnabled` | `sentry_service.dart` | Android-only |
| `flutter_secure_storage` | In pubspec; **unused in `lib/`** | No Keychain Sharing work unless fast-login revives it |
| Emulator fingerprint skip | `device_fingerprint_service.dart` | iOS uses IDFV |

---

## 7. Plugin-by-plugin iOS matrix (`GeneratedPluginRegistrant.m`)

Legend: ✅ little/no config · 🟡 plist / Pod flags / light setup · 🔴 significant native / console work

| Plugin | Status | Requirement |
|--------|:------:|-------------|
| `app_links` | 🟡 | Custom schemes present; Universal Links need Associated Domains |
| `audio_session` | 🟡 | Transitive; test interruptions with WebRTC / ringtone |
| `battery_plus` | ✅ | None |
| `connectivity_plus` | ✅ | None |
| `device_info_plus` | ✅ | No ATT unless IDFA used |
| `facebook_app_events` | 🟡 | Dart Android-only; still linked on iOS — consider excluding |
| `file_picker` / `file_selector_ios` | ✅ | Basic pick OK |
| `firebase_core` / `firebase_auth` / `firebase_messaging` / `firebase_storage` | 🔴 | `GoogleService-Info.plist` + APNs |
| `flutter_image_compress` | 🟡 | Verify HEIC on device |
| `flutter_local_notifications` | 🟡 | Darwin init present; permission via FCM path |
| `flutter_secure_storage` | ✅ | Unused in Dart today |
| `gal` | 🟡 | `NSPhotoLibraryAddUsageDescription` |
| `get_thumbnail_video` | ✅ | None |
| `google_sign_in_ios` | 🔴 | `REVERSED_CLIENT_ID` + plist + `GOOGLE_WEB_CLIENT_ID` |
| `image_picker_ios` | 🟡 | Camera/photo strings; add write string if saving |
| `integration_test` | ✅ | Dev only |
| `just_audio` | 🟡 | `audio` background mode for BG ringtone |
| `media_kit_video` | ✅ | Registered; unused in `lib/` (dead weight) |
| `package_info_plus` | ✅ | None |
| `permission_handler_apple` | 🔴 | Pod preprocessor flags (§3.6) |
| `photo_manager` | 🟡 | Read string present; add write string |
| `record_ios` | 🟡 | Voice notes live; expand mic string |
| `sentry_flutter` | 🟡 | dSYM upload pipeline |
| `share_plus` | 🟡 | Fix Play-only share copy (§4.7) |
| `shared_preferences_foundation` | ✅ | None |
| `sqflite_darwin` | ✅ | None |
| `stream_video_flutter` / `stream_webrtc_flutter` | 🔴 | Camera/mic; large WebRTC pod; BG audio for calls |
| `stream_video_push_notification` | 🔴 | Linked but unused — CallKit/PushKit still required for BG ring |
| `thermal` | ✅ | None |
| `url_launcher_ios` | 🟡 | Expand `LSApplicationQueriesSchemes` |
| `video_player_avfoundation` | ✅ | None |
| `wakelock_plus` | ✅ | None |

Approx. **8 red**, **14 yellow** among registered plugins.

---

## 8. Step-by-step on a Mac

### 8.1 Warnings before you start

- Open **`ios/Runner.xcworkspace`**, never `macos/` (desktop Flutter host) and prefer workspace over `.xcodeproj` after pods.
- `FIREBASE_SETUP.md` may still mention old package `com.example.zztherapy` — use **`com.matchvibe.app`**.
- Env vars: use dotenv (`API_BASE_URL`, `GOOGLE_WEB_CLIENT_ID`, etc.); see `app_constants.dart` over stale constants in older docs.
- No iOS CI today (Ubuntu moments workflow only). Optional later: `flutter build ipa` on `macos-*` runners.

### 8.2 Machine setup

```bash
xcode-select --install
sudo xcodebuild -license accept
sudo gem install cocoapods   # or brew
flutter doctor -v            # Xcode + CocoaPods must be ✓
```

### 8.3 Project + pods

```bash
cd zztherapy/frontend
flutter pub get
# Edit ios/Podfile: platform :ios, '14.0' + permission_handler flags
cd ios && pod install --repo-update && cd ..
```

### 8.4 Firebase + Google

1. Add `GoogleService-Info.plist` (§3.2).
2. Upload APNs `.p8`.
3. Add `REVERSED_CLIENT_ID` to `Info.plist` (§3.7).
4. Confirm `GOOGLE_WEB_CLIENT_ID` in `.env.*` (§3.8).
5. Confirm iOS OAuth client in Google Cloud for `com.matchvibe.app`.

### 8.5 Info.plist + capabilities

1. Photo add usage string; expand query schemes; update mic string; optional `ITSAppUsesNonExemptEncryption`.
2. Xcode: Team, Push Notifications, Background Modes (`audio`, `voip` when CallKit ready).
3. Bump deployment target to 14.0+.

### 8.6 CallKit (for background ringing)

Follow Stream push guide; VoIP cert; Dart + AppDelegate wiring (§4.2).

### 8.7 First run

```bash
flutter devices
flutter run -d <iphone-id>
```

### 8.8 Release / TestFlight

```bash
flutter build ipa --release
# or Xcode Archive → Distribute
```

Also: App Store Connect app record, production APNs, privacy questionnaire, Sign in with Apple / IAP decisions, Sentry dSYM upload, `PrivacyInfo.xcprivacy`.

---

## 9. QA checklist (“works perfectly”)

- [ ] `flutter doctor` clean on Mac; pods install succeeds
- [ ] App launches; Firebase initializes without plist errors
- [ ] Google Sign-In round-trip with **non-null `idToken`** (`GOOGLE_WEB_CLIENT_ID` set)
- [ ] Camera + mic prompts appear (permission_handler flags work)
- [ ] Video call connects; ringtone plays in foreground
- [ ] Background/killed incoming call rings (after CallKit) on **device**
- [ ] Chat voice note records and sends
- [ ] Profile photo pick (full + limited library)
- [ ] HEIC photo upload succeeds
- [ ] Deep links: wallet, vip, moments-plan, moment, signup
- [ ] Checkout return reopens app and updates entitlement/balance
- [ ] Notification permission prompt on onboarding
- [ ] Share sheet shows **App Store** URL on iOS (not Play-only copy)
- [ ] WhatsApp / mailto / https launches work
- [ ] Capture shield: screenshot / screen record on iOS 17 and 18
- [ ] Cellular call interrupts Stream call gracefully
- [ ] iPad layout OK **or** device family set to iPhone-only
- [ ] Sentry receives a test event; Release build has dSYMs uploaded
- [ ] No unexpected Facebook/SKAdNetwork prompts on cold start

---

## 10. Appendices

### Appendix A — One-page action checklist

**Windows (done):** Info.plist privacy/query/encryption · deployment 14.0 · PrivacyInfo file · share App Store branch · photos limited · iOS haptics

**Mac (todo) — see also [`IOS_MAC_ONLY_CHANGES.md`](IOS_MAC_ONLY_CHANGES.md):**

- [ ] Mac + Xcode 15+ + CocoaPods + Flutter
- [ ] `flutter pub get` → edit Podfile (14.0 + permission flags) → `pod install`
- [ ] `GoogleService-Info.plist` + APNs `.p8`
- [ ] `GOOGLE_WEB_CLIENT_ID` in `.env.*` + iOS OAuth client
- [ ] `REVERSED_CLIENT_ID` URL scheme in Info.plist
- [ ] Entitlements / Push + Background Modes (`audio`, `voip` when CallKit ready)
- [ ] Add `PrivacyInfo.xcprivacy` to Runner target in Xcode
- [ ] Signing Team
- [ ] CallKit / PushKit / VoIP for background calls
- [ ] Set `APP_STORE_URL` when listing exists
- [ ] Sign in with Apple; IAP decision
- [ ] iPhone-only **or** iPad QA
- [ ] UX polish: Safe Area / keyboard / swipe-back; later Dynamic Island / Live Activities
- [ ] `flutter run` on device → full §9 QA → `flutter build ipa`

### Appendix B — Explicit non-gaps (do not invent work)

These are **not** required for current product code:

- Phone OTP / Firebase phone reCAPTCHA URL scheme (disabled)
- Biometrics / Face ID usage strings
- Location, contacts, calendar, Bluetooth, NFC
- App Tracking Transparency / IDFA (Meta Android-only)
- Widgets, App Clips, App Groups
- In-app review (`store_review`)
- Keychain Sharing (secure storage unused)
- Cloudflare image Accept headers (already iOS-aware in `image_cache_managers.dart`)

### Appendix C — Open questions

1. Active Apple Developer Program enrollment?
2. Is `com.matchvibe.app` registered as an App ID?
3. APNs Auth Key uploaded to Firebase?
4. VoIP Services certificate for Stream?
5. App Store Connect record created?
6. Sign in with Apple timeline?
7. IAP vs continue Razorpay web checkout?
8. Ship iPhone-only or support iPad?
9. Universal Links domain + `apple-app-site-association`?
10. Exclude `facebook_app_events` from iOS builds?

### Appendix D — File reference index

| What | Path |
|------|------|
| Pubspec | [`../pubspec.yaml`](../pubspec.yaml) |
| Firebase options | [`../lib/firebase_options.dart`](../lib/firebase_options.dart) |
| Entry / FCM / local notifs | [`../lib/main.dart`](../lib/main.dart) |
| Google Sign-In | [`../lib/core/services/google_sign_in_service.dart`](../lib/core/services/google_sign_in_service.dart) |
| Push (in-app policy) | [`../lib/core/services/push_notification_service.dart`](../lib/core/services/push_notification_service.dart) |
| Permissions | [`../lib/features/video/services/permission_service.dart`](../lib/features/video/services/permission_service.dart) |
| Deep links | [`../lib/app/widgets/app_lifecycle_wrapper.dart`](../lib/app/widgets/app_lifecycle_wrapper.dart) |
| Moment share | [`../lib/features/moments/services/moment_share_service.dart`](../lib/features/moments/services/moment_share_service.dart) |
| Meta (Android-only) | [`../lib/core/services/meta_app_events_service.dart`](../lib/core/services/meta_app_events_service.dart) |
| Security MethodChannel | [`../lib/features/video/services/security_service.dart`](../lib/features/video/services/security_service.dart) |
| Info.plist | [`../ios/Runner/Info.plist`](../ios/Runner/Info.plist) |
| AppDelegate | [`../ios/Runner/AppDelegate.swift`](../ios/Runner/AppDelegate.swift) |
| Plugin registrant | [`../ios/Runner/GeneratedPluginRegistrant.m`](../ios/Runner/GeneratedPluginRegistrant.m) |
| Xcode project | [`../ios/Runner.xcodeproj/project.pbxproj`](../ios/Runner.xcodeproj/project.pbxproj) |
| Android manifest (parity) | [`../android/app/src/main/AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml) |
| Sentry dSYM script | [`../scripts/sentry_release_upload.sh`](../scripts/sentry_release_upload.sh) |
| Google Sign-In setup | [`../GOOGLE_SIGNIN_SETUP.md`](../GOOGLE_SIGNIN_SETUP.md) |
| **Mac-only checklist (M5 Air)** | [`IOS_MAC_ONLY_CHANGES.md`](IOS_MAC_ONLY_CHANGES.md) |

### Appendix E — Android → iOS permission / feature map

| Android | iOS |
|---------|-----|
| `CAMERA` / `RECORD_AUDIO` | Usage strings + permission_handler flags |
| `POST_NOTIFICATIONS` | `FirebaseMessaging.requestPermission` + entitlements |
| `READ_MEDIA_IMAGES` / storage | Photo usage strings (+ Add for write) |
| `AD_ID` | N/A while Meta Android-only |
| Intent filters (hosts) | URL schemes (hosts handled in Dart) |
| `google-services.json` | `GoogleService-Info.plist` |
| `FLAG_SECURE` | AppDelegate secure layer + capture shield |
| Cleartext debug | ATS exceptions (debug only) |
| Facebook manifest meta | Not configured on iOS (Dart gated) |
| Install referrer | Deep-link referral only |

---

*End of report — audit 2026-07-20, version 1.0.0+80.*
