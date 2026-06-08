import 'package:flutter/material.dart';

import '../theme/withdrawal_tokens.dart';

class WithdrawalSectionHeader extends StatelessWidget {
  const WithdrawalSectionHeader({
    super.key,
    required this.title,
    this.underlineWord,
  });

  final String title;
  /// When set, draws a purple accent line under this word in [title].
  final String? underlineWord;

  @override
  Widget build(BuildContext context) {
    if (underlineWord == null || !title.contains(underlineWord!)) {
      return Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: WithdrawalTokens.valueDark,
        ),
      );
    }

    final word = underlineWord!;
    final index = title.indexOf(word);
    final before = title.substring(0, index);
    final after = title.substring(index + word.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        final style = const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: WithdrawalTokens.valueDark,
        );
        final painter = TextPainter(
          text: TextSpan(text: before, style: style),
          textDirection: TextDirection.ltr,
        )..layout();
        final underlineLeft = painter.width;
        final wordPainter = TextPainter(
          text: TextSpan(text: word, style: style),
          textDirection: TextDirection.ltr,
        )..layout();
        final underlineWidth = wordPainter.width.clamp(24.0, 80.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: style,
                children: [
                  TextSpan(text: before),
                  TextSpan(text: word),
                  TextSpan(text: after),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: underlineLeft),
              child: Container(
                width: underlineWidth,
                height: 3,
                decoration: BoxDecoration(
                  color: WithdrawalTokens.primaryPurple,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
