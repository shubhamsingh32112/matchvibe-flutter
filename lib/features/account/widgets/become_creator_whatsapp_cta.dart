import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../shared/styles/app_brand_styles.dart';

class BecomeCreatorWhatsappCta extends StatelessWidget {
  final VoidCallback? onApply;
  final bool isSubmitting;

  const BecomeCreatorWhatsappCta({
    super.key,
    required this.onApply,
    this.isSubmitting = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppBrandGradients.accountMenuCardShadow,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFF25D366),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chat,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ready to start your journey? Share your details on '
                        'WhatsApp and our team will guide you.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF4A4A4A),
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isSubmitting ? null : onApply,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppBrandGradients.accountMenuIconTint,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE0E0E0),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Apply on WhatsApp',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
            const Positioned(
              right: 8,
              top: -8,
              child: _DecorativeArrow(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecorativeArrow extends StatelessWidget {
  const _DecorativeArrow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 48,
      child: CustomPaint(
        painter: _DashedArrowPainter(
          color: AppBrandGradients.accountMenuIconTint.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _DashedArrowPainter extends CustomPainter {
  final Color color;

  _DashedArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.1, size.height * 0.85)
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height * 0.2,
        size.width * 0.9,
        size.height * 0.15,
      );

    _drawDashedPath(canvas, path, paint);

    final arrowPaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.9, size.height * 0.15),
      Offset(size.width * 0.72, size.height * 0.08),
      arrowPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.9, size.height * 0.15),
      Offset(size.width * 0.82, size.height * 0.28),
      arrowPaint,
    );
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}
