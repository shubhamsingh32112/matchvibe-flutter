import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Device-only soak scenarios — excluded from default CI.
///
/// Run on a physical device:
///   flutter test integration_test/moments_mobile_soak_test.dart \
///     --dart-define=MOMENTS_VIDEO_PLAYBACK_METRICS=true
@Tags(['mobile-soak'])
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('mobile-soak placeholder — run manual matrix in docs/moments-mobile-soak.md', () {
    // Automated device soak requires signed playback + auth fixtures.
    // Mark pass when manual checklist in docs/moments-mobile-soak-results.md is signed off.
    expect(true, isTrue);
  });
}
