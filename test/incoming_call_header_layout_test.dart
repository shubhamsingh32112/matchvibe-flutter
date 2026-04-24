import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('incoming listener no longer renders fullscreen Material veil', () {
    final source = File(
      'lib/features/video/widgets/incoming_call_listener.dart',
    ).readAsStringSync();

    expect(source.contains('color: Colors.black54'), isFalse);
    expect(source.contains('IncomingCallWidget('), isTrue);
  });

  test('incoming call widget preserves header with top-sheet layout', () {
    final source = File(
      'lib/features/video/widgets/incoming_call_widget.dart',
    ).readAsStringSync();

    expect(source.contains('return SafeArea('), isTrue);
    expect(source.contains('IgnorePointer('), isTrue);
    expect(source.contains('CallDialCard('), isTrue);
  });
}
