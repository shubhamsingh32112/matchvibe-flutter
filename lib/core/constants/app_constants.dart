import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static const String appName = 'Match Vibe';
  
  // Get from environment variables
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000/api/v1';
  static String get socketUrl => dotenv.env['SOCKET_URL'] ?? 'http://localhost:3000';
  static String get websiteBaseUrl => dotenv.env['WEBSITE_BASE_URL'] ?? 'http://localhost:8080';
  static String get streamApiKey => dotenv.env['STREAM_API_KEY'] ?? 'd536t7g4q75v';

  /// Google OAuth Web client ID (used as serverClientId for `google_sign_in`).
  /// Can be overridden via env for different Firebase projects.
  static String get googleWebClientId =>
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] ??
      '911372372113-jpbm0el15fmlltaajrhe7boqk0n4vfs2.apps.googleusercontent.com';
  
  // Health check URL (derived from socket URL)
  static String get healthCheckUrl => '$socketUrl/health';
  
  // SharedPreferences keys
  static const String keyAuthToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyUserEmail = 'user_email';
  static const String keyUserPhone = 'user_phone';
  static const String keyUserCoins = 'user_coins';
}

