import 'package:flutter/material.dart';

import '../../theme/creator_home_tokens.dart';

class CreatorHomeCallRulesCard extends StatelessWidget {
  const CreatorHomeCallRulesCard({super.key});

  static const _rules = [
    (Icons.schedule_rounded, 'Online 6 Hours Daily'),
    (Icons.verified_user_outlined, '80%+ Call Acceptance Rate'),
    (Icons.flag_outlined, 'Complete Weekly Targets'),
    (Icons.description_outlined, 'Follow Platform Policies'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CreatorHomeTokens.sectionSpacing),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: CreatorHomeTokens.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: CreatorHomeTokens.pinkAccent,
                  size: 22,
                ),
                SizedBox(width: 8),
                Text(
                  'Creator Rules',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: CreatorHomeTokens.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final rule in _rules) ...[
              Row(
                children: [
                  Icon(rule.$1, size: 18, color: CreatorHomeTokens.primaryPurple),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rule.$2,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CreatorHomeTokens.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CreatorHomeTokens.statYellow.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: CreatorHomeTokens.statYellow.withValues(alpha: 0.35),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: CreatorHomeTokens.statYellow,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'If targets are not met, the Rs. 3,000 monthly salary will not be credited.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: CreatorHomeTokens.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
