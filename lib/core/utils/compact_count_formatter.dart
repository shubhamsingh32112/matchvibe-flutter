/// Formats large counts for compact display (e.g. 12500 → "12.5K").
String formatCompactCount(int count) {
  if (count < 0) return '0';
  if (count < 1000) return count.toString();
  if (count < 1000000) {
    final value = count / 1000;
    if (value >= 100) return '${value.round()}K';
    if (value >= 10) {
      final rounded = (value * 10).round() / 10;
      return rounded == rounded.roundToDouble()
          ? '${rounded.toInt()}K'
          : '${rounded.toStringAsFixed(1)}K';
    }
    final rounded = (value * 10).round() / 10;
    return '${rounded.toStringAsFixed(1)}K';
  }
  final value = count / 1000000;
  if (value >= 100) return '${value.round()}M';
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? '${rounded.toInt()}M'
      : '${rounded.toStringAsFixed(1)}M';
}
