import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/widgets/app_nav_destinations.dart';
import '../../../app/widgets/main_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../constants/vip_benefits_content.dart';
import '../models/vip_models.dart';
import '../providers/vip_provider.dart';
import '../theme/vip_page_tokens.dart';
import '../widgets/vip_active_member_panel.dart';
import '../widgets/vip_benefits_detail_list.dart';
import '../widgets/vip_featured_plan_banner.dart';
import '../widgets/vip_hero_section.dart';
import '../widgets/vip_page_header.dart';
import '../widgets/vip_plan_selector.dart';
import '../widgets/vip_quick_benefits_row.dart';
import '../widgets/vip_subscribe_footer.dart';

class VipScreen extends ConsumerStatefulWidget {
  const VipScreen({super.key});

  @override
  ConsumerState<VipScreen> createState() => _VipScreenState();
}

class _VipScreenState extends ConsumerState<VipScreen> {
  String? _selectedPlanId;
  bool _isCheckingOut = false;

  Future<void> _refresh() async {
    ref.invalidate(vipPlansProvider);
    ref.invalidate(vipStatusProvider);
    await ref.read(authProvider.notifier).refreshUser();
  }

  Future<void> _subscribe(String planId, {required bool isActive}) async {
    if (_isCheckingOut) return;
    setState(() => _isCheckingOut = true);
    try {
      final url = await ref
          .read(vipApiServiceProvider)
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
        AppToast.showError(context, 'Failed to start VIP checkout');
      }
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _ensureDefaultSelection(VipPlansResponse response) {
    if (_selectedPlanId != null) return;
    final defaultPlan = response.defaultPlan;
    if (defaultPlan != null) {
      _selectedPlanId = defaultPlan.planId;
    }
  }

  VipPlanOption? _selectedPlan(VipPlansResponse response) {
    final plans = response.activePlans;
    if (plans.isEmpty) return null;
    return plans.firstWhere(
      (plan) => plan.planId == _selectedPlanId,
      orElse: () => response.defaultPlan ?? plans.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider.select((s) => s.user?.role));
    if (AppNavDestinations.isCreatorOrAdmin(role)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/recent');
      });
      return const SizedBox.shrink();
    }

    final vipStatus = ref.watch(authProvider.select((s) => s.user?.vipStatus));
    final plansAsync = ref.watch(vipPlansProvider);
    final isActive = vipStatus?.active == true;

    return Theme(
      data: AppTheme.vipInheritedTheme,
      child: MainLayout(
        selectedIndex: AppNavDestinations.centerIndex,
        vipPageStyle: true,
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: VipPageTokens.pageBackground),
          child: plansAsync.when(
            loading: () => const Center(
              child: LoadingIndicator(color: VipPageTokens.borderGold),
            ),
          error: (_, __) => Center(
            child: Text(
              'Could not load VIP plans. Pull to refresh.',
              style: TextStyle(color: VipPageTokens.textMuted),
            ),
          ),
          data: (response) {
            _ensureDefaultSelection(response);
            final selectedPlan = _selectedPlan(response);
            final benefitSections = buildVipBenefitSections(response.perks);
            final quickBenefitSections =
                buildVipQuickBenefitSections(response.perks);
            final activePlans = response.activePlans;
            final canPurchase = activePlans.isNotEmpty && selectedPlan != null;

            return RefreshIndicator(
              color: VipPageTokens.borderGold,
              backgroundColor: VipPageTokens.surface,
              onRefresh: _refresh,
              child: Stack(
                children: [
                  CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      const SliverToBoxAdapter(child: VipPageHeader()),
                      SliverToBoxAdapter(
                        child: VipHeroSection(compact: isActive),
                      ),
                      if (isActive) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: VipActiveMemberPanel(
                              expiresLabel: vipStatus!.expiresAt != null
                                  ? 'Active until ${_formatDate(vipStatus.expiresAt!)}'
                                  : 'VIP Active',
                              remaining: vipStatus.freeMomentsRemainingToday,
                              total: vipStatus.freeMomentsDailyLimit,
                            ),
                          ),
                        ),
                      ] else ...[
                        const SliverToBoxAdapter(child: SizedBox(height: 18)),
                        SliverToBoxAdapter(
                          child: VipQuickBenefitsRow(
                            sections: quickBenefitSections,
                          ),
                        ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 18)),
                      SliverToBoxAdapter(
                        child: VipBenefitsDetailList(sections: benefitSections),
                      ),
                      if (selectedPlan != null) ...[
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        if (activePlans.length > 1)
                          SliverToBoxAdapter(
                            child: VipPlanSelector(
                              plans: activePlans,
                              selectedPlanId:
                                  _selectedPlanId ?? activePlans.first.planId,
                              onPlanSelected: (planId) {
                                setState(() => _selectedPlanId = planId);
                              },
                            ),
                          )
                        else
                          SliverToBoxAdapter(
                            child: VipFeaturedPlanBanner(plan: selectedPlan),
                          ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 96)),
                    ],
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: canPurchase
                        ? VipSubscribeFooter(
                            label: isActive ? 'Renew VIP' : 'Become VIP Now',
                            isLoading: _isCheckingOut,
                            onPressed: () => _subscribe(
                              selectedPlan.planId,
                              isActive: isActive,
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'VIP is not available right now.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: VipPageTokens.textMuted),
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      ),
    );
  }
}
