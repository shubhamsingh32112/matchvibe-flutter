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

  static String buildHostDisabledMessage({
    required String userId,
    required String hostName,
  }) {
    return 'Hi MatchVibe team, my host account has been disabled. Please help.\n'
        'User ID: $userId\n'
        'Host: $hostName';
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
    return _launchMessage(message);
  }

  static Future<bool> launchHostDisabledChat({
    required String userId,
    required String hostName,
  }) async {
    final message = buildHostDisabledMessage(
      userId: userId,
      hostName: hostName,
    );
    return _launchMessage(message);
  }

  static Future<bool> _launchMessage(String message) async {
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
