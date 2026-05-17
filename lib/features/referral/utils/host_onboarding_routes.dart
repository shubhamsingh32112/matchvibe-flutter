import '../../../shared/models/user_model.dart';

/// Returns a route path when the user must complete agency host onboarding UI.
String? hostOnboardingRedirectPath(UserModel? user) {
  if (user == null) return null;
  if (user.creatorApplicationPending) return '/host-application-pending';
  if (user.hostProfileSetupRequired) return '/host-profile-setup';
  return null;
}
