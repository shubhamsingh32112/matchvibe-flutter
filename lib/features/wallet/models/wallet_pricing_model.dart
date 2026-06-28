class WalletCoinPack {
  final int coins;
  final int priceInr;
  final int? oldPriceInr;
  final int? originalPriceInr;
  final bool vipDiscountApplied;
  final int vipBonusCoins;
  final int totalCoinsReceived;
  final bool vipBonusApplied;
  final String? badge;
  final int sortOrder;

  const WalletCoinPack({
    required this.coins,
    required this.priceInr,
    required this.sortOrder,
    this.oldPriceInr,
    this.originalPriceInr,
    this.vipDiscountApplied = false,
    this.vipBonusCoins = 0,
    this.totalCoinsReceived = 0,
    this.vipBonusApplied = false,
    this.badge,
  });

  factory WalletCoinPack.fromJson(Map<String, dynamic> json) {
    final baseCoins = (json['coins'] as num?)?.toInt() ?? 0;
    final bonus = (json['vipBonusCoins'] as num?)?.toInt() ?? 0;
    return WalletCoinPack(
      coins: baseCoins,
      priceInr: (json['priceInr'] as num?)?.toInt() ?? 0,
      oldPriceInr: (json['oldPriceInr'] as num?)?.toInt(),
      originalPriceInr: (json['originalPriceInr'] as num?)?.toInt(),
      vipDiscountApplied: json['vipDiscountApplied'] == true,
      vipBonusCoins: bonus,
      totalCoinsReceived:
          (json['totalCoinsReceived'] as num?)?.toInt() ?? baseCoins + bonus,
      vipBonusApplied: json['vipBonusApplied'] == true,
      badge: json['badge'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class WalletPricingData {
  final String pricingTier;
  final bool hasPurchasedCoinPackage;
  final String pricingUpdatedAt;
  final List<WalletCoinPack> packages;

  const WalletPricingData({
    required this.pricingTier,
    required this.hasPurchasedCoinPackage,
    required this.pricingUpdatedAt,
    required this.packages,
  });

  factory WalletPricingData.fromJson(Map<String, dynamic> json) {
    final packagesRaw = (json['packages'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(WalletCoinPack.fromJson)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return WalletPricingData(
      pricingTier: json['pricingTier'] as String? ?? 'tier1',
      hasPurchasedCoinPackage:
          json['hasPurchasedCoinPackage'] as bool? ?? false,
      pricingUpdatedAt: json['pricingUpdatedAt'] as String? ?? '',
      packages: packagesRaw,
    );
  }
}
