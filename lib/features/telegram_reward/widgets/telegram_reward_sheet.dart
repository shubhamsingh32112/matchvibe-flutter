import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_toast.dart';
import '../models/telegram_reward_status.dart';
import '../providers/telegram_reward_provider.dart';
import 'telegram_plane_icon.dart';
import 'telegram_reward_fab.dart';

class TelegramRewardSheet extends ConsumerStatefulWidget {
  const TelegramRewardSheet({super.key, this.onClaimed});

  final VoidCallback? onClaimed;

  @override
  ConsumerState<TelegramRewardSheet> createState() =>
      _TelegramRewardSheetState();
}

class _TelegramRewardSheetState extends ConsumerState<TelegramRewardSheet>
    with WidgetsBindingObserver {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(telegramRewardProvider.notifier).loadStatus(silent: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(telegramRewardProvider.notifier).loadStatus(silent: true);
    }
  }

  /// Opens the public channel / group join URL (not the bot).
  Future<void> _joinChannel(TelegramRewardStatus status) async {
    final url = status.channelUrl.trim();
    if (url.isEmpty) {
      AppToast.showError(context, 'Channel URL is not configured.');
      return;
    }
    final ok = await launchTelegramUrl(url);
    if (!mounted) return;
    if (!ok) {
      AppToast.showError(context, 'Could not open the Telegram channel.');
      return;
    }
    if (!status.linked) {
      AppToast.showSuccess(
        context,
        'Join the channel, then connect your account and Verify.',
      );
    } else {
      showTelegramVerifyHintDialog(context);
    }
  }

  /// Binds app user ↔ Telegram via bot deep link (required for membership check).
  Future<void> _linkTelegram() async {
    setState(() => _busy = true);
    try {
      final token =
          await ref.read(telegramRewardProvider.notifier).createLinkToken();
      final ok = await launchTelegramUrl(token.deepLink);
      if (!mounted) return;
      if (!ok) {
        AppToast.showError(
          context,
          'Could not open Telegram. Install the app and try again.',
        );
      } else {
        AppToast.showSuccess(
          context,
          'Tap Start in the bot, then return here and Verify.',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await ref.read(telegramRewardProvider.notifier).loadStatus(silent: true);
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context,
          e is TelegramRewardException ? e.message : 'Failed to link Telegram',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    try {
      final result = await ref.read(telegramRewardProvider.notifier).verify();
      if (!mounted) return;
      if (result.alreadyClaimed) {
        AppToast.showSuccess(context, 'Reward already claimed.');
        Navigator.of(context).pop();
        return;
      }
      await showTelegramRewardSuccess(
        context: context,
        coins: result.coinsCredited > 0 ? result.coinsCredited : result.coins,
      );
      widget.onClaimed?.call();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        final msg = e is TelegramRewardException
            ? e.message
            : 'Verification failed. Please try again.';
        AppToast.showError(context, msg);
        // Keep sheet open for NOT_LINKED / NOT_JOINED so user can continue steps.
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(telegramRewardProvider);
    final status = async.valueOrNull;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1E2430).withValues(alpha: 0.98),
                const Color(0xFF12151C),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: async.isLoading && status == null
              ? const SizedBox(
                  height: 180,
                  child: Center(
                    child: CircularProgressIndicator(color: kTelegramBlue),
                  ),
                )
              : status == null
                  ? const SizedBox(
                      height: 120,
                      child: Center(
                        child: Text(
                          'Unable to load reward status',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    )
                  : _SheetBody(
                      status: status,
                      busy: _busy,
                      onJoin: () => _joinChannel(status),
                      onLink: _linkTelegram,
                      onVerify: _verify,
                    ),
        ),
      ),
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.status,
    required this.busy,
    required this.onJoin,
    required this.onLink,
    required this.onVerify,
  });

  final TelegramRewardStatus status;
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback onLink;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final claimed = status.claimed;
    final linked = status.linked;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),
        Hero(
          tag: kTelegramRewardHeroTag,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kTelegramBlue,
                boxShadow: [
                  BoxShadow(
                    color: kTelegramBlue.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: claimed
                  ? const Icon(Icons.check, color: Colors.white, size: 36)
                  : const Center(child: TelegramPlaneIcon(size: 34)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          claimed ? 'Telegram Joined' : 'Join our Telegram Community',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          claimed
              ? 'Reward Claimed'
              : 'Join our official Telegram channel and earn ${status.rewardCoins} FREE Coins instantly.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        if (!claimed) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: kTelegramBlue.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kTelegramBlue.withValues(alpha: 0.45)),
            ),
            child: Text(
              '+${status.rewardCoins} Coins',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (claimed)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white12,
                disabledBackgroundColor: Colors.white12,
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('✓ Claimed'),
            ),
          )
        else ...[
          // Always open the public channel first — never the bot.
          _PrimaryButton(
            label: 'Join Channel',
            busy: busy,
            onPressed: onJoin,
          ),
          const SizedBox(height: 10),
          if (!linked)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: busy ? null : onLink,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      )
                    : const Text(
                        'Connect account',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: busy ? null : onVerify,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      )
                    : const Text(
                        'Verify & Claim',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          if (!linked) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: busy ? null : onVerify,
                child: Text(
                  'I joined — Verify',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            Text(
              '1) Join channel  ·  2) Connect account (bot Start)  ·  3) Verify',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: kTelegramBlue,
          disabledBackgroundColor: kTelegramBlue.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }
}
