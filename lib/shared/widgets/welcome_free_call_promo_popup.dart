import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Welcome free-call promo shown after onboarding welcome (and login promo when ineligible for wallet intro).
class WelcomeFreeCallPromoPopup extends StatelessWidget {
  const WelcomeFreeCallPromoPopup({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxW =
        math.min(size.width * 0.94, 520.0).clamp(0.0, size.width - 24);
    final bannerH = (maxW * 0.58).clamp(210.0, 310.0);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const SizedBox.expand(),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: SizedBox(
                width: maxW,
                height: bannerH,
                child: const _WelcomeFreeCallPromoBanner(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeFreeCallPromoBanner extends StatelessWidget {
  const _WelcomeFreeCallPromoBanner();

  static const _violet = Color(0xFF8A2BE2);

  TextStyle _headlineStyle(double size) => GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        height: 1.0,
        letterSpacing: -0.5,
      );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(child: _PromoBackground()),
          const Positioned(
            top: 18,
            right: 28,
            child: _FloatingCoin(size: 34, blur: 0),
          ),
          const Positioned(
            bottom: 22,
            left: 42,
            child: _FloatingCoin(size: 28, blur: 2),
          ),
          const Positioned(
            top: 8,
            right: 120,
            child: _FloatingChip(size: 44, angle: -0.35, blur: 3),
          ),
          const Positioned(
            bottom: 6,
            right: 8,
            child: _FloatingChip(size: 52, angle: 0.25, blur: 1),
          ),
          const Positioned(
            top: 52,
            left: 6,
            child: _FloatingChip(size: 36, angle: 0.5, blur: 4),
          ),
          const Positioned(
            top: 14,
            left: 180,
            child: _Sparkle(size: 14, color: Colors.white),
          ),
          const Positioned(
            top: 72,
            right: 96,
            child: _Sparkle(size: 10, color: _violet),
          ),
          const Positioned(
            bottom: 48,
            left: 120,
            child: _Sparkle(size: 12, color: Colors.white70),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 52,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _FirstCallBadge(),
                      const SizedBox(height: 10),
                      ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFFFFFF),
                            Color(0xFFE8FFE8),
                            Color(0xFF7CFF40),
                          ],
                          stops: [0.0, 0.42, 1.0],
                        ).createShader(bounds),
                        child: Text(
                          'FIRST CALL IS\nON US!',
                          style: _headlineStyle(25).copyWith(
                            color: Colors.white,
                            height: 0.98,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'TALK. CONNECT. HAVE FUN.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                          color: Colors.white.withValues(alpha: 0.94),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 48,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      _NeonGreenCallCard(),
                      SizedBox(height: 8),
                      _PurpleInfoBar(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoBackground extends StatelessWidget {
  const _PromoBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PromoBackgroundPainter(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0A0214),
              const Color(0xFF1A0033),
              const Color(0xFF12001F).withValues(alpha: 0.95),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final streakPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.55, 0),
        Offset(size.width, size.height * 0.7),
        [
          const Color(0xFF6A0DAD).withValues(alpha: 0.0),
          const Color(0xFF9B30FF).withValues(alpha: 0.45),
          const Color(0xFF4B0082).withValues(alpha: 0.15),
        ],
        [0.0, 0.55, 1.0],
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

    final path = Path()
      ..moveTo(size.width * 0.35, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.15, size.height)
      ..close();
    canvas.drawPath(path, streakPaint);

    final streak2 = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.7, size.height),
        Offset(size.width * 0.2, 0),
        [
          const Color(0xFF7B39FD).withValues(alpha: 0.0),
          const Color(0xFF8A2BE2).withValues(alpha: 0.35),
        ],
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.4, 0, size.width * 0.6, size.height),
      streak2,
    );

    final streak3 = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, size.height * 0.35),
        Offset(size.width * 0.45, size.height * 0.85),
        [
          const Color(0xFF5A189A).withValues(alpha: 0.0),
          const Color(0xFF9333EA).withValues(alpha: 0.22),
        ],
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * 0.2)
        ..lineTo(size.width * 0.35, 0)
        ..lineTo(size.width * 0.5, size.height * 0.15)
        ..lineTo(0, size.height * 0.55)
        ..close(),
      streak3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FirstCallBadge extends StatelessWidget {
  const _FirstCallBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF2A0F45),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Color(0xFF1E0A30),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_in_talk_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '1ST CALL',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Transform.rotate(
            angle: -0.08,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                'ON US!',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: Colors.black,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _NeonGreenCallCard extends StatelessWidget {
  const _NeonGreenCallCard();

  @override
  Widget build(BuildContext context) {
    const neon = Color(0xFF7CFF40);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: neon.withValues(alpha: 0.6),
            blurRadius: 20,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: neon.withValues(alpha: 0.28),
            blurRadius: 36,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D3B12), Color(0xFF062010)],
          ),
          border: Border.all(color: neon, width: 2.4),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned(
              top: -4,
              right: -2,
              child: _Sparkle(size: 12, color: Colors.white),
            ),
            const Positioned(
              bottom: -2,
              right: 8,
              child: _Sparkle(size: 10, color: Colors.white70),
            ),
            Row(
              children: [
                Transform.rotate(
                  angle: -0.35,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.25),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.phone_in_talk_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EVERY CALL IS',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                      ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF7CFF40), Color(0xFFB8FF6A)],
                        ).createShader(bounds),
                        child: Text(
                          'FREE FREE!',
                          style: GoogleFonts.inter(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PurpleInfoBar extends StatelessWidget {
  const _PurpleInfoBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF5C1A8A), Color(0xFF3D0F66)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8A2BE2).withValues(alpha: 0.25),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  'CALL ANYONE',
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 18,
            color: Colors.white.withValues(alpha: 0.35),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _RupeeCycleIcon(size: 16),
                const SizedBox(width: 4),
                Text(
                  'NO COST',
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RupeeCycleIcon extends StatelessWidget {
  final double size;

  const _RupeeCycleIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RupeeCyclePainter(),
      ),
    );
  }
}

class _RupeeCyclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final ring = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, r - 1, ring);

    final arrow = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r - 2.5),
      -0.8,
      4.6,
      false,
      arrow,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: '₹',
        style: TextStyle(
          color: Colors.white,
          fontSize: size.width * 0.55,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      center - Offset(tp.width / 2, tp.height / 2 - 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Sparkle extends StatelessWidget {
  final double size;
  final Color color;

  const _Sparkle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SparklePainter(color: color),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final Color color;

  _SparklePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final c = Offset(size.width / 2, size.height / 2);
    final w = size.width / 2;
    final h = size.height / 6;
    canvas.drawOval(Rect.fromCenter(center: c, width: w * 2, height: h * 2), paint);
    canvas.drawOval(Rect.fromCenter(center: c, width: h * 2, height: w * 2), paint);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _FloatingChip extends StatelessWidget {
  final double size;
  final double angle;
  final double blur;

  const _FloatingChip({
    required this.size,
    required this.angle,
    required this.blur,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: ImageFiltered(
        imageFilter: blur > 0
            ? ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur)
            : ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0),
        child: CustomPaint(
          size: Size(size, size),
          painter: const _PokerChipPainter(),
        ),
      ),
    );
  }
}

class _PokerChipPainter extends CustomPainter {
  const _PokerChipPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final outer = Paint()..color = const Color(0xFF6A0DAD);
    canvas.drawCircle(center, r, outer);

    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.9);
    for (var i = 0; i < 8; i++) {
      final a = (i / 8) * math.pi * 2;
      final p1 = center + Offset(math.cos(a) * r * 0.72, math.sin(a) * r * 0.72);
      final p2 = center + Offset(math.cos(a) * r, math.sin(a) * r);
      canvas.drawLine(p1, p2, stripe..strokeWidth = 2.5);
    }

    final inner = Paint()..color = const Color(0xFF4B0082);
    canvas.drawCircle(center, r * 0.55, inner);

    final gloss = Paint()
      ..shader = ui.Gradient.radial(
        center - Offset(r * 0.2, r * 0.2),
        r * 0.5,
        [Colors.white.withValues(alpha: 0.35), Colors.transparent],
      );
    canvas.drawCircle(center, r * 0.9, gloss);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FloatingCoin extends StatelessWidget {
  final double size;
  final double blur;

  const _FloatingCoin({required this.size, required this.blur});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: blur > 0
          ? ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur)
          : ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0),
      child: CustomPaint(
        size: Size(size, size),
        painter: const _GoldCoinPainter(),
      ),
    );
  }
}

class _GoldCoinPainter extends CustomPainter {
  const _GoldCoinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final fill = Paint()
      ..shader = ui.Gradient.radial(
        center - Offset(r * 0.25, r * 0.25),
        r * 1.2,
        [const Color(0xFFFFE566), const Color(0xFFD4A017)],
      );
    canvas.drawCircle(center, r, fill);

    final rim = Paint()
      ..color = const Color(0xFFB8860B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, r - 0.8, rim);

    final tp = TextPainter(
      text: TextSpan(
        text: '₹',
        style: TextStyle(
          color: const Color(0xFF5C3A00),
          fontSize: size.width * 0.52,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
