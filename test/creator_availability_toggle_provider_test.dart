import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zztherapy/features/creator/providers/creator_availability_toggle_provider.dart';

void main() {
  test('CreatorAvailabilityToggleState copyWith clears error when requested', () {
    const initial = CreatorAvailabilityToggleState(
      toggleOn: true,
      error: 'failed',
    );
    final next = initial.copyWith(clearError: true);
    expect(next.toggleOn, isTrue);
    expect(next.error, isNull);
  });

  test('CreatorAvailabilityToggleState defaults to toggle off', () {
    const state = CreatorAvailabilityToggleState();
    expect(state.toggleOn, isFalse);
    expect(state.isSyncing, isFalse);
  });
}
