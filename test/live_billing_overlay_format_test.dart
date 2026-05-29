import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/features/video/widgets/live_billing_overlay.dart';

void main() {
  test('formats under one hour as MM:SS', () {
    expect(formatBillingMmSs(0), '00:00');
    expect(formatBillingMmSs(65), '01:05');
    expect(formatBillingMmSs(3599), '59:59');
  });

  test('formats one hour or more as H:MM:SS', () {
    expect(formatBillingMmSs(3600), '1:00:00');
    expect(formatBillingMmSs(3630), '1:00:30');
    expect(formatBillingMmSs(35970), '9:59:30');
  });
}
