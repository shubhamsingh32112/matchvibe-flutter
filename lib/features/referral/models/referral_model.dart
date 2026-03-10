/// Model for a single referred user in the referral list.
class ReferralEntry {
  final String userId;
  final String name;
  final bool rewardGranted;
  final DateTime joinedAt;

  const ReferralEntry({
    required this.userId,
    required this.name,
    required this.rewardGranted,
    required this.joinedAt,
  });

  factory ReferralEntry.fromJson(Map<String, dynamic> json) {
    return ReferralEntry(
      userId: json['userId'] as String,
      name: json['name'] as String,
      rewardGranted: json['rewardGranted'] as bool? ?? false,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
    );
  }
}

/// Response from GET /user/referrals.
class ReferralData {
  final String? referralCode;
  final List<ReferralEntry> referrals;

  const ReferralData({
    this.referralCode,
    required this.referrals,
  });

  factory ReferralData.fromJson(Map<String, dynamic> json) {
    final list = json['referrals'] as List<dynamic>? ?? [];
    return ReferralData(
      referralCode: json['referralCode'] as String?,
      referrals: list.map((e) => ReferralEntry.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
