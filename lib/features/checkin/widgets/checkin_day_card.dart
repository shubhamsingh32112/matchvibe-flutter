import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../models/checkin_status_model.dart';

class CheckInDayCard extends StatelessWidget {
  final CheckInRewardDay reward;

  const CheckInDayCard({super.key, required this.reward});

  @override
  Widget build(BuildContext context) {
    final isToday = reward.isToday;
    final isClaimed = reward.isClaimed;
    final isDay7 = reward.day == 7;

    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: isToday
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF9B2CF3), Color(0xFFFF4D8D)],
            )
          : null,
      color: isToday
          ? null
          : isClaimed
              ? const Color(0xFFF0F0F0)
              : Colors.white,
      border: isToday || isClaimed
          ? null
          : Border.all(color: const Color(0xFFE8E8E8)),
    );

    final dayColor = isToday
        ? Colors.white
        : isClaimed
            ? const Color(0xFF9E9E9E)
            : const Color(0xFFE91E63);

    final amountColor = isToday
        ? Colors.white
        : isClaimed
            ? const Color(0xFF9E9E9E)
            : const Color(0xFF424242);

    return Container(
      decoration: decoration,
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Day ${reward.day}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: dayColor,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Center(
                  child: Opacity(
                    opacity: isClaimed ? 0.55 : 1,
                    child: isDay7
                        ? Icon(
                            Icons.inventory_2_rounded,
                            size: isToday ? 36 : 30,
                            color: isToday
                                ? const Color(0xFFFFD54F)
                                : const Color(0xFFFFB300),
                          )
                        : Image.asset(
                            AppConstants.coinsIconAsset,
                            width: isToday ? 34 : 28,
                            height: isToday ? 34 : 28,
                            fit: BoxFit.contain,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'x ${reward.coins}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
              Text(
                isClaimed
                    ? 'Claimed'
                    : isToday
                        ? 'Today'
                        : '',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isToday ? Colors.white : const Color(0xFF9E9E9E),
                  height: 1.2,
                ),
              ),
            ],
          ),
          if (isClaimed)
            const Positioned(
              top: 0,
              right: 0,
              child: Icon(
                Icons.check_circle,
                size: 16,
                color: Color(0xFF4CAF50),
              ),
            ),
        ],
      ),
    );
  }
}
