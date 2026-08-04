import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zztherapy/features/moments/utils/moment_video_fit.dart';

void main() {
  // Typical phone viewport (~9:19.5)
  const phone = Size(390, 844);

  group('resolveMomentVideoFit', () {
    test('portrait 9:16 fills phone (cover)', () {
      expect(
        resolveMomentVideoFit(video: const Size(1080, 1920), viewport: phone),
        BoxFit.cover,
      );
    });

    test('tall 9:21 fills phone (cover)', () {
      expect(
        resolveMomentVideoFit(video: const Size(1080, 2520), viewport: phone),
        BoxFit.cover,
      );
    });

    test('square fills phone (cover)', () {
      expect(
        resolveMomentVideoFit(video: const Size(1080, 1080), viewport: phone),
        BoxFit.cover,
      );
    });

    test('landscape 16:9 on phone uses contain (full frame)', () {
      expect(
        resolveMomentVideoFit(video: const Size(1920, 1080), viewport: phone),
        BoxFit.contain,
      );
    });

    test('ultra-wide 21:9 on phone uses contain', () {
      expect(
        resolveMomentVideoFit(video: const Size(2560, 1080), viewport: phone),
        BoxFit.contain,
      );
    });

    test('near-matching portrait-ish video on phone uses cover', () {
      // Slightly wider than phone but still portrait
      expect(
        resolveMomentVideoFit(video: const Size(1000, 1800), viewport: phone),
        BoxFit.cover,
      );
    });

    test('landscape video on landscape viewport uses cover', () {
      const landscapeTablet = Size(1024, 768);
      expect(
        resolveMomentVideoFit(
          video: const Size(1920, 1080),
          viewport: landscapeTablet,
        ),
        BoxFit.cover,
      );
    });

    test('zero / invalid sizes fall back to cover', () {
      expect(
        resolveMomentVideoFit(video: Size.zero, viewport: phone),
        BoxFit.cover,
      );
      expect(
        resolveMomentVideoFit(
          video: const Size(1080, 1920),
          viewport: Size.zero,
        ),
        BoxFit.cover,
      );
      expect(
        resolveMomentVideoFit(
          video: const Size(double.nan, 1920),
          viewport: phone,
        ),
        BoxFit.cover,
      );
    });
  });
}
