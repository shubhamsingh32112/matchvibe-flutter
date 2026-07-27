import '../../../shared/models/user_model.dart';

/// Returns a route path when the host cannot use the main app yet.
String? hostOnboardingRedirectPath(UserModel? user) {
  if (user == null) return null;
  if (user.isHostDisabled &&
      (user.role == 'creator' || user.role == 'admin')) {
    return '/host-disabled';
  }
  if (user.creatorApplicationPending) return '/host-application-pending';
  return null;
}
