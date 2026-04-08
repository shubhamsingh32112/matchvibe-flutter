/// Matches backend [isValidReferralCodeFormat]: legacy 6-char or current 8-char.
class ReferralCodeFormat {
  ReferralCodeFormat._();

  static final RegExp _v1 = RegExp(r'^[A-Z]{2}\d{4}$');
  static final RegExp _v2 = RegExp(r'^[A-Z]{3}\d{5}$');

  static bool isValid(String raw) {
    final s = raw.trim().toUpperCase();
    if (s.length == 6 && _v1.hasMatch(s)) return true;
    if (s.length == 8 && _v2.hasMatch(s)) return true;
    return false;
  }
}
