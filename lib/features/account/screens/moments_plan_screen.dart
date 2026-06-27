import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/widgets/app_nav_destinations.dart';
import '../../../app/widgets/app_nav_index.dart';
import '../../../app/widgets/main_layout.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/decorative_asset_image.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../../vip/constants/vip_page_assets.dart';
import '../models/moments_premium_models.dart';
import '../providers/moments_premium_provider.dart';
import '../../moments/providers/moments_providers.dart';
import '../theme/moments_premium_page_tokens.dart';

const _planFeatures = <String>[
  'Unlimited Moments',
  'Verified Creators',
  'First Access to Premium Moments and Stories',
];

class MomentsPlanScreen extends ConsumerStatefulWidget {
  const MomentsPlanScreen({super.key});

  @override
  ConsumerState<MomentsPlanScreen> createState() => _MomentsPlanScreenState();
}

class _MomentsPlanScreenState extends ConsumerState<MomentsPlanScreen> {
  String? _selectedPlanId;
  bool _isCheckingOut = false;

  Future<void> _refresh() async {
    final container = ProviderScope.containerOf(context, listen: false);
    ref.invalidate(momentsPremiumPlansProvider);
    ref.invalidate(momentsPremiumStatusProvider);
    await ref.read(authProvider.notifier).refreshUser();
    invalidateMomentsFeeds(container);
  }

  void _ensureDefaultSelection(MomentsPremiumPlansResponse response) {
    if (_selectedPlanId != null) return;
    final defaultPlan = response.defaultPlan;
    if (defaultPlan != null) {
      _selectedPlanId = defaultPlan.planId;
    }
  }

  MomentsPremiumPlanOption? _selectedPlan(MomentsPremiumPlansResponse response) {
    final plans = response.activePlans;
    if (plans.isEmpty) return null;
    return plans.firstWhere(
      (plan) => plan.planId == _selectedPlanId,
      orElse: () => response.defaultPlan ?? plans.first,
    );
  }

  Future<void> _onBuy(String planId) async {
    if (_isCheckingOut) return;
    setState(() => _isCheckingOut = true);
    try {
      final url = await ref
          .read(momentsPremiumApiServiceProvider)
          .initiateCheckout(planId: planId);
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        AppToast.showError(context, 'Could not open checkout');
      }
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, 'Failed to start Moments Premium checkout');
      }
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider.select((s) => s.user?.role));
    if (AppNavDestinations.isCreatorOrAdmin(role)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/account');
      });
      return const SizedBox.shrink();
    }

    final premiumStatus =
        ref.watch(authProvider.select((s) => s.user?.momentsPremiumStatus));
    final plansAsync = ref.watch(momentsPremiumPlansProvider);
    final isActive = premiumStatus?.active == true;

    return MainLayout(
      selectedIndex: appNavSelectedIndex(ref, '/account'),
      vipPageStyle: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: MomentsPremiumPageTokens.pageGlow,
        ),
        child: plansAsync.when(
          loading: () => const Center(
            child: LoadingIndicator(color: MomentsPremiumPageTokens.accentPink),
          ),
          error: (_, __) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Could not load plans. Pull to refresh.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lexend(color: MomentsPremiumPageTokens.textMuted),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (response) {
            _ensureDefaultSelection(response);
            final selectedPlan = _selectedPlan(response);
            final activePlans = response.activePlans;
            final canPurchase = activePlans.isNotEmpty && selectedPlan != null;

            return Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    color: MomentsPremiumPageTokens.accentPink,
                    backgroundColor: MomentsPremiumPageTokens.surface,
                    onRefresh: _refresh,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _HeroSection(onBack: () => context.pop())),
                        if (isActive) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: _ActiveMemberBanner(
                                expiresLabel: premiumStatus!.expiresAt != null
                                    ? 'Active until ${_formatDate(premiumStatus.expiresAt!)}'
                                    : 'Moments Premium Active',
                              ),
                            ),
                          ),
                        ],
                        const SliverToBoxAdapter(child: SizedBox(height: 20)),
                        const SliverToBoxAdapter(child: _BenefitsGrid()),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        SliverToBoxAdapter(
                          child: Text(
                            '✨ Choose Your Plan ✨',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.lexend(
                              color: MomentsPremiumPageTokens.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 14)),
                        SliverToBoxAdapter(
                          child: _PlanSelector(
                            plans: activePlans,
                            selectedPlanId: _selectedPlanId ?? '',
                            onPlanSelected: (id) => setState(() => _selectedPlanId = id),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        const SliverToBoxAdapter(child: _SecurityBanner()),
                        const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      ],
                    ),
                  ),
                ),
                _SubscribeFooter(
                  onBuy: canPurchase ? () => _onBuy(selectedPlan.planId) : null,
                  isLoading: _isCheckingOut,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: 300,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const _BlurredPortraitBackground(),
          Positioned(
            top: topInset + 8,
            left: MomentsPremiumPageTokens.horizontalPadding,
            child: _BackButton(onTap: onBack),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: topInset + 44,
            child: Column(
              children: [
                const _CrownShowcase(),
                const SizedBox(height: 10),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.lexend(
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      height: 1.1,
                      letterSpacing: -0.4,
                    ),
                    children: [
                      const TextSpan(
                        text: 'Moments ',
                        style: TextStyle(color: MomentsPremiumPageTokens.textPrimary),
                      ),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: ShaderMask(
                          shaderCallback: (bounds) =>
                              MomentsPremiumPageTokens.premiumTextGradient
                                  .createShader(bounds),
                          child: Text(
                            'Premium',
                            style: GoogleFonts.lexend(
                              fontWeight: FontWeight.w800,
                              fontSize: 28,
                              height: 1.1,
                              letterSpacing: -0.4,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    'Unlock exclusive photos, videos, and stories from verified creators.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lexend(
                      color: MomentsPremiumPageTokens.textPrimary.withValues(alpha: 0.92),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enjoy unlimited access anytime.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(
                    color: MomentsPremiumPageTokens.accentPink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.45),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _BlurredPortraitBackground extends StatelessWidget {
  const _BlurredPortraitBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: -24,
              top: 18,
              child: _portraitTile(const Color(0xFF7B2CBF), locked: true),
            ),
            Positioned(
              right: -18,
              top: 8,
              child: _portraitTile(const Color(0xFFFF4B91), locked: false),
            ),
            Positioned(
              left: 42,
              top: 52,
              child: _portraitTile(const Color(0xFF5B2EFF), locked: true, small: true),
            ),
            Positioned(
              right: 36,
              top: 64,
              child: _portraitTile(const Color(0xFFCE93D8), locked: false, small: true),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  color: MomentsPremiumPageTokens.pageBackground.withValues(alpha: 0.35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _portraitTile(Color color, {required bool locked, bool small = false}) {
    final size = small ? 56.0 : 78.0;
    return Container(
      width: size,
      height: size * 1.25,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.75),
            color.withValues(alpha: 0.35),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.person_rounded,
            size: small ? 28 : 38,
            color: Colors.white.withValues(alpha: 0.55),
          ),
          if (locked)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Icon(
                  Icons.lock_rounded,
                  size: small ? 18 : 24,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CrownShowcase extends StatelessWidget {
  const _CrownShowcase();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  MomentsPremiumPageTokens.accentPurple.withValues(alpha: 0.45),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          DecorativeAssetImage(
            assetPath: VipPageAssets.crownHero,
            width: 72,
            height: 48,
            fallbackIcon: Icons.workspace_premium_rounded,
            fallbackIconSize: 52,
            fallbackIconColor: MomentsPremiumPageTokens.accentGold,
          ),
          const Positioned(top: 2, left: 8, child: _Sparkle(size: 8)),
          const Positioned(top: 10, right: 6, child: _Sparkle(size: 6)),
          const Positioned(bottom: 8, left: 2, child: _Sparkle(size: 5)),
          const Positioned(bottom: 4, right: 10, child: _Sparkle(size: 7)),
        ],
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.auto_awesome,
      size: size,
      color: Colors.white.withValues(alpha: 0.85),
    );
  }
}

class _BenefitsGrid extends StatelessWidget {
  const _BenefitsGrid();

  static const _benefits = <({IconData icon, Color iconColor, String title, String desc})>[
    (
      icon: Icons.all_inclusive_rounded,
      iconColor: MomentsPremiumPageTokens.accentPink,
      title: 'Enjoy Premium Moments',
      desc: 'Exclusive photos and videos from creators',
    ),
    (
      icon: Icons.verified_user_rounded,
      iconColor: MomentsPremiumPageTokens.accentPurple,
      title: 'Unlimited Moments',
      desc: 'Access all premium content without restrictions',
    ),
    (
      icon: Icons.verified_rounded,
      iconColor: MomentsPremiumPageTokens.accentPurple,
      title: 'Verified Creators',
      desc: 'Only trusted and verified creators on MatchVibe',
    ),
    (
      icon: Icons.bolt_rounded,
      iconColor: MomentsPremiumPageTokens.accentGold,
      title: 'First Access to Premium Moments and Stories',
      desc: 'Be the first to watch new premium content & stories',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MomentsPremiumPageTokens.horizontalPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _benefits.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: _BenefitTile(benefit: _benefits[i])),
          ],
        ],
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({required this.benefit});

  final ({IconData icon, Color iconColor, String title, String desc}) benefit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: benefit.iconColor.withValues(alpha: 0.65),
              width: 1.5,
            ),
            color: benefit.iconColor.withValues(alpha: 0.12),
          ),
          child: Icon(benefit.icon, color: benefit.iconColor, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          benefit.title,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.lexend(
            color: MomentsPremiumPageTokens.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 9.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          benefit.desc,
          textAlign: TextAlign.center,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.lexend(
            color: MomentsPremiumPageTokens.textMuted,
            fontSize: 8,
            fontWeight: FontWeight.w400,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _ActiveMemberBanner extends StatelessWidget {
  const _ActiveMemberBanner({required this.expiresLabel});

  final String expiresLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: MomentsPremiumPageTokens.badgeGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              expiresLabel,
              style: GoogleFonts.lexend(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanSelector extends StatelessWidget {
  const _PlanSelector({
    required this.plans,
    required this.selectedPlanId,
    required this.onPlanSelected,
  });

  final List<MomentsPremiumPlanOption> plans;
  final String selectedPlanId;
  final ValueChanged<String> onPlanSelected;

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MomentsPremiumPageTokens.horizontalPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < plans.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _PlanCard(
                plan: plans[i],
                selected: plans[i].planId == selectedPlanId,
                featured: plans[i].badge == MomentsPremiumPlanBadge.mostPopular,
                onTap: () => onPlanSelected(plans[i].planId),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.featured,
    required this.onTap,
  });

  final MomentsPremiumPlanOption plan;
  final bool selected;
  final bool featured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? MomentsPremiumPageTokens.accentPink
        : Colors.white.withValues(alpha: 0.1);

    return Transform.scale(
      scale: featured ? 1.03 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MomentsPremiumPageTokens.cardRadius),
          child: Ink(
            decoration: BoxDecoration(
              gradient: MomentsPremiumPageTokens.cardGradient,
              borderRadius: BorderRadius.circular(MomentsPremiumPageTokens.cardRadius),
              border: Border.all(color: borderColor, width: selected ? 2 : 1),
              boxShadow: selected
                  ? MomentsPremiumPageTokens.selectedCardGlow(
                      MomentsPremiumPageTokens.accentPurple,
                    )
                  : null,
            ),
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (plan.badge != null)
                  _PlanBadge(badge: plan.badge!),
                if (plan.badge != null) const SizedBox(height: 10),
                Text(
                  plan.label,
                  style: GoogleFonts.lexend(
                    color: MomentsPremiumPageTokens.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      MomentsPremiumPageTokens.premiumTextGradient.createShader(bounds),
                  child: Text(
                    '₹${plan.priceInr}',
                    style: GoogleFonts.lexend(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      height: 1,
                    ),
                  ),
                ),
                if (plan.billedLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    plan.billedLabel!,
                    style: GoogleFonts.lexend(
                      color: MomentsPremiumPageTokens.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                for (final feature in _planFeatures) ...[
                  _FeatureRow(label: feature),
                  const SizedBox(height: 5),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.badge});

  final MomentsPremiumPlanBadge badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        gradient: MomentsPremiumPageTokens.badgeGradient,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${momentsPremiumBadgeEmoji(badge)} ${momentsPremiumBadgeLabel(badge)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.lexend(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 7.5,
          height: 1.15,
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_rounded,
          size: 12,
          color: MomentsPremiumPageTokens.checkPurple,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.lexend(
              color: MomentsPremiumPageTokens.textPrimary.withValues(alpha: 0.9),
              fontSize: 7.5,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _SecurityBanner extends StatelessWidget {
  const _SecurityBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MomentsPremiumPageTokens.horizontalPadding,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: MomentsPremiumPageTokens.surfaceElevated.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MomentsPremiumPageTokens.accentPurple.withValues(alpha: 0.2),
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: MomentsPremiumPageTokens.accentPurple,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cancel anytime. No hidden charges. Your subscription is 100% secure.',
                style: GoogleFonts.lexend(
                  color: MomentsPremiumPageTokens.textPrimary.withValues(alpha: 0.9),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [
                        MomentsPremiumPageTokens.accentPurple.withValues(alpha: 0.85),
                        MomentsPremiumPageTokens.accentPink.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                  child: const Icon(Icons.lock_rounded, color: Colors.white, size: 16),
                ),
                const Positioned(top: -4, right: -4, child: _Sparkle(size: 8)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscribeFooter extends StatelessWidget {
  const _SubscribeFooter({
    required this.onBuy,
    this.isLoading = false,
  });

  final VoidCallback? onBuy;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        MomentsPremiumPageTokens.horizontalPadding,
        8,
        MomentsPremiumPageTokens.horizontalPadding,
        12,
      ),
      color: MomentsPremiumPageTokens.pageBackground,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: MomentsPremiumPageTokens.ctaGradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: MomentsPremiumPageTokens.accentPink.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isLoading ? null : onBuy,
                    borderRadius: BorderRadius.circular(28),
                    child: Center(
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                DecorativeAssetImage(
                                  assetPath: VipPageAssets.crownSmall,
                                  width: 28,
                                  height: 28,
                                  fallbackIcon: Icons.workspace_premium_rounded,
                                  fallbackIconSize: 24,
                                  fallbackIconColor: MomentsPremiumPageTokens.accentGold,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Unlock Premium Moments',
                                  style: GoogleFonts.lexend(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '🔒 Secure Payment | 🛡️ Powered by Razorpay',
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                color: MomentsPremiumPageTokens.textMuted.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
