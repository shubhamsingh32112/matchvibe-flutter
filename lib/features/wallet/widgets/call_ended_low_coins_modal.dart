import 'package:flutter/material.dart';
import '../../../core/images/image_cache_managers.dart';
import '../../../shared/widgets/app_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/providers/coin_purchase_popup_provider.dart';
import '../../home/providers/availability_provider.dart';
import '../models/wallet_pricing_model.dart';
import '../providers/wallet_pricing_provider.dart';
import '../services/wallet_checkout_launcher.dart';
import 'call_ended_asset_paths.dart';

/// Presents the call-ended / low-coins purchase modal.
Future<void> presentCallEndedLowCoinsModal(
  BuildContext context,
  WidgetRef ref, {
  required CoinPopupIntent intent,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.54),
    builder: (_) => CallEndedLowCoinsModal(intent: intent),
  );
}

class CallEndedLowCoinsModal extends ConsumerStatefulWidget {
  final CoinPopupIntent intent;

  const CallEndedLowCoinsModal({super.key, required this.intent});

  @override
  ConsumerState<CallEndedLowCoinsModal> createState() =>
      _CallEndedLowCoinsModalState();
}

class _CallEndedLowCoinsModalState extends ConsumerState<CallEndedLowCoinsModal> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pricing = ref.read(walletPricingProvider);
      if (pricing.hasError || !pricing.hasValue) {
        ref.invalidate(walletPricingProvider);
      }
    });
  }

  static const _kPurpleDeep = Color(0xFF1A0D2E);
  static const _kPurpleMid = Color(0xFF2D1B4E);
  static const _kBorderPink = Color(0xFFE879F9);
  static const _kOnlineGreen = Color(0xFF7CFF7C);
  static const _kBannerBg = Color(0xFF2D1F45);

  String _tierArt(int index) {
    switch (index) {
      case 0:
        return CallEndedAssets.diamondsPouch;
      case 1:
        return CallEndedAssets.yellowDiamonds;
      default:
        return CallEndedAssets.diamondsChest;
    }
  }

  Future<void> _onBuy(int coins) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await WalletCheckoutLauncher.startCheckoutForCoins(context, coins);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final intent = widget.intent;
    final availability = intent.remoteFirebaseUid != null
        ? ref.watch(creatorAvailabilityProvider)[intent.remoteFirebaseUid!]
        : null;
    final isOnline = availability == CreatorAvailability.online;
    final pricingAsync = ref.watch(walletPricingProvider);

    final nameHint = intent.remoteDisplayName?.trim();
    final onlineLine = (intent.remoteFirebaseUid != null && isOnline)
        ? "She's still online.."
        : null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_kPurpleMid, _kPurpleDeep],
            ),
            border: Border.all(
              color: _kBorderPink.withValues(alpha: 0.65),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _kBorderPink.withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 36,
                  right: -8,
                  width: 140,
                  height: 160,
                  child: IgnorePointer(
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (rect) => const LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [Colors.white, Colors.transparent],
                        stops: [0.45, 1],
                      ).createShader(rect),
                      child: _HeaderModelPhoto(
                        remoteUrl: intent.remotePhotoUrl,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      Row(
                        children: [
                          const Expanded(child: SizedBox()),
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () =>
                              Navigator.of(context, rootNavigator: true).pop(),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Colors.black.withValues(alpha: 0.35),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(6),
                            minimumSize: const Size(32, 32),
                          ),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ),
                      if (intent.showCallEndedCopy) ...[
                        Text(
                          'Call Ended 😢',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFFFFFFFF),
                            Color(0xFFFFB0D0),
                          ],
                        ).createShader(bounds),
                        child: Text(
                          'Continue Your Call Now',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                      ),
                      if (onlineLine != null) ...[
                        const SizedBox(height: 8),
                        Text.rich(
                          TextSpan(
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            children: [
                              const TextSpan(text: "She's still "),
                              TextSpan(
                                text: 'online.. 🟢',
                                style: TextStyle(
                                  color: _kOnlineGreen,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (nameHint != null && nameHint.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          nameHint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'Don\'t miss this moment',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 148,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              child: Image.asset(
                                CallEndedAssets.yellowDiamonds,
                                height: 120,
                                fit: BoxFit.contain,
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              left: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _kBannerBg.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.bolt_rounded,
                                      color: Colors.amber.shade400,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'You ran out of coins. Get coins instantly and keep talking!',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      pricingAsync.when(
                        data: (data) {
                          final packs = data.packages.take(3).toList();
                          if (packs.isEmpty) {
                            return Text(
                              'No packages available.',
                              style: GoogleFonts.inter(color: Colors.white70),
                            );
                          }
                          final primaryPack = packs.first;
                          return Column(
                            children: [
                              for (var i = 0; i < packs.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _PackRow(
                                    pack: packs[i],
                                    tierArt: _tierArt(i),
                                    isBestValue: i == 0,
                                    busy: _busy,
                                    onTap: () => _onBuy(packs[i].coins),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              _ContinueCta(
                                busy: _busy,
                                onPressed: () => _onBuy(primaryPack.coins),
                              ),
                            ],
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        error: (e, _) => Column(
                          children: [
                            Text(
                              'Couldn\'t load prices.',
                              style: GoogleFonts.inter(color: Colors.white70),
                            ),
                            TextButton(
                              onPressed: () =>
                                  ref.invalidate(walletPricingProvider),
                              child: const Text(
                                'Retry',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _TrustFooter(textStyle: GoogleFonts.inter(fontSize: 10)),
                    ],
                  ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderModelPhoto extends StatelessWidget {
  final String? remoteUrl;

  const _HeaderModelPhoto({this.remoteUrl});

  @override
  Widget build(BuildContext context) {
    final url = remoteUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return AppNetworkImage(
        imageUrl: url,
        width: 140,
        height: 160,
        fit: BoxFit.cover,
        cacheManager: avatarCacheManager,
        errorFallback: Image.asset(CallEndedAssets.girl, fit: BoxFit.cover),
        placeholder: Image.asset(CallEndedAssets.girl, fit: BoxFit.cover),
        variantTag: 'avatarMd',
      );
    }
    return Image.asset(CallEndedAssets.girl, fit: BoxFit.cover);
  }
}

class _PackRow extends StatelessWidget {
  final WalletCoinPack pack;
  final String tierArt;
  final bool isBestValue;
  final bool busy;
  final VoidCallback onTap;

  const _PackRow({
    required this.pack,
    required this.tierArt,
    required this.isBestValue,
    required this.busy,
    required this.onTap,
  });

  static const _kPinkAccent = Color(0xFFFF4081);

  @override
  Widget build(BuildContext context) {
    final hasDiscount =
        pack.oldPriceInr != null && pack.oldPriceInr! > pack.priceInr;
    final badgeLabel = pack.badge?.trim().isNotEmpty == true
        ? pack.badge!.trim()
        : '+${pack.coins} Bonus';

    final decoration = isBestValue
        ? BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF9E8), Color(0xFFFFE8CC)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.85),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.25),
                blurRadius: 12,
              ),
            ],
          )
        : BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: decoration,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (isBestValue)
                Positioned(
                  left: -4,
                  top: -6,
                  child: Transform.rotate(
                    angle: -0.12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF5FA8), Color(0xFFFF4081)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events,
                              size: 14, color: Colors.amber.shade200),
                          const SizedBox(width: 4),
                          Text(
                            'BEST VALUE',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Image.asset(tierArt, width: 52, height: 52, fit: BoxFit.contain),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${pack.coins} coins',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isBestValue
                                  ? _kPinkAccent
                                  : const Color(0xFFFFF176),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              badgeLabel,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isBestValue
                                    ? Colors.white
                                    : const Color(0xFF3D2C00),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isBestValue && hasDiscount)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Image.asset(
                          CallEndedAssets.off90,
                          height: 44,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.local_fire_department,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${pack.priceInr}',
                          style: GoogleFonts.inter(
                            fontSize: isBestValue ? 22 : 18,
                            fontWeight: FontWeight.w800,
                            color: isBestValue ? _kPinkAccent : const Color(0xFF7B39FD),
                          ),
                        ),
                        if (hasDiscount)
                          Text(
                            '₹${pack.oldPriceInr}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              decoration: TextDecoration.lineThrough,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    if (!isBestValue) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: Colors.grey.shade500),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueCta extends StatelessWidget {
  final bool busy;
  final VoidCallback onPressed;

  const _ContinueCta({required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onPressed,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFF3B3B),
                Color(0xFF9C27B0),
                Color(0xFF5C6BC0),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7B39FD).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
                ),
                child: const Icon(Icons.phone, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Continue Call Now',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chat_bubble_outline,
                color: Colors.white.withValues(alpha: 0.95),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustFooter extends StatelessWidget {
  final TextStyle textStyle;

  const _TrustFooter({required this.textStyle});

  @override
  Widget build(BuildContext context) {
    Widget cell({
      required IconData icon,
      required String title,
      required String subtitle,
      required Color iconColor,
    }) {
      return Expanded(
        child: Column(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textStyle.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: textStyle.copyWith(
                color: Colors.white.withValues(alpha: 0.65),
                height: 1.15,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        cell(
          icon: Icons.bolt_rounded,
          title: 'Instant Delivery',
          subtitle: 'Get coins instantly',
          iconColor: Colors.amber.shade400,
        ),
        cell(
          icon: Icons.verified_user_outlined,
          title: 'Secure Payment',
          subtitle: '100% safe & trusted',
          iconColor: const Color(0xFFB388FF),
        ),
        cell(
          icon: Icons.schedule_rounded,
          title: 'Limited Offer',
          subtitle: 'Hurry! Offer ends soon',
          iconColor: const Color(0xFFCE93D8),
        ),
      ],
    );
  }
}
