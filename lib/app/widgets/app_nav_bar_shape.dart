import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'app_nav_destinations.dart';

/// Concave center notch on the top edge for the VIP FAB (user nav only).
class AppNavBarNotchClipper extends CustomClipper<Path> {
  final double topCornerRadius;
  final double notchRadius;

  const AppNavBarNotchClipper({
    this.topCornerRadius = AppNavDestinations.barTopCornerRadius,
    this.notchRadius = 36,
  });

  @override
  Path getClip(Size size) {
    final r = topCornerRadius.clamp(0.0, size.height / 2);
    final notchR = notchRadius.clamp(0.0, size.width / 4);
    final cx = size.width / 2;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(cx - notchR, 0);

    // Semicircle dip downward into the bar (cradles VIP button).
    path.arcTo(
      Rect.fromCircle(center: Offset(cx, 0), radius: notchR),
      math.pi,
      math.pi,
      false,
    );

    path
      ..lineTo(size.width - r, 0)
      ..quadraticBezierTo(size.width, 0, size.width, r)
      ..lineTo(size.width, size.height)
      ..close();

    return path;
  }

  @override
  bool shouldReclip(covariant AppNavBarNotchClipper oldClipper) {
    return oldClipper.topCornerRadius != topCornerRadius ||
        oldClipper.notchRadius != notchRadius;
  }
}

/// Rounded-rectangle clip for creator nav (no center notch).
class AppNavBarFlatClipper extends CustomClipper<Path> {
  final double topCornerRadius;

  const AppNavBarFlatClipper({
    this.topCornerRadius = AppNavDestinations.barTopCornerRadius,
  });

  @override
  Path getClip(Size size) {
    final r = topCornerRadius.clamp(0.0, size.height / 2);
    return Path()
      ..moveTo(0, size.height)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(size.width - r, 0)
      ..quadraticBezierTo(size.width, 0, size.width, r)
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant AppNavBarFlatClipper oldClipper) {
    return oldClipper.topCornerRadius != topCornerRadius;
  }
}

/// White nav background with optional center notch.
class AppNavBarBackground extends StatelessWidget {
  final CustomClipper<Path> clipper;
  final Widget child;

  const AppNavBarBackground({
    super.key,
    required this.clipper,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: clipper,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
