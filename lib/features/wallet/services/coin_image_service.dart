import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Resolves wallet coin image URLs from Firebase Storage and caches them.
class CoinImageService {
  CoinImageService._();

  static final Map<int, String> _urlCache = {};

  static Future<String?> getCoinImageUrl(int ordinal) async {
    if (ordinal < 1 || ordinal > 9) return null;

    final cached = _urlCache[ordinal];
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final ref = FirebaseStorage.instance.ref().child(
        'wallet/coins/$ordinal.png',
      );
      final url = await ref.getDownloadURL();
      _urlCache[ordinal] = url;
      return url;
    } catch (error) {
      debugPrint(
        '⚠️ [COIN IMAGE] Failed to resolve wallet/coins/$ordinal.png: $error',
      );
      return null;
    }
  }
}
