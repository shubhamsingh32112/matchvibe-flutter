import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config_provider.dart';
import '../../../shared/widgets/app_modal_bottom_sheet.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/telegram_reward_provider.dart';
import 'telegram_plane_icon.dart';
import 'telegram_reward_sheet.dart';

const Color kTelegramBlue = Color(0xFF229ED9);
const String kTelegramRewardHeroTag = 'telegram_reward_fab';

/// Reusable floating Telegram reward control (60×60 + FREE COINS label).
///
/// Place above the bottom nav (e.g. MainLayout Stack). Hidden when the feature
/// is off, already claimed, or the user is not a plain `user`.
class TelegramRewardFAB extends ConsumerStatefulWidget {
  const TelegramRewardFAB({super.key, this.onClaimed});

  /// Called after a successful verify/claim.
  final VoidCallback? onClaimed;

  static const double buttonSize = 60;
  static const double bottomClearance = 90;
  static const double rightClearance = 20;

  @override
  ConsumerState<TelegramRewardFAB> createState() => _TelegramRewardFABState();
}

class _TelegramRewardFABState extends ConsumerState<TelegramRewardFAB>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _pulseController;
  late final AnimationController _tapController;
  late final Animation<double> _floatAnim;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _tapScale;
  Timer? _pulseTimer;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -4, end: 4).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));

    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.92,
      upperBound: 1,
      value: 1,
    );
    _tapScale = _tapController;

    _pulseTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_pulseController.isAnimating) {
        _pulseController.forward(from: 0);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final role = ref.read(authProvider).user?.role;
    final enabled = ref.read(appFeaturesProvider).telegramRewardEnabled;
    if (role != 'user' || !enabled) return;
    _loaded = true;
    try {
      await ref.read(telegramRewardProvider.notifier).loadStatus(silent: true);
    } catch (_) {
      // FAB stays hidden on error until next refresh.
    }
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _floatController.dispose();
    _pulseController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    HapticFeedback.lightImpact();
    await _tapController.reverse();
    await _tapController.forward();
    if (!mounted) return;
    await showAppModalBottomSheet<void>(
      context: context,
      builder: (ctx) => TelegramRewardSheet(
        onClaimed: widget.onClaimed,
      ),
    );
    if (mounted) {
      unawaited(
        ref.read(telegramRewardProvider.notifier).loadStatus(silent: true),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider.select((s) => s.user?.role));
    final featureOn =
        ref.watch(appFeaturesProvider.select((f) => f.telegramRewardEnabled));
    if (role != 'user' || !featureOn) {
      return const SizedBox.shrink();
    }

    final status = ref.watch(telegramRewardProvider).valueOrNull;
    if (status == null || !status.shouldShowFab) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_floatAnim, _pulseAnim, _tapScale]),
      builder: (context, child) {
        final scale = _pulseAnim.value * _tapScale.value;
        return Transform.translate(
          offset: Offset(0, _floatAnim.value),
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: _onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: kTelegramRewardHeroTag,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: TelegramRewardFAB.buttonSize,
                  height: TelegramRewardFAB.buttonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        kTelegramBlue.withValues(alpha: 0.95),
                        const Color(0xFF1A8BC4),
                        kTelegramBlue.withValues(alpha: 0.85),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kTelegramBlue.withValues(alpha: 0.45),
                        blurRadius: 16,
                        spreadRadius: 1,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: TelegramPlaneIcon(size: 28),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: kTelegramBlue,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                '🎁 FREE COINS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> launchTelegramUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    try {
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      return false;
    }
  }
}

void showTelegramVerifyHintDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Almost there',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      content: const Text(
        'After joining the channel, return here and tap Verify.',
        style: TextStyle(color: Colors.white70, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Got it', style: TextStyle(color: kTelegramBlue)),
        ),
      ],
    ),
  );
}

Future<void> showTelegramRewardSuccess({
  required BuildContext context,
  required int coins,
}) async {
  AppToast.showSuccess(
    context,
    'Congratulations!\n$coins Coins have been added.',
  );
}
