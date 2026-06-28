import 'package:flutter/material.dart';

import '../models/vip_models.dart';
import 'vip_page_assets.dart';

class VipBenefitSection {
  const VipBenefitSection({
    required this.id,
    required this.shortTitle,
    required this.title,
    required this.shortDescription,
    required this.description,
    this.iconAsset,
    this.fallbackIcon = Icons.star_rounded,
  });

  final String id;
  final String shortTitle;
  final String title;
  final String shortDescription;
  final String description;
  final String? iconAsset;
  final IconData fallbackIcon;
}

List<VipBenefitSection> buildVipBenefitSections(VipPlansPerks perks) {
  return [
    VipBenefitSection(
      id: 'unlimited_moments',
      shortTitle: 'Moments',
      title: 'Unlimited Moments',
      shortDescription: 'Watch every moment',
      description:
          'Access the full Moments feed plus exclusive VIP-only content.',
      iconAsset: VipPageAssets.benefitRewards,
      fallbackIcon: Icons.play_circle_outline_rounded,
    ),
    VipBenefitSection(
      id: 'priority_calls',
      shortTitle: 'Priority Calls',
      title: 'Priority call connections',
      shortDescription: 'Connect first, skip waiting',
      description:
          'Jump ahead when creators are busy and get priority access to live calls.',
      iconAsset: VipPageAssets.benefitPriorityCalls,
      fallbackIcon: Icons.phone_in_talk_rounded,
    ),
    VipBenefitSection(
      id: 'call_scheduling',
      shortTitle: 'Call Scheduling',
      title: 'Call scheduling with your fav creator',
      shortDescription: 'Book calls on your time',
      description:
          'Schedule one-on-one calls with your favourite creators whenever it suits you.',
      iconAsset: VipPageAssets.benefitCallScheduling,
      fallbackIcon: Icons.event_available_rounded,
    ),
    VipBenefitSection(
      id: 'unlimited_chats',
      shortTitle: 'Free Chats',
      title: 'Unlimited chats free',
      shortDescription: 'Message without spending',
      description:
          'Chat freely with creators without using coins on every message.',
      iconAsset: VipPageAssets.benefitFreeChats,
      fallbackIcon: Icons.chat_bubble_rounded,
    ),
    VipBenefitSection(
      id: 'recharge_rewards',
      shortTitle: 'Extra Rewards',
      title: 'Extra rewards on each recharge',
      shortDescription: 'Discount + bonus coins',
      description:
          'Get ${perks.rechargeDiscountPercent}% off recharge price and ${perks.rechargeDiscountPercent}% bonus coins on every top-up.',
      iconAsset: VipPageAssets.benefitExtraRewards,
      fallbackIcon: Icons.card_giftcard_rounded,
    ),
    VipBenefitSection(
      id: 'vip_badge',
      shortTitle: 'VIP Badge',
      title: 'VIP badging on profile',
      shortDescription: 'Stand out everywhere',
      description:
          'Show your VIP status with a premium badge and profile frame across the app.',
      iconAsset: VipPageAssets.benefitVipBadge,
      fallbackIcon: Icons.workspace_premium_rounded,
    ),
    VipBenefitSection(
      id: 'priority_support',
      shortTitle: 'Priority Support',
      title: 'Priority support for VIP',
      shortDescription: 'Help when you need it',
      description:
          'Get faster responses and dedicated support whenever you reach out to our team.',
      iconAsset: VipPageAssets.benefitPrioritySupport,
      fallbackIcon: Icons.support_agent_rounded,
    ),
  ];
}

const int vipSocialProofMemberCount = 5000;

/// Condensed highlights for the top quick-benefits row (max four columns).
List<VipBenefitSection> buildVipQuickBenefitSections(VipPlansPerks perks) {
  return buildVipBenefitSections(perks).take(4).toList();
}
