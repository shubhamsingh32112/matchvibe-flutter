import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../controllers/call_connection_controller.dart';

/// Half-screen card while a **user** is dialing / connecting; bottom half passes
/// gestures through to the underlying route (e.g. home grid).
class OutgoingCallOverlay extends ConsumerStatefulWidget {
  const OutgoingCallOverlay({super.key});

  @override
  ConsumerState<OutgoingCallOverlay> createState() =>
      _OutgoingCallOverlayState();
}

class _OutgoingCallOverlayState extends ConsumerState<OutgoingCallOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _barController;
  bool? _wakelockHeld;

  static const _purpleTop = Color(0xFF8E76E8);
  static const _purpleLight = Color(0xFFF8F6FF);
  static const _pillPurple = Color(0xFF6B4DC4);
  static const _barFill = Color(0xFF7C5CE6);

  @override
  void initState() {
    super.initState();
    _barController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _barController.dispose();
    if (_wakelockHeld == true) {
      WakelockPlus.disable();
    }
    super.dispose();
  }

  void _syncWakelock(bool want) {
    if (_wakelockHeld == want) return;
    _wakelockHeld = want;
    if (want) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callConnectionControllerProvider);
    final visible = callState.isOutgoing &&
        (callState.phase == CallConnectionPhase.preparing ||
            callState.phase == CallConnectionPhase.joining);

    _syncWakelock(visible);

    if (!visible) {
      return const SizedBox.shrink();
    }

    final name = (callState.outgoingCreatorName ?? 'Creator').trim();
    final age = callState.outgoingCreatorAge;
    final country = callState.outgoingCreatorCountry?.trim();
    final imageUrl = callState.remoteImageFallbackUrl;
    final connecting = callState.creatorAcceptedForOutgoing;

    final nameLine = age != null ? '${name.toUpperCase()}, $age' : name.toUpperCase();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await ref.read(callConnectionControllerProvider.notifier).endCall();
        }
      },
      child: Column(
        children: [
          Expanded(
            flex: 11,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_purpleTop, _purpleLight],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nameLine,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF2D2640),
                                          letterSpacing: 0.3,
                                        ),
                                  ),
                                  if (country != null &&
                                      country.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      country,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: const Color(0xFF6B6280),
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _ProfilePhoto(imageUrl: imageUrl),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _pillPurple,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Eager to talk with you...',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          connecting
                              ? 'Connecting...'
                              : 'Awaiting response...',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: const Color(0xFF4A4458),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (connecting) ...[
                          const SizedBox(height: 14),
                          _ConnectingBar(
                            animation: _barController,
                            trackColor: _purpleTop.withValues(alpha: 0.22),
                            fillColor: _barFill,
                          ),
                        ],
                        const Spacer(),
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              ref
                                  .read(callConnectionControllerProvider
                                      .notifier)
                                  .endCall();
                            },
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red,
                                    blurRadius: 16,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.call_end,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 9,
            child: IgnorePointer(
              child: ColoredBox(
                color: Colors.transparent,
                child: SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePhoto extends StatelessWidget {
  final String? imageUrl;

  const _ProfilePhoto({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    const size = 76.0;
    return SizedBox(
      width: size + 6,
      height: size + 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 0,
            top: 4,
            child: Container(
              width: size - 6,
              height: size - 6,
              decoration: BoxDecoration(
                color: const Color(0xFFC4B5F5).withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Color(0xFFE8E4F5),
                        child: Icon(Icons.person, size: 40, color: Color(0xFF8E76E8)),
                      ),
                    )
                  : const ColoredBox(
                      color: Color(0xFFE8E4F5),
                      child: Icon(Icons.person, size: 40, color: Color(0xFF8E76E8)),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectingBar extends StatelessWidget {
  final Animation<double> animation;
  final Color trackColor;
  final Color fillColor;

  const _ConnectingBar({
    required this.animation,
    required this.trackColor,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            const height = 8.0;
            final segmentW = maxW * 0.42;
            final travel = maxW + segmentW;
            final left = (animation.value * travel) - segmentW;

            return Container(
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFF8E76E8).withValues(alpha: 0.45),
                  width: 1.2,
                ),
                color: trackColor,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned(
                    left: left,
                    top: 0,
                    bottom: 0,
                    width: segmentW,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: fillColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
