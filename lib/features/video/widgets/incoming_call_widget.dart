import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/coin_purchase_popup.dart';
import '../../../shared/widgets/app_modal_bottom_sheet.dart';
import '../../auth/providers/auth_provider.dart';
import '../controllers/call_connection_controller.dart';
import '../utils/call_remote_image_resolver.dart';

/// Widget to display incoming call notification.
///
/// Shows Accept / Reject buttons when idle.
/// Shows "Connecting…" spinner when the controller is preparing / joining.
///
/// ❌ Does NOT navigate or join — delegates entirely to [CallConnectionController].
class IncomingCallWidget extends ConsumerWidget {
  final Call incomingCall;
  final String? fallbackImageUrl;

  /// Called when the call is dismissed (rejected by creator or cancelled by caller).
  /// The parent [IncomingCallListener] uses this to mark the call ID as handled
  /// and prevent the overlay from re-appearing.
  final VoidCallback? onDismiss;

  const IncomingCallWidget({
    super.key,
    required this.incomingCall,
    this.fallbackImageUrl,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final callPhase = ref.watch(callConnectionControllerProvider).phase;
    final currentUserId = ref.watch(authProvider).firebaseUser?.uid;
    final isProcessing = callPhase == CallConnectionPhase.preparing ||
        callPhase == CallConnectionPhase.joining;

    String? remoteImageUrl = (fallbackImageUrl != null &&
            fallbackImageUrl!.isNotEmpty)
        ? fallbackImageUrl
        : resolveRemoteImageUrl(
            call: incomingCall,
            currentUserId: currentUserId,
            fallbackImageUrl: fallbackImageUrl,
            enableDebugLogs: true,
            debugSourceTag: 'incoming',
          );

    debugPrint(
        '🖼️ [INCOMING CALL WIDGET] Image URL: ${remoteImageUrl ?? "null"} (fallback: ${fallbackImageUrl ?? "null"})');

    final u = remoteImageUrl;
    final String? photoUrl =
        u != null && u.trim().isNotEmpty ? u.trim() : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (photoUrl != null)
          Image.network(
            photoUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('❌ [INCOMING CALL WIDGET] Image load error: $error');
              return ColoredBox(color: scheme.surface);
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return ColoredBox(
                color: scheme.surface,
                child: Center(
                  child: CircularProgressIndicator(
                    color: scheme.primary,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
          )
        else
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppBrandGradients.appBackground,
            ),
            child: Center(
              child: Icon(
                Icons.person,
                size: 120,
                color: AppPalette.emptyIcon,
              ),
            ),
          ),
        if (photoUrl != null)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.18),
                  Colors.black.withValues(alpha: 0.48),
                ],
              ),
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: photoUrl != null
                      ? Colors.white.withValues(alpha: 0.22)
                      : AppPalette.surface,
                  child: ClipOval(
                    child: photoUrl != null
                        ? Image.network(
                            photoUrl,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            Icons.person,
                            size: 60,
                            color: AppPalette.subtitle,
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isProcessing ? 'Connecting…' : 'Incoming Call',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: photoUrl != null
                            ? Colors.white
                            : AppPalette.onSurface,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Video Call',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: photoUrl != null
                            ? Colors.white.withValues(alpha: 0.85)
                            : AppPalette.subtitle,
                      ),
                ),
                const Spacer(),
                if (isProcessing)
                  CircularProgressIndicator(
                    color: photoUrl != null ? Colors.white : scheme.primary,
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _CallActionButton(
                        icon: Icons.call_end,
                        label: 'Reject',
                        color: AppPalette.primaryRed,
                        labelColor: photoUrl != null
                            ? Colors.white
                            : AppPalette.onSurface,
                        onPressed: () async {
                          try {
                            await incomingCall.reject();
                            debugPrint('❌ [CALL] Call rejected by creator');
                          } catch (e) {
                            debugPrint('❌ [CALL] Error rejecting call: $e');
                          }
                          onDismiss?.call();
                        },
                      ),
                      _CallActionButton(
                        icon: Icons.call,
                        label: 'Accept',
                        color: AppPalette.success,
                        labelColor: photoUrl != null
                            ? Colors.white
                            : AppPalette.onSurface,
                        onPressed: () {
                          final authState = ref.read(authProvider);
                          final user = authState.user;
                          if (user != null &&
                              user.role == 'user' &&
                              user.coins < 10) {
                            showAppModalBottomSheet(
                              context: context,
                              builder: (context) =>
                                  const CoinPurchaseBottomSheet(),
                            );
                            return;
                          }
                          ref
                              .read(callConnectionControllerProvider.notifier)
                              .acceptIncomingCall(incomingCall);
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color labelColor;
  final VoidCallback onPressed;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.labelColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
