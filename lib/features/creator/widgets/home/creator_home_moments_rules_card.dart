import 'package:flutter/material.dart';

import '../../theme/creator_home_tokens.dart';

class CreatorHomeMomentsRulesCard extends StatelessWidget {
  const CreatorHomeMomentsRulesCard({super.key});

  static const _rules = [
    (Icons.image_outlined, 'Upload 2 own photos daily'),
    (Icons.videocam_outlined, 'Upload 1 own video daily'),
    (Icons.verified_user_outlined, 'Only your own content is allowed'),
    (Icons.block, 'No Google, influencer or stolen content'),
    (Icons.sentiment_satisfied_alt_outlined, 'Face optional'),
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
                  Icons.movie_filter_outlined,
                  color: CreatorHomeTokens.pinkAccent,
                  size: 22,
                ),
                SizedBox(width: 8),
                Text(
                  'Moments Rules',
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
          ],
        ),
      ),
    );
  }
}
