import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/core/utils/compact_count_formatter.dart';
import 'package:zztherapy/features/home/utils/creator_location_display.dart';
import 'package:zztherapy/shared/models/creator_model.dart';

void main() {
  group('formatCompactCount', () {
    test('formats values under 1000 as-is', () {
      expect(formatCompactCount(0), '0');
      expect(formatCompactCount(126), '126');
      expect(formatCompactCount(999), '999');
    });

    test('formats thousands with K suffix', () {
      expect(formatCompactCount(12500), '12.5K');
      expect(formatCompactCount(10000), '10K');
      expect(formatCompactCount(105000), '105K');
    });

    test('formats millions with M suffix', () {
      expect(formatCompactCount(1000000), '1M');
      expect(formatCompactCount(2500000), '2.5M');
    });
  });

  group('creatorLocationFlagEmoji', () {
    test('maps India to flag', () {
      expect(creatorLocationFlagEmoji('India'), '🇮🇳');
      expect(creatorLocationFlagEmoji('IN'), '🇮🇳');
    });

    test('defaults to India flag when empty', () {
      expect(creatorLocationFlagEmoji(null), '🇮🇳');
      expect(creatorLocationFlagEmoji(''), '🇮🇳');
    });
  });

  group('creatorDisplayCountry', () {
    test('prefers creator location', () {
      const creator = CreatorModel(
        id: '1',
        userId: 'u1',
        name: 'Test',
        about: '',
        price: 60,
        location: 'Mumbai',
      );
      expect(creatorDisplayCountry(creator), 'Mumbai');
    });

    test('falls back to India', () {
      const creator = CreatorModel(
        id: '1',
        userId: 'u1',
        name: 'Test',
        about: '',
        price: 60,
      );
      expect(creatorDisplayCountry(creator), 'India');
    });
  });
}
