import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';

class CreatorWhatsappLauncher {
  const CreatorWhatsappLauncher._();

  static String buildApplyMessage({
    required String userWhatsapp,
    required String userId,
  }) {
    return 'Hi MatchVibe team, I want to become a creator.\n'
        'My WhatsApp: $userWhatsapp\n'
        'User ID: $userId';
  }

  static Uri? buildWaMeUri(String message) {
    final number = AppConstants.creatorWhatsappNumber;
    if (number.isEmpty) return null;
    return Uri.parse(
      'https://wa.me/$number?text=${Uri.encodeComponent(message)}',
    );
  }

  static Future<bool> launchApplyChat({
    required String userWhatsapp,
    required String userId,
  }) async {
    final message = buildApplyMessage(
      userWhatsapp: userWhatsapp,
      userId: userId,
    );
    final uri = buildWaMeUri(message);
    if (uri == null) return false;

    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Validates a WhatsApp / phone number string (8–15 digits after stripping).
bool looksLikeWhatsappNumber(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 8 && digits.length <= 15;
}
