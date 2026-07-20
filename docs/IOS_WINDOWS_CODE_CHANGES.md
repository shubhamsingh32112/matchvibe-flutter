# iOS Windows-safe code changes — before / after

**Date:** 2026-07-20  
**App:** Match Vibe (`frontend/`, version `1.0.0+80`)  
**Scope:** Changes applied without a Mac. Mac-only work is listed in [`IOS_MAC_ONLY_CHANGES.md`](IOS_MAC_ONLY_CHANGES.md).

---

## Summary of files touched

| File | Change type |
|------|-------------|
| [`ios/Runner/Info.plist`](../ios/Runner/Info.plist) | Modified |
| [`ios/Flutter/AppFrameworkInfo.plist`](../ios/Flutter/AppFrameworkInfo.plist) | Modified |
| [`ios/Runner.xcodeproj/project.pbxproj`](../ios/Runner.xcodeproj/project.pbxproj) | Modified |
| [`ios/Runner/PrivacyInfo.xcprivacy`](../ios/Runner/PrivacyInfo.xcprivacy) | **Created** |
| [`lib/core/constants/app_constants.dart`](../lib/core/constants/app_constants.dart) | Modified |
| [`lib/features/moments/models/moments_models.dart`](../lib/features/moments/models/moments_models.dart) | Modified |
| [`lib/features/moments/services/moment_share_service.dart`](../lib/features/moments/services/moment_share_service.dart) | Rewritten |
| [`lib/features/account/screens/edit_profile_screen.dart`](../lib/features/account/screens/edit_profile_screen.dart) | Modified |
| [`lib/core/services/in_app_feedback_service.dart`](../lib/core/services/in_app_feedback_service.dart) | Modified |
| [`.env.example`](../.env.example) | Modified |
| [`docs/IOS_BUILD_READINESS.md`](IOS_BUILD_READINESS.md) | Updated (docs) |
| [`docs/IOS_MAC_ONLY_CHANGES.md`](IOS_MAC_ONLY_CHANGES.md) | **Created** (docs) |

---

## 1. `ios/Runner/Info.plist`

### Why

App Store privacy accuracy, `url_launcher` query schemes, photo save permission, and export-compliance declaration.

### Before

```xml
	<key>CADisableMinimumFrameDurationOnPhone</key>
	<true/>
	<key>UIApplicationSupportsIndirectInputEvents</key>
	<true/>
	<key>CFBundleURLTypes</key>
	<!-- ... zztherapy + app schemes ... -->
	<!-- Privacy usage descriptions (required on iOS) -->
	<key>NSCameraUsageDescription</key>
	<string>We need camera access for video calls and profile photo capture.</string>
	<key>NSMicrophoneUsageDescription</key>
	<string>We need microphone access for audio during calls.</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>We need photo library access to let you choose a profile picture.</string>
	<key>LSApplicationQueriesSchemes</key>
	<array>
		<string>whatsapp</string>
	</array>
```

### After

```xml
	<key>CADisableMinimumFrameDurationOnPhone</key>
	<true/>
	<key>UIApplicationSupportsIndirectInputEvents</key>
	<true/>
	<key>ITSAppUsesNonExemptEncryption</key>
	<false/>
	<key>CFBundleURLTypes</key>
	<!-- ... zztherapy + app schemes unchanged ... -->
	<!-- Privacy usage descriptions (required on iOS) -->
	<key>NSCameraUsageDescription</key>
	<string>We need camera access for video calls and profile photo capture.</string>
	<key>NSMicrophoneUsageDescription</key>
	<string>We need microphone access for video/audio calls and chat voice messages.</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>We need photo library access to let you choose a profile picture.</string>
	<key>NSPhotoLibraryAddUsageDescription</key>
	<string>We save photos and clips to your library when you choose to save them.</string>
	<key>LSApplicationQueriesSchemes</key>
	<array>
		<string>https</string>
		<string>http</string>
		<string>mailto</string>
		<string>tel</string>
		<string>sms</string>
		<string>whatsapp</string>
	</array>
```

### Diff highlights

| Key | Before | After |
|-----|--------|-------|
| `ITSAppUsesNonExemptEncryption` | absent | `false` |
| `NSMicrophoneUsageDescription` | “…audio during calls.” | “…video/audio calls and chat voice messages.” |
| `NSPhotoLibraryAddUsageDescription` | absent | added |
| `LSApplicationQueriesSchemes` | `whatsapp` only | `https`, `http`, `mailto`, `tel`, `sms`, `whatsapp` |

---

## 2. `ios/Flutter/AppFrameworkInfo.plist`

### Why

Align Flutter framework minimum with modern pods (Firebase / Stream / WebRTC).

### Before

```xml
  <key>MinimumOSVersion</key>
  <string>13.0</string>
```

### After

```xml
  <key>MinimumOSVersion</key>
  <string>14.0</string>
```

---

## 3. `ios/Runner.xcodeproj/project.pbxproj`

### Why

Same deployment-target bump for all Runner / project build configurations (3 occurrences).

### Before

```text
IPHONEOS_DEPLOYMENT_TARGET = 13.0;
```

### After

```text
IPHONEOS_DEPLOYMENT_TARGET = 14.0;
```

**Note:** On Mac, also set `platform :ios, '14.0'` in the generated `Podfile` so CocoaPods matches.

---

## 4. `ios/Runner/PrivacyInfo.xcprivacy` (new file)

### Why

App Store Required Reason API privacy manifest for Runner. File exists on disk; **must still be added to the Runner target in Xcode on Mac**.

### Before

File did not exist.

### After (full file)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>CA92.1</string>
			</array>
		</dict>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>C617.1</string>
			</array>
		</dict>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryDiskSpace</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>E174.1</string>
			</array>
		</dict>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategorySystemBootTime</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>35F9.1</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```

| Declared API category | Reason code |
|----------------------|-------------|
| UserDefaults | `CA92.1` |
| File timestamp | `C617.1` |
| Disk space | `E174.1` |
| System boot time | `35F9.1` |

Tracking: `NSPrivacyTracking` = `false`.

---

## 5. `lib/core/constants/app_constants.dart`

### Why

Centralize App Store / Play Store URLs for share sheets; App Store URL comes from env until a listing exists.

### Before

```dart
  /// Digits-only WhatsApp number for creator applications (e.g. 919876543210).
  static String get creatorWhatsappNumber =>
      (dotenv.env['CREATOR_WHATSAPP_NUMBER'] ?? '').replaceAll(RegExp(r'\D'), '');

  static bool get enableServerOnboardingFlow =>
```

### After

```dart
  /// Digits-only WhatsApp number for creator applications (e.g. 919876543210).
  static String get creatorWhatsappNumber =>
      (dotenv.env['CREATOR_WHATSAPP_NUMBER'] ?? '').replaceAll(RegExp(r'\D'), '');

  /// App Store URL for share sheets on iOS (set after App Store Connect listing exists).
  /// Example: https://apps.apple.com/app/idXXXXXXXX
  static String get appStoreUrl => (dotenv.env['APP_STORE_URL'] ?? '').trim();

  /// Play Store URL fallback for share sheets on Android.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.matchvibe.app&pcampaignid=web_share';

  static bool get enableServerOnboardingFlow =>
```

---

## 6. `lib/features/moments/models/moments_models.dart`

### Why

Allow backend to return an iOS App Store URL in share metadata.

### Before

```dart
class MomentShareInfo {
  const MomentShareInfo({
    required this.shareUrl,
    required this.deepLink,
    required this.playStoreUrl,
    required this.title,
    required this.thumbnailUrl,
  });

  final String shareUrl;
  final String deepLink;
  final String playStoreUrl;
  final String title;
  final String thumbnailUrl;

  factory MomentShareInfo.fromJson(Map<String, dynamic> json) {
    return MomentShareInfo(
      shareUrl: json['shareUrl'] as String? ?? '',
      deepLink: json['deepLink'] as String? ?? '',
      playStoreUrl: json['playStoreUrl'] as String? ?? '',
      title: json['title'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
    );
  }
}
```

### After

```dart
class MomentShareInfo {
  const MomentShareInfo({
    required this.shareUrl,
    required this.deepLink,
    required this.playStoreUrl,
    this.appStoreUrl = '',
    required this.title,
    required this.thumbnailUrl,
  });

  final String shareUrl;
  final String deepLink;
  final String playStoreUrl;
  final String appStoreUrl;
  final String title;
  final String thumbnailUrl;

  factory MomentShareInfo.fromJson(Map<String, dynamic> json) {
    return MomentShareInfo(
      shareUrl: json['shareUrl'] as String? ?? '',
      deepLink: json['deepLink'] as String? ?? '',
      playStoreUrl: json['playStoreUrl'] as String? ?? '',
      appStoreUrl: json['appStoreUrl'] as String? ?? '',
      title: json['title'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
    );
  }
}
```

---

## 7. `lib/features/moments/services/moment_share_service.dart`

### Why

Share text was Play Store–only; iOS users should see App Store wording/URL.

### Before

```dart
import 'package:share_plus/share_plus.dart';

import '../models/moments_models.dart';
import '../services/moments_api_service.dart';

class MomentShareService {
  MomentShareService({MomentsApiService? api}) : _api = api ?? MomentsApiService();

  final MomentsApiService _api;

  static const _defaultPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.matchvibe.app&pcampaignid=web_share';

  Future<void> shareMoment(String momentId) async {
    final info = await _api.fetchShareInfo(momentId);
    final storeUrl =
        info.playStoreUrl.isNotEmpty ? info.playStoreUrl : _defaultPlayStoreUrl;
    final message = StringBuffer()
      ..writeln(info.title)
      ..writeln();
    if (info.deepLink.isNotEmpty) {
      message.writeln('Open in MatchVibe: ${info.deepLink}');
    }
    message.write('Get MatchVibe on Google Play: $storeUrl');
    await Share.share(message.toString());
  }
}
```

### After

```dart
import 'dart:io';

import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../models/moments_models.dart';
import '../services/moments_api_service.dart';

class MomentShareService {
  MomentShareService({MomentsApiService? api}) : _api = api ?? MomentsApiService();

  final MomentsApiService _api;

  Future<void> shareMoment(String momentId) async {
    final info = await _api.fetchShareInfo(momentId);
    final storeUrl = _storeUrlForPlatform(info);
    final storeLabel = Platform.isIOS ? 'the App Store' : 'Google Play';
    final message = StringBuffer()
      ..writeln(info.title)
      ..writeln();
    if (info.deepLink.isNotEmpty) {
      message.writeln('Open in MatchVibe: ${info.deepLink}');
    }
    if (storeUrl.isNotEmpty) {
      message.write('Get MatchVibe on $storeLabel: $storeUrl');
    }
    await Share.share(message.toString());
  }

  String _storeUrlForPlatform(MomentShareInfo info) {
    if (Platform.isIOS) {
      if (info.appStoreUrl.isNotEmpty) return info.appStoreUrl;
      return AppConstants.appStoreUrl;
    }
    if (info.playStoreUrl.isNotEmpty) return info.playStoreUrl;
    return AppConstants.playStoreUrl;
  }
}
```

### Behaviour

| Platform | Store URL priority | Label |
|----------|--------------------|-------|
| iOS | `info.appStoreUrl` → `APP_STORE_URL` env | “the App Store” |
| Android | `info.playStoreUrl` → `AppConstants.playStoreUrl` | “Google Play” |

If iOS URL is empty, share still includes title/deep link but omits the store line.

---

## 8. `lib/features/account/screens/edit_profile_screen.dart`

### Why

iOS Limited Photo Library (`PermissionStatus.isLimited`) was not treated as usable; requesting again when already limited, then returning `true` unconditionally after Android-style logic, was incorrect for iOS.

### Before

```dart
    } else {
      // iOS
      status = await Permission.photos.status;
      if (!status.isGranted) {
        status = await Permission.photos.request();
      }
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        _showPermissionDeniedDialog();
      }
      return false;
    }

    // image_picker on Android can often work even without explicit permission
    // granted via permission_handler (it uses the system's activity-result API).
    // So we return true and let image_picker handle its own fallback.
    return true;
  }
```

### After

```dart
    } else {
      // iOS — limited library access still allows picking selected photos.
      status = await Permission.photos.status;
      if (!status.isGranted && !status.isLimited) {
        status = await Permission.photos.request();
      }
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        _showPermissionDeniedDialog();
      }
      return false;
    }

    // iOS limited access and Android system pickers can still succeed.
    if (Platform.isIOS) {
      return status.isGranted || status.isLimited;
    }

    // image_picker on Android can often work even without explicit permission
    // granted via permission_handler (it uses the system's activity-result API).
    // So we return true and let image_picker handle its own fallback.
    return true;
  }
```

---

## 9. `lib/core/services/in_app_feedback_service.dart`

### Why

iOS chat haptics used `lightImpact`, which is easy to miss; `mediumImpact` is a better default for message notifications.

### Before

```dart
  static Future<void> _defaultHaptic() {
    // `lightImpact()` is frequently imperceptible or a no-op on many Android devices
    // (and on emulators). Prefer a stronger, more widely supported signal there.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return HapticFeedback.vibrate();
    }
    return HapticFeedback.lightImpact();
  }
```

### After

```dart
  static Future<void> _defaultHaptic() {
    // Android: lightImpact is often imperceptible; prefer vibrate.
    // iOS: mediumImpact is the usual chat/notification feel (light can be missed).
    if (defaultTargetPlatform == TargetPlatform.android) {
      return HapticFeedback.vibrate();
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return HapticFeedback.mediumImpact();
    }
    return HapticFeedback.lightImpact();
  }
```

| Platform | Before | After |
|----------|--------|-------|
| Android | `vibrate()` | `vibrate()` (unchanged) |
| iOS | `lightImpact()` | `mediumImpact()` |
| Other | `lightImpact()` | `lightImpact()` |

---

## 10. `.env.example`

### Why

Document new / critical env keys for Google Sign-In and iOS share.

### Before

```env
# Website base URL (for legal pages, etc.)
WEBSITE_BASE_URL=https://yourdomain.com

# Stream Chat/Video API key (public key, optional - has default)
```

### After

```env
# Website base URL (for legal pages, etc.)
WEBSITE_BASE_URL=https://yourdomain.com

# Web OAuth client ID (Firebase / Google Cloud) — required for Google Sign-In idToken on Android + iOS
GOOGLE_WEB_CLIENT_ID=

# App Store URL for iOS share sheets (set after App Store Connect listing exists)
# Example: https://apps.apple.com/app/idXXXXXXXX
APP_STORE_URL=

# Stream Chat/Video API key (public key, optional - has default)
```

**Action for you:** copy these into `.env.development` / `.env.production` with real values when available. Do not commit secret env files.

---

## 11. Documentation-only (no runtime code)

### Created

- [`docs/IOS_MAC_ONLY_CHANGES.md`](IOS_MAC_ONLY_CHANGES.md) — MacBook Air M5 checklist (pods, Firebase, signing, CallKit, UX polish: Dynamic Island, Live Activities, Safe Area, keyboard, swipe-back, etc.)

### Updated

- [`docs/IOS_BUILD_READINESS.md`](IOS_BUILD_READINESS.md) — Windows-done vs Mac-todo, §5A UX polish, appendix checklist, links to Mac-only doc

These docs are not reproduced here in full; open the files for content.

---

## What was intentionally **not** changed (Mac-only)

| Item | Reason |
|------|--------|
| `ios/Podfile` / `pod install` | Requires Mac + CocoaPods |
| `GoogleService-Info.plist` | Download + Xcode target membership |
| `REVERSED_CLIENT_ID` URL scheme | Value comes from GoogleService-Info |
| `Runner.entitlements` / Push / Background Modes | Xcode capabilities |
| CallKit / PushKit / AppDelegate VoIP | Native + device QA |
| `UIBackgroundModes` | Add only when CallKit is wired |
| Dynamic Island / Live Activities | ActivityKit Widget Extension on Mac |
| Cupertino swipe-back for `go_router` | Device visual QA first |
| `flutter build ios` / TestFlight | macOS only |

---

## Quick verification checklist

- [ ] Info.plist opens and validates in Xcode (no XML errors)
- [ ] Set `APP_STORE_URL` when App Store listing exists
- [ ] Set `GOOGLE_WEB_CLIENT_ID` in real `.env.*` files
- [ ] On Mac: add `PrivacyInfo.xcprivacy` to Runner target
- [ ] On Mac: Podfile `platform :ios, '14.0'` + permission_handler flags
- [ ] On device: limited photos pick, share sheet copy, chat haptic feel

---

*End of before/after change log — 2026-07-20.*
