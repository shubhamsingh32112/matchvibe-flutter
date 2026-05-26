import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Design tokens
const _neonPurple = Color(0xFF8A2BE2);
const _neonGreen = Color(0xFF7CFF40);
const _goldBadge = Color(0xFFFFD700);

/// Welcome free-call promo shown after onboarding welcome (and login promo when ineligible for wallet intro).
class WelcomeFreeCallPromoPopup extends StatelessWidget {
  const WelcomeFreeCallPromoPopup({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxW =
        math.min(size.width * 0.94, 520.0).clamp(0.0, size.width - 24);
    final maxH = size.height * 0.82;

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
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxW,
                  maxHeight: maxH,
                ),
                child: SingleChildScrollView(
                  child: _WelcomeFreeCallPromoBanner(maxWidth: maxW),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double _promoScale(double maxW) => (maxW / 360).clamp(0.85, 1.15);

BoxDecoration _neonBorderDecoration({
  required Color glowColor,
  required double radius,
  Color? fillColor,
  Gradient? fillGradient,
  double borderWidth = 2,
}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    color: fillGradient == null ? fillColor : null,
    gradient: fillGradient,
    border: Border.all(color: glowColor, width: borderWidth),
    boxShadow: [
      BoxShadow(
        color: glowColor.withValues(alpha: 0.55),
        blurRadius: 14,
        spreadRadius: 0.5,
      ),
      BoxShadow(
        color: glowColor.withValues(alpha: 0.32),
        blurRadius: 28,
        spreadRadius: 1.5,
      ),
    ],
  );
}

TextStyle _promoDisplayStyle({
  required double fontSize,
  Color color = Colors.white,
  FontStyle fontStyle = FontStyle.italic,
  List<Shadow>? shadows,
}) {
  return GoogleFonts.archivoBlack(
    fontSize: fontSize,
    fontWeight: FontWeight.w400,
    fontStyle: fontStyle,
    height: 0.95,
    letterSpacing: -0.5,
    color: color,
    shadows: shadows,
  );
}

class _WelcomeFreeCallPromoBanner extends StatelessWidget {
  const _WelcomeFreeCallPromoBanner({required this.maxWidth});

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final s = _promoScale(maxWidth);
    final padH = 16.0 * s;
    final padV = 18.0 * s;
    final gapSm = 10.0 * s;
    final gapMd = 14.0 * s;
    final gapLg = 16.0 * s;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(child: _PromoBackground()),
          // Portrait-oriented floating decorations
          Positioned(
            top: -6 * s,
            left: -10 * s,
            child: _FloatingChip(size: 48 * s, angle: 0.45, blur: 3),
          ),
          Positioned(
            top: 4 * s,
            right: -6 * s,
            child: _FloatingChip(size: 40 * s, angle: -0.35, blur: 2),
          ),
          Positioned(
            bottom: 28 * s,
            left: -14 * s,
            child: _FloatingChip(size: 44 * s, angle: -0.2, blur: 4),
          ),
          Positioned(
            top: 52 * s,
            right: 12 * s,
            child: _FloatingCoin(size: 36 * s, blur: 0),
          ),
          Positioned(
            top: 140 * s,
            left: 8 * s,
            child: _FloatingCoin(size: 30 * s, blur: 3),
          ),
          Positioned(
            bottom: 64 * s,
            right: 10 * s,
            child: _FloatingCoin(size: 32 * s, blur: 2),
          ),
          Positioned(
            top: 28 * s,
            left: maxWidth * 0.42,
            child: _Sparkle(size: 14 * s, color: Colors.white),
          ),
          Positioned(
            top: 118 * s,
            right: 48 * s,
            child: _Sparkle(size: 11 * s, color: _neonPurple),
          ),
          Positioned(
            top: 200 * s,
            left: 24 * s,
            child: _Sparkle(size: 10 * s, color: Colors.white70),
          ),
          Positioned(
            bottom: 120 * s,
            right: 36 * s,
            child: _Sparkle(size: 12 * s, color: Colors.white),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(padH, padV, padH, padV),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _FirstCallBadge(scale: s),
                SizedBox(height: gapMd),
                _HeadlineBlock(scale: s),
                SizedBox(height: gapSm),
                _TaglineWithRule(scale: s, maxWidth: maxWidth),
                SizedBox(height: gapLg),
                _NeonGreenCallCard(scale: s),
                SizedBox(height: gapMd),
                _PurpleInfoBar(scale: s),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadlineBlock extends StatelessWidget {
  const _HeadlineBlock({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final headlineSize = 34.0 * scale;
    final gradientSize = 32.0 * scale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'FIRST CALL',
          textAlign: TextAlign.center,
          style: _promoDisplayStyle(
            fontSize: headlineSize,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
              Shadow(
                color: _neonPurple.withValues(alpha: 0.45),
                blurRadius: 16,
              ),
            ],
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF7CFF40),
              Color(0xFFB8FF6A),
              Color(0xFFFFE566),
              Color(0xFFFFD700),
            ],
            stops: [0.0, 0.35, 0.72, 1.0],
          ).createShader(bounds),
          child: Text(
            'IS ON US!',
            textAlign: TextAlign.center,
            style: _promoDisplayStyle(
              fontSize: gradientSize,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _TaglineWithRule extends StatelessWidget {
  const _TaglineWithRule({required this.scale, required this.maxWidth});

  final double scale;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'TALK. CONNECT. HAVE FUN.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12.5 * scale,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            letterSpacing: 1.2,
            color: Colors.white.withValues(alpha: 0.94),
          ),
        ),
        SizedBox(height: 10 * scale),
        Center(
          child: Container(
            width: maxWidth * 0.78,
            height: 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1),
              gradient: LinearGradient(
                colors: [
                  _neonPurple.withValues(alpha: 0.0),
                  _neonPurple.withValues(alpha: 0.9),
                  _neonPurple.withValues(alpha: 0.0),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _neonPurple.withValues(alpha: 0.65),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PromoBackground extends StatelessWidget {
  const _PromoBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PromoBackgroundPainter(),
      child: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0214),
              Color(0xFF1A0033),
              Color(0xFF12001F),
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
    // Strong diagonal streak from top-right through center (portrait focal)
    final streakPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.85, 0),
        Offset(size.width * 0.25, size.height * 0.75),
        [
          const Color(0xFF9B30FF).withValues(alpha: 0.55),
          const Color(0xFF6A0DAD).withValues(alpha: 0.25),
          const Color(0xFF4B0082).withValues(alpha: 0.0),
        ],
        [0.0, 0.5, 1.0],
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);

    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.2, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height * 0.85)
        ..lineTo(size.width * 0.05, size.height * 0.55)
        ..close(),
      streakPaint,
    );

    final streak2 = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width, size.height * 0.3),
        Offset(0, size.height * 0.9),
        [
          const Color(0xFF7B39FD).withValues(alpha: 0.0),
          const Color(0xFF8A2BE2).withValues(alpha: 0.4),
        ],
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.35, 0, size.width * 0.65, size.height),
      streak2,
    );

    final streak3 = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, size.height * 0.15),
        Offset(size.width * 0.5, size.height * 0.55),
        [
          const Color(0xFF5A189A).withValues(alpha: 0.0),
          const Color(0xFF9333EA).withValues(alpha: 0.28),
        ],
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * 0.08)
        ..lineTo(size.width * 0.4, 0)
        ..lineTo(size.width * 0.55, size.height * 0.2)
        ..lineTo(0, size.height * 0.45)
        ..close(),
      streak3,
    );

    // Subtle radial vignette for depth
    final vignette = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.5, size.height * 0.45),
        size.width * 0.75,
        [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.35),
        ],
      );
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FirstCallBadge extends StatelessWidget {
  const _FirstCallBadge({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final h = 34.0 * scale;
    final iconSize = 18.0 * scale;

    return Container(
      height: h,
      decoration: _neonBorderDecoration(
        glowColor: _neonPurple,
        radius: 20 * scale,
        fillColor: const Color(0xFF2A0F45),
        borderWidth: 2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: h,
            height: h,
            decoration: const BoxDecoration(
              color: Color(0xFF1E0A30),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.phone_in_talk_rounded,
              color: Colors.white,
              size: iconSize,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10 * scale),
            child: Text(
              '1ST CALL',
              style: GoogleFonts.inter(
                fontSize: 11 * scale,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Transform.rotate(
            angle: -0.12,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 11 * scale,
                vertical: 7 * scale,
              ),
              decoration: BoxDecoration(
                color: _goldBadge,
                borderRadius: BorderRadius.circular(6 * scale),
                boxShadow: [
                  BoxShadow(
                    color: _goldBadge.withValues(alpha: 0.55),
                    blurRadius: 10,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
              child: Text(
                'ON US!',
                style: GoogleFonts.inter(
                  fontSize: 11 * scale,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: Colors.black,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
          SizedBox(width: 6 * scale),
        ],
      ),
    );
  }
}

class _NeonGreenCallCard extends StatelessWidget {
  const _NeonGreenCallCard({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final radius = 18.0 * scale;
    final phoneSize = 54.0 * scale;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: _neonGreen.withValues(alpha: 0.7),
            blurRadius: 22 * scale,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: _neonGreen.withValues(alpha: 0.35),
            blurRadius: 40 * scale,
            spreadRadius: 2.5,
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 16 * scale,
          vertical: 16 * scale,
        ),
        decoration: _neonBorderDecoration(
          glowColor: _neonGreen,
          radius: radius,
          fillGradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D3B12), Color(0xFF062010)],
          ),
          borderWidth: 2.6,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -4 * scale,
              right: -2 * scale,
              child: _Sparkle(size: 13 * scale, color: Colors.white),
            ),
            Positioned(
              bottom: -2 * scale,
              right: 10 * scale,
              child: _Sparkle(size: 10 * scale, color: Colors.white70),
            ),
            Row(
              children: [
                Transform.rotate(
                  angle: -0.35,
                  child: Container(
                    width: phoneSize,
                    height: phoneSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.3),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.phone_in_talk_rounded,
                      color: Colors.white,
                      size: 30 * scale,
                    ),
                  ),
                ),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EVERY CALL IS',
                        style: GoogleFonts.inter(
                          fontSize: 11 * scale,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF7CFF40),
                            Color(0xFFB8FF6A),
                            Color(0xFFFFE566),
                          ],
                        ).createShader(bounds),
                        child: Text(
                          'FREE FREE!',
                          style: _promoDisplayStyle(
                            fontSize: 26 * scale,
                            color: Colors.white,
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
  const _PurpleInfoBar({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final h = 38.0 * scale;
    final radius = 20.0 * scale;

    return Container(
      height: h,
      decoration: _neonBorderDecoration(
        glowColor: _neonPurple,
        radius: radius,
        fillGradient: const LinearGradient(
          colors: [Color(0xFF5C1A8A), Color(0xFF3D0F66)],
        ),
        borderWidth: 1.8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bolt_rounded, size: 18 * scale, color: Colors.white),
                SizedBox(width: 5 * scale),
                Text(
                  'CALL ANYONE',
                  style: GoogleFonts.inter(
                    fontSize: 10.5 * scale,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                    letterSpacing: 0.35,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1.5,
            height: 22 * scale,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white.withValues(alpha: 0.45),
                  Colors.white.withValues(alpha: 0.1),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _neonPurple.withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RupeeCycleIcon(size: 18 * scale),
                SizedBox(width: 5 * scale),
                Text(
                  'NO COST',
                  style: GoogleFonts.inter(
                    fontSize: 10.5 * scale,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                    letterSpacing: 0.35,
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
