import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoinPopupIntent {
  final String reason;
  final String dedupeKey;

  /// Remote creator / caller display name (optional subtitle).
  final String? remoteDisplayName;

  /// Profile image URL for the remote party (optional).
  final String? remotePhotoUrl;

  /// When set, [CreatorAvailability] is read to show the green online line.
  final String? remoteFirebaseUid;

  /// When false, header copy is neutral (e.g. message-send flows if reused).
  final bool showCallEndedCopy;

  const CoinPopupIntent({
    required this.reason,
    required this.dedupeKey,
    this.remoteDisplayName,
    this.remotePhotoUrl,
    this.remoteFirebaseUid,
    this.showCallEndedCopy = true,
  });
}

/// Provider to request coin purchase popups via modal coordinator.
final coinPurchasePopupProvider = StateProvider<CoinPopupIntent?>(
  (ref) => null,
);
