import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/providers/coin_purchase_popup_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../controllers/call_connection_controller.dart';
import '../services/call_ringtone_service.dart';
import '../utils/call_admission_constants.dart';
import '../utils/call_remote_image_resolver.dart';
import '../utils/call_remote_participant_display.dart';
import 'call_dial_card.dart';

/// Widget to display incoming call notification.
///
/// Shows Accept / Reject buttons when idle.
/// Shows "Connecting…" + progress bar when the controller is preparing / joining.
///
/// Does not navigate or join — delegates entirely to [CallConnectionController].
class IncomingCallWidget extends ConsumerStatefulWidget {
  final Call incomingCall;
  final String? fallbackImageUrl;
  final String? fallbackImageSource;

  /// Called when the call is dismissed (rejected by creator or cancelled by caller).
  final VoidCallback? onDismiss;

  const IncomingCallWidget({
    super.key,
    required this.incomingCall,
    this.fallbackImageUrl,
    this.fallbackImageSource,
    this.onDismiss,
  });

  @override
  ConsumerState<IncomingCallWidget> createState() => _IncomingCallWidgetState();
}

class _IncomingCallWidgetState extends ConsumerState<IncomingCallWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _barController;
  StreamSubscription<dynamic>? _incomingCallStateSubscription;

  static const String _fixedIncomingMessage =
      "Baby, I'm alone 😚\nEager to talk to you 💕";

  @override
  void initState() {
    super.initState();
    _barController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _subscribeCallState(widget.incomingCall);
  }

  @override
  void didUpdateWidget(covariant IncomingCallWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.incomingCall.id != widget.incomingCall.id) {
      _subscribeCallState(widget.incomingCall);
    }
  }

  @override
  void dispose() {
    _incomingCallStateSubscription?.cancel();
    _barController.dispose();
    super.dispose();
  }

  void _subscribeCallState(Call call) {
    _incomingCallStateSubscription?.cancel();
    try {
      final dynamic stateStream = (call as dynamic).partialState(
        (dynamic state) => state,
      );
      _incomingCallStateSubscription = (stateStream as Stream<dynamic>).listen((
        _,
      ) {
        if (mounted) {
          setState(() {});
        }
      });
    } catch (_) {
      // Best-effort hydration re-render only.
    }
  }

  @override
  Widget build(BuildContext context) {
    final callPhase = ref.watch(callConnectionControllerProvider).phase;
    final currentUserId = ref.watch(
      authProvider.select((s) => s.firebaseUser?.uid),
    );
    final isProcessing =
        callPhase == CallConnectionPhase.preparing ||
        callPhase == CallConnectionPhase.joining;

    final resolvedImage = resolveRemoteImage(
      call: widget.incomingCall,
      currentUserId: currentUserId,
      fallbackImageUrl: widget.fallbackImageUrl,
      fallbackSourceTag: widget.fallbackImageSource,
      enableDebugLogs: true,
      debugSourceTag: 'incoming',
    );
    final resolvedImageUrl = resolvedImage?.url;
    final resolvedImageSource =
        resolvedImage?.source ?? widget.fallbackImageSource ?? 'none';
    final remoteImageUrl =
        (resolvedImageUrl != null && resolvedImageUrl.isNotEmpty)
        ? resolvedImageUrl
        : null;

    debugPrint(
      '🖼️ [INCOMING CALL WIDGET] Image URL: ${remoteImageUrl ?? "null"} '
      '(source: $resolvedImageSource, fallback: ${widget.fallbackImageUrl ?? "null"})',
    );

    final u = remoteImageUrl;
    final String? photoUrl = u != null && u.trim().isNotEmpty ? u.trim() : null;

    final display = resolveRemoteParticipantDisplay(
      call: widget.incomingCall,
      currentUserId: currentUserId,
      fallbackName: 'Caller',
    );

    final actions = isProcessing
        ? _IncomingProcessingFooter(
            animation: _barController,
            onHangUp: () {
              ref.read(callConnectionControllerProvider.notifier).endCall();
            },
          )
        : _IncomingActionRow(
            onDecline: () async {
              CallRingtoneService.stop();
              try {
                await widget.incomingCall.reject();
                debugPrint('❌ [CALL] Call rejected by user');
              } catch (e) {
                debugPrint('❌ [CALL] Error rejecting call: $e');
              }
              widget.onDismiss?.call();
            },
            onAccept: () async {
              final authState = ref.read(authProvider);
              final user = authState.user;
              if (user != null &&
                  user.role == 'user' &&
                  user.spendableCallCoins < kMinCoinsToCall) {
                CallRingtoneService.stop();
                try {
                  await widget.incomingCall.reject();
                } catch (_) {}
                widget.onDismiss?.call();
                final currentUid = authState.firebaseUser?.uid;
                final remoteUid = resolveRemoteParticipantFirebaseUid(
                  call: widget.incomingCall,
                  currentUserId: currentUid,
                );
                final display = resolveRemoteParticipantDisplay(
                  call: widget.incomingCall,
                  currentUserId: currentUid,
                  fallbackName: 'Caller',
                );
                final photo = resolveRemoteImageUrl(
                  call: widget.incomingCall,
                  currentUserId: currentUid,
                  fallbackImageUrl: widget.fallbackImageUrl,
                );
                ref
                    .read(coinPurchasePopupProvider.notifier)
                    .state = CoinPopupIntent(
                  reason: 'preflight_low_coins_incoming',
                  dedupeKey: 'low-coins-incoming-${widget.incomingCall.id}',
                  remoteDisplayName: display.primaryName,
                  remotePhotoUrl: photo,
                  remoteFirebaseUid: remoteUid,
                );
                return;
              }
              ref
                  .read(callConnectionControllerProvider.notifier)
                  .acceptIncomingCall(widget.incomingCall);
            },
          );

    final location = display.country?.trim();
    final callerIsVip = _remoteParticipantIsVip(
      widget.incomingCall,
      currentUserId,
    );

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Material(
              color: Colors.white,
              elevation: 16,
              shadowColor: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(26),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _IncomingHeader(isProcessing: isProcessing),
                    const SizedBox(height: 14),
                    CallDialProfilePhoto(
                      size: 220,
                      imageUrl: photoUrl,
                      imageSourceTag: resolvedImageSource,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      display.nameLine,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppPalette.onSurface,
                      ),
                    ),
                    if (callerIsVip) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppBrandGradients.vipBadgeGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.workspace_premium_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'VIP Priority Caller',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (location != null && location.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                            color: AppPalette.subtitle,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppPalette.subtitle,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    _IncomingMessageBubble(text: _fixedIncomingMessage),
                    const SizedBox(height: 14),
                    actions,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _remoteParticipantIsVip(Call call, String? currentUserId) {
  try {
    final dynamic callState = (call as dynamic).state?.value;

    bool isVipFromExtra(dynamic extra) {
      if (extra is! Map) return false;
      final value = extra['isVip'];
      return value == true || value == 'true' || value == 1;
    }

    final dynamic members = callState?.members;
    if (members is Iterable) {
      for (final dynamic member in members) {
        final memberId = (member as dynamic).userId?.toString() ??
            (member as dynamic).user?.id?.toString();
        if (memberId == null) continue;
        if (currentUserId != null &&
            currentUserId.isNotEmpty &&
            memberId == currentUserId) {
          continue;
        }
        final user = (member as dynamic).user;
        if (isVipFromExtra((member as dynamic).extraData) ||
            isVipFromExtra(user?.extraData)) {
          return true;
        }
      }
    }

    final createdBy = callState?.createdBy;
    final createdById = createdBy?.id?.toString();
    if (createdById != null &&
        (currentUserId == null ||
            currentUserId.isEmpty ||
            createdById != currentUserId)) {
      if (isVipFromExtra(createdBy?.extraData)) return true;
    }
  } catch (_) {
    // Best-effort only.
  }
  return false;
}

class _IncomingHeader extends StatelessWidget {
  final bool isProcessing;

  const _IncomingHeader({required this.isProcessing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.videocam, color: AppPalette.subtitle, size: 18),
        const SizedBox(width: 10),
        Text(
          isProcessing ? 'Connecting…' : 'Incoming Video Call…',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppPalette.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _IncomingMessageBubble extends StatelessWidget {
  final String text;

  const _IncomingMessageBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE7F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.favorite, color: CallDialCardColors.pillAndProgress),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppPalette.onSurface,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomingActionRow extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _IncomingActionRow({required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    final baseTextStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
    );

    return Row(
      children: [
        Expanded(
          child: _IncomingPillButton(
            label: 'Decline',
            icon: Icons.call_end,
            backgroundColor: Colors.white,
            foregroundColor: AppPalette.primaryRed,
            borderColor: AppPalette.outlineSoft,
            textStyle: baseTextStyle,
            onPressed: onDecline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _IncomingPillButton(
            label: 'Accept',
            icon: Icons.call,
            backgroundColor: CallDialCardColors.pillAndProgress,
            foregroundColor: Colors.white,
            borderColor: Colors.transparent,
            textStyle: baseTextStyle,
            onPressed: onAccept,
          ),
        ),
      ],
    );
  }
}

class _IncomingPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final TextStyle? textStyle;
  final VoidCallback onPressed;

  const _IncomingPillButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.textStyle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: borderColor, width: 1.2),
    );

    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          shape: shape,
          textStyle: textStyle,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }
}

class _IncomingProcessingFooter extends StatelessWidget {
  final Animation<double> animation;
  final VoidCallback onHangUp;

  const _IncomingProcessingFooter({
    required this.animation,
    required this.onHangUp,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: CallDialConnectingBar(
            animation: animation,
            trackColor: CallDialCardColors.progressTrack,
            fillColor: CallDialCardColors.pillAndProgress,
          ),
        ),
        const SizedBox(height: 14),
        _IncomingPillButton(
          label: 'Hang up',
          icon: Icons.call_end,
          backgroundColor: AppPalette.primaryRed,
          foregroundColor: Colors.white,
          borderColor: Colors.transparent,
          textStyle: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          onPressed: onHangUp,
        ),
      ],
    );
  }
}
