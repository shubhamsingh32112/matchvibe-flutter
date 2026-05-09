/// Visual / copy variants for outbound video-call entrypoints (tiles, sheets, chat).
///
/// Extend with seasonal / referral variants without sprinkling literals in widgets.
enum CallButtonVariant { normal, welcomeFree }

extension CallButtonVariantCopy on CallButtonVariant {
  /// Short stacked caption for circular tile (two lines handled in widget via twice).
  String get stackedPromoLine => switch (this) {
        CallButtonVariant.welcomeFree => 'FREE',
        CallButtonVariant.normal => '',
      };

  bool get showWelcomePromo => this == CallButtonVariant.welcomeFree;
}
