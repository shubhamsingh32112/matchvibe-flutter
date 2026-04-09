import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static const String appName = 'Match Vibe';

  /// Brand logo (PNG). Also used as source for launcher icons via `flutter_launcher_icons`.
  static const String appLogoAsset = 'lib/assets/app_logo.png';

  /// Full-screen splash / login background.
  static const String loaderBackgroundAsset = 'lib/assets/loader_bg.png';

  /// Login screen looping background video (muted in code). Add file under lib/assets/.
  static const String loginBackgroundVideoAsset = 'lib/assets/loginpage_video.mp4';

  static const String privacyPolicyUrl =
      'https://matchvibes.vercel.app/privacy-policy';
  static const String termsOfUseUrl =
      'https://matchvibes.vercel.app/terms-of-use';

  // Get from environment variables
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000/api/v1';
  static String get socketUrl => dotenv.env['SOCKET_URL'] ?? 'http://localhost:3000';
  static String get websiteBaseUrl => dotenv.env['WEBSITE_BASE_URL'] ?? 'http://localhost:8080';
  static String get streamApiKey => dotenv.env['STREAM_API_KEY'] ?? 'd536t7g4q75v';

  /// Web OAuth client ID (Firebase console → Project settings → Your apps → Web client).
  /// Required for reliable Google Sign-In → Firebase [idToken] on Android/iOS.
  static String get googleWebClientId =>
      (dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '').trim();
  
  // Health check URL (derived from socket URL)
  static String get healthCheckUrl => '$socketUrl/health';
  
  // SharedPreferences keys
  static const String keyAuthToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyUserEmail = 'user_email';
  static const String keyUserPhone = 'user_phone';
  static const String keyUserCoins = 'user_coins';

  /// Per-user key suffix: `ack_profile_revision_$userId` — last seen [UserModel.profileRevision].
  static const String keyAckProfileRevisionPrefix = 'ack_profile_revision_';

  /// Staged referral code before Firebase sign-in (survives process death when persisted).
  static const String keyPendingReferralCode = 'pending_referral_code';
}

