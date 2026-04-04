import 'package:google_sign_in/google_sign_in.dart';
import '../constants/app_constants.dart';

/// Single [GoogleSignIn] instance with Firebase-recommended [serverClientId]
/// (Web OAuth client ID from Firebase / Google Cloud) so [idToken] is reliably
/// returned for [GoogleAuthProvider.credential].
class AppGoogleSignIn {
  AppGoogleSignIn._();

  static GoogleSignIn? _instance;

  static GoogleSignIn get instance {
    final id = AppConstants.googleWebClientId;
    _instance ??= GoogleSignIn(
      scopes: const <String>['email', 'profile'],
      serverClientId: id.isNotEmpty ? id : null,
    );
    return _instance!;
  }

  /// Clears the Google session locally (call before Firebase [signOut]).
  /// Does not revoke OAuth consent — avoids forcing full consent on every app open.
  static Future<void> signOut() async {
    try {
      await _instance?.signOut();
    } catch (_) {}
  }
}
