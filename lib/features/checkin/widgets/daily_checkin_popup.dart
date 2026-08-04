import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_toast.dart';
import '../models/checkin_status_model.dart';
import '../providers/checkin_provider.dart';
import 'checkin_day_card.dart';

/// Daily Check-in reward popup (reference UI).
class DailyCheckInPopup extends ConsumerStatefulWidget {
  final CheckInStatus initialStatus;

  const DailyCheckInPopup({super.key, required this.initialStatus});

  @override
  ConsumerState<DailyCheckInPopup> createState() => _DailyCheckInPopupState();
}

class _DailyCheckInPopupState extends ConsumerState<DailyCheckInPopup> {
  late CheckInStatus _status;
  bool _claiming = false;
  Timer? _ticker;
  late DateTime _localAnchor;
  late DateTime _serverAnchor;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _serverAnchor = widget.initialStatus.serverNow;
    _localAnchor = DateTime.now().toUtc();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Countdown from server clock: serverNow + local elapsed → remaining until resetsAt.
  Duration get _remaining {
    final elapsed = DateTime.now().toUtc().difference(_localAnchor);
    final approxServerNow = _serverAnchor.add(elapsed);
    final left = _status.resetsAt.difference(approxServerNow);
    if (left.isNegative) return Duration.zero;
    return left;
  }

  String _formatCountdown(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _onOk() async {
    if (_claiming) return;
    if (!_status.canClaimToday) {
      Navigator.of(context, rootNavigator: true).pop();
      return;
    }

    setState(() => _claiming = true);
    try {
      final result = await ref.read(checkInProvider.notifier).claim();
      if (!mounted) return;
      setState(() {
        _status = result;
        _claiming = false;
      });
      final credited = result.coinsCredited;
      AppToast.showSuccess(
        context,
        credited > 0
            ? 'Claimed +$credited coins!'
            : 'Already claimed today',
      );
      Navigator.of(context, rootNavigator: true).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _claiming = false);
      AppToast.showError(
        context,
        'Couldn’t claim reward. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxW = math.min(size.width * 0.88, 400.0);

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Header(
                  countdown: _formatCountdown(_remaining),
                  onClose: () =>
                      Navigator.of(context, rootNavigator: true).pop(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                  child: _RewardsGrid(rewards: _status.rewards),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF8A00), Color(0xFFFF3D00)],
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: _claiming ? null : _onOk,
                          child: Center(
                            child: _claiming
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'OK',
                                    style: GoogleFonts.poppins(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                      ),
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

class _Header extends StatelessWidget {
  final String countdown;
  final VoidCallback onClose;

  const _Header({required this.countdown, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      width: double.infinity,
      child: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6B1FA2),
                  Color(0xFFC2185B),
                  Color(0xFFFF6F00),
                ],
              ),
            ),
            child: SizedBox.expand(),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              onPressed: onClose,
              icon: Icon(
                Icons.close,
                color: Colors.white.withValues(alpha: 0.9),
                size: 22,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        countdown,
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.05,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Return Tomorrow\nFor The Next Reward!',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.95),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const _HeaderIllustration(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIllustration extends StatelessWidget {
  const _HeaderIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: 4,
            bottom: 8,
            child: Image.asset(
              AppConstants.coinsIconAsset,
              width: 48,
              height: 48,
            ),
          ),
          Positioned(
            left: 8,
            top: 10,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Icon(
                Icons.event_available,
                color: Color(0xFFE53935),
                size: 28,
              ),
            ),
          ),
          const Positioned(
            top: 4,
            right: 18,
            child: Icon(Icons.auto_awesome, color: Colors.white, size: 16),
          ),
          const Positioned(
            bottom: 4,
            left: 20,
            child: Icon(Icons.star, color: Colors.white70, size: 12),
          ),
        ],
      ),
    );
  }
}

class _RewardsGrid extends StatelessWidget {
  final List<CheckInRewardDay> rewards;

  const _RewardsGrid({required this.rewards});

  @override
  Widget build(BuildContext context) {
    final days = List<CheckInRewardDay>.generate(7, (i) {
      if (i < rewards.length) return rewards[i];
      return CheckInRewardDay(day: i + 1, coins: 0, status: 'upcoming');
    });

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 108,
            child: Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: CheckInDayCard(reward: days[i])),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 108,
            child: Row(
              children: [
                for (var i = 4; i < 7; i++) ...[
                  if (i > 4) const SizedBox(width: 8),
                  Expanded(child: CheckInDayCard(reward: days[i])),
                ],
                const SizedBox(width: 8),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
