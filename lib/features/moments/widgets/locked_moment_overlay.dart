import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../account/theme/moments_premium_page_tokens.dart';
import '../utils/moments_paywall.dart';
import '../models/moments_models.dart';
import 'moment_viewer_chrome.dart';

class LockedMomentOverlay extends ConsumerWidget {
  const LockedMomentOverlay({
    super.key,
    required this.item,
    required this.onUnlocked,
    this.viewerLayout = false,
    this.bottomOverlayInset = 0,
  });

  final MomentFeedItem item;
  final ValueChanged<MomentFeedItem> onUnlocked;
  final bool viewerLayout;
  final double bottomOverlayInset;

  bool get _isVipOnly => item.accessReason == 'VIP_ONLY';

  void _openUpsell(BuildContext context) {
    if (_isVipOnly) {
      context.go('/vip');
      return;
    }
    openMomentsPremiumPage(
      context,
      source: viewerLayout ? 'viewer_locked_tap' : 'viewer_overlay',
      momentId: item.id,
    );
  }

  String get _unlockLabel =>
      _isVipOnly ? 'Unlock with VIP' : 'Unlock Moments Premium';

  String get _title => _isVipOnly ? 'VIP exclusive' : 'Premium content';

  String get _buttonLabel => _isVipOnly ? 'Get VIP' : 'Unlock Moments';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (viewerLayout) {
      return GestureDetector(
        onTap: () => _openUpsell(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              item.media.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.black26),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),
            Positioned(
              left: 16,
              bottom: bottomOverlayInset > 0 ? bottomOverlayInset + 12 : 180,
              child: MomentViewerPremiumBadge(
                unlockLabel: _unlockLabel,
                onTap: () => _openUpsell(context),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _openUpsell(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            item.media.thumbnailUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.black26),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: Colors.black.withValues(alpha: 0.35)),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, color: Colors.white, size: 40),
                const SizedBox(height: 12),
                Text(
                  _title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _openUpsell(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: _isVipOnly
                        ? const Color(0xFFD4AF37)
                        : MomentsPremiumPageTokens.accentPink,
                  ),
                  child: Text(_buttonLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
