import 'package:flutter/services.dart';

/// Digits (ASCII + fullwidth) are not allowed in moments comments.
final RegExp momentCommentDigitPattern = RegExp(r'[0-9０-９]');

/// English number words (cardinals / scale words) are not allowed in moments comments.
final RegExp momentCommentNumberWordPattern = RegExp(
  r'\b(zero|one|two|three|four|five|six|seven|eight|nine|ten|'
  r'eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|'
  r'twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|'
  r'hundred|thousand|million|billion)\b',
  caseSensitive: false,
);

bool momentCommentContainsDigits(String text) =>
    momentCommentDigitPattern.hasMatch(text);

bool momentCommentContainsNumberWords(String text) =>
    momentCommentNumberWordPattern.hasMatch(text);

/// True when [text] contains digits or number-words.
bool momentCommentContainsNumbers(String text) =>
    momentCommentContainsDigits(text) || momentCommentContainsNumberWords(text);

/// Blocks digits as they are typed/pasted, and rejects edits that introduce number-words.
class MomentCommentNoNumbersFormatter extends TextInputFormatter {
  const MomentCommentNoNumbersFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (momentCommentContainsNumbers(newValue.text)) {
      return oldValue;
    }
    return newValue;
  }
}
