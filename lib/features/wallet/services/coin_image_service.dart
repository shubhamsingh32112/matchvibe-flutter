import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Resolves wallet coin image URLs from Firebase Storage and caches them.
/// 
/// Features:
/// - In-memory URL caching for performance
/// - Automatic preloading of all coin images
/// - Retry logic with exponential backoff
/// - Comprehensive error logging
class CoinImageService {
  CoinImageService._();

  static final Map<int, String> _urlCache = {};
  static final Map<int, Future<String?>> _loadingFutures = {};
  static bool _isPreloading = false;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 500);

  /// Get the download URL for a coin image by ordinal (1-9).
  /// Returns cached URL if available, otherwise fetches from Firebase Storage.
  static Future<String?> getCoinImageUrl(int ordinal) async {
    if (ordinal < 1 || ordinal > 9) {
      debugPrint('⚠️ [COIN IMAGE] Invalid ordinal: $ordinal (must be 1-9)');
      return null;
    }

    // Return cached URL if available
    final cached = _urlCache[ordinal];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    // If already loading this ordinal, return the existing future
    final existingFuture = _loadingFutures[ordinal];
    if (existingFuture != null) {
      return existingFuture;
    }

    // Start loading
    final future = _loadCoinImageUrl(ordinal);
    _loadingFutures[ordinal] = future;

    try {
      final url = await future;
      return url;
    } finally {
      _loadingFutures.remove(ordinal);
    }
  }

  /// Load coin image URL from Firebase Storage with retry logic.
  static Future<String?> _loadCoinImageUrl(int ordinal, {int retryCount = 0}) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(
        'wallet/coins/$ordinal.png',
      );
      
      debugPrint('🪙 [COIN IMAGE] Fetching wallet/coins/$ordinal.png...');
      final url = await ref.getDownloadURL();
      
      if (url.isNotEmpty) {
        _urlCache[ordinal] = url;
        debugPrint('✅ [COIN IMAGE] Successfully loaded coin $ordinal');
        return url;
      } else {
        debugPrint('⚠️ [COIN IMAGE] Empty URL returned for coin $ordinal');
        return null;
      }
    } catch (error) {
      final errorMessage = error.toString();
      debugPrint(
        '⚠️ [COIN IMAGE] Failed to load wallet/coins/$ordinal.png (attempt ${retryCount + 1}/$_maxRetries): $errorMessage',
      );

      // Retry logic with exponential backoff
      if (retryCount < _maxRetries - 1) {
        final delay = Duration(
          milliseconds: _retryDelay.inMilliseconds * (retryCount + 1),
        );
        debugPrint('🔄 [COIN IMAGE] Retrying coin $ordinal after ${delay.inMilliseconds}ms...');
        await Future.delayed(delay);
        return _loadCoinImageUrl(ordinal, retryCount: retryCount + 1);
      }

      // All retries exhausted
      debugPrint('❌ [COIN IMAGE] Failed to load coin $ordinal after $_maxRetries attempts');
      return null;
    }
  }

  /// Preload all coin images (1-9) in the background.
  /// This improves performance by fetching all images upfront.
  /// Safe to call multiple times - will only preload once.
  static Future<void> preloadAllCoinImages() async {
    if (_isPreloading) {
      debugPrint('🪙 [COIN IMAGE] Preload already in progress, skipping...');
      return;
    }

    _isPreloading = true;
    debugPrint('🪙 [COIN IMAGE] Starting preload of all coin images...');

    try {
      // Load all coin images in parallel
      final futures = List.generate(9, (index) => getCoinImageUrl(index + 1));
      final results = await Future.wait(futures);

      final successCount = results.where((url) => url != null && url.isNotEmpty).length;
      debugPrint(
        '✅ [COIN IMAGE] Preload complete: $successCount/9 images loaded',
      );
    } catch (error) {
      debugPrint('❌ [COIN IMAGE] Error during preload: $error');
    } finally {
      _isPreloading = false;
    }
  }

  /// Clear the URL cache. Useful for testing or forcing refresh.
  static void clearCache() {
    _urlCache.clear();
    _loadingFutures.clear();
    debugPrint('🔄 [COIN IMAGE] Cache cleared');
  }

  /// Get the number of cached coin image URLs.
  static int getCacheSize() => _urlCache.length;

  /// Check if a specific coin image is cached.
  static bool isCached(int ordinal) {
    final url = _urlCache[ordinal];
    return url != null && url.isNotEmpty;
  }
}
