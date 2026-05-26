import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../shared/styles/app_brand_styles.dart';

class BecomeCreatorHowItWorks extends StatelessWidget {
  const BecomeCreatorHowItWorks({super.key});

  static const _steps = [
    _StepData(
      number: 1,
      label: 'Submit\nApplication',
      icon: Icons.edit_document,
      tint: Color(0xFFEDE7F6),
    ),
    _StepData(
      number: 2,
      label: 'Verification\n& Approval',
      icon: Icons.verified_user_outlined,
      tint: Color(0xFFFCE4EC),
    ),
    _StepData(
      number: 3,
      label: 'Training &\nGuidelines',
      icon: Icons.school_outlined,
      tint: Color(0xFFEDE7F6),
    ),
    _StepData(
      number: 4,
      label: 'Go Live &\nStart Earning',
      icon: Icons.play_circle_outline,
      tint: Color(0xFFFCE4EC),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How it works',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A),
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _steps.length; i++) ...[
                  if (i > 0) const _StepArrow(),
                  _StepTile(data: _steps[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepData {
  final int number;
  final String label;
  final IconData icon;
  final Color tint;

  const _StepData({
    required this.number,
    required this.label,
    required this.icon,
    required this.tint,
  });
}

class _StepTile extends StatelessWidget {
  final _StepData data;

  const _StepTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppBrandGradients.accountMenuHeaderGradient,
            ),
            alignment: Alignment.center,
            child: Text(
              '${data.number}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: data.tint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              data.icon,
              color: AppBrandGradients.accountMenuIconTint,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A4A4A),
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepArrow extends StatelessWidget {
  const _StepArrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 52, left: 4, right: 4),
      child: Icon(
        Icons.chevron_right,
        size: 18,
        color: Color(0xFFBDBDBD),
      ),
    );
  }
}
