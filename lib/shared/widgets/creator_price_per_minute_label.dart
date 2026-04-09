import 'package:flutter/material.dart';
import 'gem_icon.dart';

/// Formats [price] (coins per minute) for display: whole numbers without decimals,
/// otherwise one decimal place. Invalid values yield empty string (caller may hide).
String formatCreatorPricePerMinute(double price) {
  if (price.isNaN || price <= 0) return '';
  final rounded = price.roundToDouble();
  if ((price - rounded).abs() < 1e-9) {
    return rounded.toInt().toString();
  }
  return price.toStringAsFixed(1);
}

/// Diamond icon + amount + " / min" — used on home creator tiles and profile sheet.
class CreatorPricePerMinuteLabel extends StatelessWidget {
  final double price;
  final double iconSize;
  final Color? iconColor;
  final TextStyle? textStyle;
  final TextAlign textAlign;
  final int maxLines;
  final TextOverflow overflow;
  final bool expandText;

  const CreatorPricePerMinuteLabel({
    super.key,
    required this.price,
    this.iconSize = 18,
    this.iconColor,
    this.textStyle,
    this.textAlign = TextAlign.start,
    this.maxLines = 1,
    this.overflow = TextOverflow.visible,
    this.expandText = false,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = formatCreatorPricePerMinute(price);
    if (formatted.isEmpty) {
      return const SizedBox.shrink();
    }

    final defaultStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        );
    final effectiveStyle = textStyle ?? defaultStyle;

    final text = Text(
      '$formatted / min',
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      style: effectiveStyle,
    );

    final row = expandText
        ? Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GemIcon(size: iconSize, color: iconColor),
              const SizedBox(width: 6),
              Expanded(child: text),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GemIcon(size: iconSize, color: iconColor),
              const SizedBox(width: 6),
              text,
            ],
          );

    return Semantics(
      label: '$formatted coins per minute',
      child: row,
    );
  }
}
