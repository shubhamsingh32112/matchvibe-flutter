import '../../../shared/models/user_model.dart';

/// Returns a route path when the user is waiting on agency host approval.
String? hostOnboardingRedirectPath(UserModel? user) {
  if (user == null) return null;
  if (user.creatorApplicationPending) return '/host-application-pending';
  return null;
}
