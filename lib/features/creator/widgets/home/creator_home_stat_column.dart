import 'package:flutter/material.dart';

/// Single stat cell matching the creator home reference (icon + value).
class CreatorHomeStatColumn extends StatelessWidget {
  const CreatorHomeStatColumn({
    super.key,
    required this.iconAssetPath,
    this.iconSize = 50,
    required this.value,
    this.unitSuffix,
    this.valueFontWeight = FontWeight.w600,
  });

  final String iconAssetPath;
  final double iconSize;
  final String value;
  /// When set, rendered in smaller weight after [value] (e.g. "min").
  final String? unitSuffix;
  final FontWeight valueFontWeight;

  static const _valueColor = Color(0xFF1B1B33);
  static const double _valueFontSize = 15;
  static const double _unitFontSize = 11;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: iconSize,
          height: iconSize,
          child: Image.asset(
            iconAssetPath,
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
        ),
        const SizedBox(height: 8),
        if (unitSuffix != null)
          RichText(
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(
                fontSize: _valueFontSize,
                fontWeight: valueFontWeight,
                color: _valueColor,
                height: 1.2,
              ),
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: ' $unitSuffix',
                  style: const TextStyle(
                    fontSize: _unitFontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _valueFontSize,
              fontWeight: valueFontWeight,
              color: _valueColor,
              height: 1.2,
            ),
          ),
      ],
    );
  }
}

class CreatorHomeStatDivider extends StatelessWidget {
  const CreatorHomeStatDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: const Color(0xFFE6E6EB),
    );
  }
}
