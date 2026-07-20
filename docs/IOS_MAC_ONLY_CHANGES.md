# iOS changes that require a Mac (MacBook Air M5)

**Audience:** You have a **MacBook Air M5** and will finish Match Vibe iOS there.  
**Companion docs:** [`IOS_BUILD_READINESS.md`](IOS_BUILD_READINESS.md) (full audit) · this file (Mac-only checklist).

**Already done on Windows (do not redo unless you change them):**

- `Info.plist` — mic string (calls + voice messages), `NSPhotoLibraryAddUsageDescription`, expanded `LSApplicationQueriesSchemes`, `ITSAppUsesNonExemptEncryption`
- Deployment target bumped to **14.0** in `AppFrameworkInfo.plist` + `project.pbxproj`
- `ios/Runner/PrivacyInfo.xcprivacy` created (still must be **added to the Runner target in Xcode**)
- Dart: moment share App Store branch, photos `isLimited`, stronger iOS haptics

Set `APP_STORE_URL` in `.env.development` / `.env.production` once the App Store listing exists (e.g. `https://apps.apple.com/app/idXXXXXXXX`).

---

## 1. Why Mac is required

Apple’s toolchain (Xcode, `xcodebuild`, codesign, simulators, CocoaPods linking for iOS) runs **only on macOS**. Your M5 Air is the correct machine for everything below.

Open **`frontend/ios/Runner.xcworkspace`** after pods — never `macos/` and prefer workspace over `.xcodeproj`.

---

## 2. Hard blockers (Mac / Apple / Firebase console)

Do these in order before expecting a working debug build on a real iPhone.

| # | Task | Notes |
|---|------|--------|
| 1 | Install Xcode 15+, CLT, CocoaPods, Flutter matching `^3.10.7` | `flutter doctor -v` must show ✓ Xcode + CocoaPods |
| 2 | `cd frontend && flutter pub get` | Generates missing `ios/Podfile` |
| 3 | Edit Podfile: `platform :ios, '14.0'` + `permission_handler` `GCC_PREPROCESSOR_DEFINITIONS` | Camera/mic/photos/notifications — see readiness §3.6 |
| 4 | `cd ios && pod install --repo-update` | First run downloads large WebRTC pods |
| 5 | Download `GoogleService-Info.plist` for `com.matchvibe.app` | Firebase project `matchvibe-d55f9` |
| 6 | Drag plist into Runner target in Xcode | Path: `ios/Runner/GoogleService-Info.plist` |
| 7 | Upload APNs Auth Key (`.p8`) to Firebase Cloud Messaging | Required for APNs delivery |
| 8 | Add `REVERSED_CLIENT_ID` URL scheme to `Info.plist` | Copy from GoogleService-Info.plist |
| 9 | Confirm `GOOGLE_WEB_CLIENT_ID` in `.env.*` | Separate from URL scheme — needed for Firebase `idToken` |
| 10 | Create iOS OAuth client in Google Cloud | Bundle id `com.matchvibe.app` |
| 11 | Xcode → Signing & Capabilities → Team | Automatic signing |
| 12 | Add Push Notifications capability | Creates `Runner.entitlements` (`aps-environment`) |
| 13 | Add PrivacyInfo.xcprivacy to Runner target | File exists; Xcode must reference it |
| 14 | `flutter run -d <iphone>` | Prefer physical device for camera/mic/push |

**Do not** enable Background Modes `fetch` or PiP unless you implement them.

---

## 3. Feature work that needs Mac + device

| Task | Why Mac |
|------|---------|
| Background Modes `audio` + `voip` (when CallKit ready) | Xcode capabilities + Info.plist; test on device |
| CallKit + PushKit + `stream_video_push_notification` wiring | Native + Dart; VoIP cert on Stream; **device only** |
| Wait for APNs token if re-enabling tray FCM | Device behavior |
| HEIC → WebP upload QA | Real iPhone camera roll |
| Screen-capture shield QA (iOS 17/18) | Device; undocumented secure-layer trick |
| Audio interruption (cellular call during Stream call) | Device |
| Sentry dSYM: Release `DWARF with dSYM` + upload script | Archive on Mac |
| Associated Domains / Universal Links | Xcode + hosted `apple-app-site-association` |
| Sign in with Apple | Entitlement + Firebase + UI; App Store 4.8 |
| iPad: QA layouts **or** set `TARGETED_DEVICE_FAMILY = 1` | Xcode / device |
| Portrait-only vs landscape | Confirm UI on device, then trim Info.plist if needed |
| Optional: exclude `facebook_app_events` from iOS pods | Podfile / build |
| `flutter build ipa` → TestFlight | Mac only |

---

## 4. iOS-specific UX polish (not blockers)

These were missing from the original readiness discussion. They affect polish, not compile.

### 4.1 Dynamic Island

- **What:** Persistent / glanceable UI in the Dynamic Island (iPhone 14 Pro+).
- **For Match Vibe:** Natural fit for **ongoing / incoming calls** (caller name, mute, end).
- **Requires:** ActivityKit, Widget Extension target in Xcode, Mac build, physical Pro device for full QA.
- **Status:** Not implemented. Do after CallKit baseline works.

### 4.2 Live Activities

- **What:** Lock Screen + Dynamic Island live updates (call timer, “incoming call”).
- **Pairs with:** CallKit / PushKit for background ringing.
- **Requires:** Same Widget Extension + ActivityKit; push updates from backend optional.
- **Status:** Not implemented. Plan as a follow-up to §3 CallKit.

### 4.3 Haptic feedback

- **Done on Windows:** Chat haptics use `HapticFeedback.mediumImpact()` on iOS (`in_app_feedback_service.dart`).
- **Still on Mac / polish:** Add selection/impact haptics on key CTA taps (join call, send, copy referral); verify intensity with System Haptics enabled on device. Avoid spam (existing cooldown/dedupe stays).

### 4.4 Safe Area

- **Current:** Many screens use `SafeArea` / `MediaQuery.padding` (`AppScaffold`, home, moments, calls, nav bar).
- **Mac QA:** Walk primary flows on notch + Dynamic Island devices; watch for:
  - Full-bleed videos/moments covering the status bar incorrectly
  - Bottom nav colliding with Home Indicator
  - Incoming-call overlay under Dynamic Island
- Fix in Flutter once you see failures on device — no Xcode required for layout tweaks after you can run the app.

### 4.5 Keyboard animation

- **Current:** Several sheets/forms use `MediaQuery.viewInsetsOf` (comments, upload review, schedule call).
- **Mac QA:** Chat composer, support forms, login, withdrawal — ensure fields scroll above keyboard with smooth inset animation (`resizeToAvoidBottomInset`, animated padding).
- Prefer `AnimatedPadding` / scroll-into-view over jumping layouts.

### 4.6 Navigation gestures

- Prefer iOS-native patterns: edge swipe back, large titles where appropriate, modal sheets that dismiss with drag.
- `go_router` currently uses Material `builder:` routes (no Cupertino back-swipe by default).

### 4.7 Swipe-back behaviour

- **Gap:** Push routes registered with `builder:` get Material transitions → **no interactive pop gesture** like UIKit.
- **Fix on Mac after visual QA:** Migrate secondary push routes to `pageBuilder` + `CupertinoPage` (or equivalent) so edge-swipe works. Keep tab roots / splash as non-swipe if needed.
- Verify: Account → Edit profile → swipe back; Wallet → Transactions → swipe back; Chat thread → swipe back.

---

## 5. Suggested order of work on the M5 Air

```text
Day 0 — Toolchain
  Xcode + CocoaPods + Flutter doctor

Day 1 — First green build
  Podfile + pod install
  GoogleService-Info + REVERSED_CLIENT_ID + GOOGLE_WEB_CLIENT_ID
  Signing + PrivacyInfo in target
  flutter run on iPhone
  Smoke: Google Sign-In (idToken), camera/mic, deep links

Day 2 — Calls & polish
  CallKit / PushKit / VoIP
  Background Modes audio+voip
  Safe Area / keyboard / swipe-back pass
  Haptics on key CTAs

Day 3+ — Store readiness
  Sign in with Apple decision
  IAP vs Razorpay decision
  Live Activities / Dynamic Island (optional v1.1)
  Archive + TestFlight + Sentry dSYM
```

---

## 6. Quick command cheat sheet (run on Mac only)

```bash
cd ~/path/to/zztherapy/frontend
flutter pub get
# edit ios/Podfile (platform 14.0 + permission_handler flags)
cd ios && pod install --repo-update && cd ..
open ios/Runner.xcworkspace
flutter devices
flutter run -d <iphone-id>
flutter build ipa --release
./scripts/sentry_release_upload.sh   # after archive / if configured
```

---

## 7. Explicitly not Mac-only (already handled or Windows-safe)

- Most Dart feature code and env-driven config
- Info.plist privacy / query / encryption keys (already updated)
- Android Meta / Play Install Referrer (stay Android-only)
- Phone OTP (disabled — skip reCAPTCHA iOS setup unless re-enabled)

---

*MacBook Air M5 checklist — Match Vibe `1.0.0+80`.*
