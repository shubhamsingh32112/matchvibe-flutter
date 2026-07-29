/// Display helpers for creator home earnings cards.
class CreatorEarningsDisplay {
  const CreatorEarningsDisplay._();

  /// Fixed host display rate used on total / free / paid earnings cards.
  static const double coinToInrRate = 0.65;

  static double coinsToInr(num coins) => coins * coinToInrRate;

  static String formatCoins(num coins) {
    final value = coins.round();
    final s = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }

  static String formatInr(num coins) {
    final inr = coinsToInr(coins).round();
    return '≈ ₹${formatCoins(inr)}';
  }

  static String resetsInLabel(DateTime? resetsAt, {DateTime? now}) {
    if (resetsAt == null) return '';
    final remaining = resetsAt.difference(now ?? DateTime.now());
    if (remaining.isNegative) return 'Resets soon';
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    if (days > 0) return 'Resets in ${days}d ${hours}h';
    final minutes = remaining.inMinutes % 60;
    if (remaining.inHours > 0) return 'Resets in ${remaining.inHours}h ${minutes}m';
    return 'Resets in ${minutes}m';
  }
}
