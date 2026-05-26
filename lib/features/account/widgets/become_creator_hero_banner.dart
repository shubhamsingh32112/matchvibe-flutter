import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../shared/styles/app_brand_styles.dart';

class BecomeCreatorHeroBanner extends StatelessWidget {
  const BecomeCreatorHeroBanner({super.key});

  static const _heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFF0F6),
      Color(0xFFF3E5F5),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: _heroGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppBrandGradients.accountMenuCardShadow,
        ),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1A),
                      height: 1.25,
                    ),
                children: const [
                  TextSpan(text: 'Become a '),
                  TextSpan(
                    text: 'MatchVibe',
                    style: TextStyle(
                      color: AppBrandGradients.accountMenuIconTint,
                    ),
                  ),
                  TextSpan(text: ' Creator'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Turn your charm into earnings.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF4A4A4A),
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppBrandGradients.accountMenuIconTint,
                  height: 1.2,
                ),
                children: const [
                  TextSpan(text: 'Earn up to '),
                  TextSpan(
                    text: '₹50,000+',
                    style: TextStyle(fontSize: 26),
                  ),
                  TextSpan(text: ' per month!'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _FeatureRow(),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow();

  static const _features = [
    _FeatureItem(Icons.schedule, 'Flexible\nHours', Color(0xFFEDE7F6)),
    _FeatureItem(
      Icons.account_balance_wallet_outlined,
      'Weekly\nPayouts',
      Color(0xFFFCE4EC),
    ),
    _FeatureItem(Icons.videocam_outlined, 'Video\nCalls', Color(0xFFEDE7F6)),
    _FeatureItem(
      Icons.headset_mic_outlined,
      'Agency\nSupport',
      Color(0xFFFCE4EC),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _features.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _FeatureChip(item: _features[i])),
        ],
      ],
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String label;
  final Color iconBackground;

  const _FeatureItem(this.icon, this.label, this.iconBackground);
}

class _FeatureChip extends StatelessWidget {
  final _FeatureItem item;

  const _FeatureChip({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: item.iconBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.icon,
              size: 18,
              color: AppBrandGradients.accountMenuIconTint,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A4A4A),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
