import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('incoming listener shows modal barrier + incoming widget', () {
    final source = File(
      'lib/features/video/widgets/incoming_call_listener.dart',
    ).readAsStringSync();

    expect(source.contains('ModalBarrier('), isTrue);
    expect(source.contains('Color.fromRGBO(0, 0, 0, 0.45)'), isTrue);
    expect(source.contains('IncomingCallWidget('), isTrue);
  });

  test('incoming call widget renders centered dialog layout', () {
    final source = File(
      'lib/features/video/widgets/incoming_call_widget.dart',
    ).readAsStringSync();

    expect(source.contains('return SafeArea('), isTrue);
    expect(source.contains('Center('), isTrue);
    expect(source.contains("Incoming Video Call…"), isTrue);
    expect(source.contains("Baby, I'm alone"), isTrue);
  });
}
