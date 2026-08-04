import 'package:flutter/material.dart';

/// White Telegram paper-plane glyph for circular FABs / badges.
class TelegramPlaneIcon extends StatelessWidget {
  final double size;
  final Color color;

  const TelegramPlaneIcon({
    super.key,
    this.size = 28,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _TelegramPlanePainter(color),
    );
  }
}

class _TelegramPlanePainter extends CustomPainter {
  final Color color;

  _TelegramPlanePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path = Path();
    // Simplified Telegram plane (viewBox-ish 0..24).
    final w = size.width;
    final h = size.height;
    path.moveTo(w * 0.12, h * 0.48);
    path.lineTo(w * 0.88, h * 0.18);
    path.lineTo(w * 0.42, h * 0.88);
    path.lineTo(w * 0.38, h * 0.58);
    path.close();

    // Inner cut for wing fold look
    final fold = Path()
      ..moveTo(w * 0.38, h * 0.58)
      ..lineTo(w * 0.72, h * 0.32)
      ..lineTo(w * 0.42, h * 0.55)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(
      fold,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _TelegramPlanePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
