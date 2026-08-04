import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/features/checkin/services/checkin_popup_gate.dart';

void main() {
  setUp(() {
    CheckInPopupGate.reset();
  });

  test('auto-show allowed once per IST day in a process', () {
    expect(CheckInPopupGate.hasAutoShownForDate('2026-08-01'), isFalse);
    CheckInPopupGate.markAutoShownForDate('2026-08-01');
    expect(CheckInPopupGate.hasAutoShownForDate('2026-08-01'), isTrue);
  });

  test('IST midnight unlock allows auto-show again without relaunch', () {
    CheckInPopupGate.markAutoShownForDate('2026-08-01');
    expect(CheckInPopupGate.hasAutoShownForDate('2026-08-01'), isTrue);
    // Next IST day → gate opens again
    expect(CheckInPopupGate.hasAutoShownForDate('2026-08-02'), isFalse);
  });

  test('reset clears gate for next account / session', () {
    CheckInPopupGate.markAutoShownForDate('2026-08-01');
    CheckInPopupGate.reset();
    expect(CheckInPopupGate.hasAutoShownForDate('2026-08-01'), isFalse);
  });
}
