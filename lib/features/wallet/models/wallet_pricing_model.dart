class WalletCoinPack {
  final int coins;
  final int priceInr;
  final int? oldPriceInr;
  final String? badge;
  final int sortOrder;

  const WalletCoinPack({
    required this.coins,
    required this.priceInr,
    required this.sortOrder,
    this.oldPriceInr,
    this.badge,
  });

  factory WalletCoinPack.fromJson(Map<String, dynamic> json) {
    return WalletCoinPack(
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      priceInr: (json['priceInr'] as num?)?.toInt() ?? 0,
      oldPriceInr: (json['oldPriceInr'] as num?)?.toInt(),
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

