import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../app/widgets/app_nav_index.dart';
import '../../../core/config/app_config_provider.dart';
import '../../../app/widgets/main_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/gem_icon.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/app_modal_bottom_sheet.dart';
import '../../admin/providers/admin_view_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/stream_chat_provider.dart';
import '../../referral/screens/referral_screen.dart';
import '../../referral/widgets/referral_icon.dart';
import '../../vip/widgets/vip_badge.dart';
import '../../referral/utils/host_onboarding_routes.dart';
import '../../video/providers/call_billing_provider.dart';
import '../../video/providers/call_billing_selectors.dart';
import '../../moments/providers/moments_providers.dart';
import '../../wallet/widgets/transactions_icon.dart';
import '../widgets/account_menu_icons.dart';
import '../widgets/become_creator_icon.dart';
import '../widgets/help_support_icon.dart';
import 'account_settings_screen.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  String? _appVersion;
  String? _buildNumber;

  static const double _headerOverlap = 28;
  static const double _exploreTileRadius = 8;
  static const double _exploreLeadingExtent = 44;
  static const double _accountListLeadingExtent = 28;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
      });
    } catch (e) {
      debugPrint('Error loading app version: $e');
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Log Out',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Log Out',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      ref.read(adminViewModeProvider.notifier).reset();
      await ref.read(authProvider.notifier).signOut();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  Future<void> _reloadProfileAndRole() async {
    final previousRole = ref.read(authProvider).user?.role;
    await ref.read(authProvider.notifier).refreshUser();
    if (!mounted) return;

    final user = ref.read(authProvider).user;
    final hostRoute = hostOnboardingRedirectPath(user);
    if (hostRoute != null) {
      AppToast.showSuccess(context, 'Profile refreshed.');
      context.go(hostRoute);
      return;
    }

    final updatedRole = user?.role;
    final becameCreator = previousRole != 'creator' && updatedRole == 'creator';

    if (becameCreator) {
      AppToast.showSuccess(
        context,
        'You\'re now a host. Complete your profile in Edit Profile when ready.',
      );
      context.go('/home');
    } else {
      AppToast.showSuccess(context, 'Profile refreshed.');
    }
  }

  void _openTransactions(BuildContext context) {
    context.push('/transactions');
  }

  void _openSupport(BuildContext context) {
    context.push('/support');
  }

  void _showAccountSettingsBottomSheet(BuildContext context) {
    showAppModalBottomSheet(
      context: context,
      builder: (context) => const AccountSettingsBottomSheet(),
    );
  }

  void _showReferralBottomSheet(BuildContext context) {
    showAppModalBottomSheet(
      context: context,
      builder: (context) => const ReferralBottomSheet(),
    );
  }

  void _openBecomeCreator(BuildContext context) {
    context.push('/account/become-creator');
  }

  String _displayName(UserModel? user) {
    if (user == null) return '…';
    return user.username ?? user.name ?? user.id;
  }

  String _profileSubtitle(UserModel? user, bool isCreator) {
    if (user == null) return '';
    if (isCreator) return 'Creator';
    return 'Member';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider.select((s) => s.user));
    final authLoading = ref.watch(authProvider.select((s) => s.isLoading));
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;
    final isCreator = user?.role == 'creator' || user?.role == 'admin';
    final isPlainUser = user?.role == 'user';
    final billingState = ref.watch(callBillingProvider);
    final coins = shouldShowLiveUserCoins(
            isCreator: isCreator, billing: billingState)
        ? billingState.userCoins
        : (user?.coins ?? 0);
    final unreadAsync = ref.watch(chatUnreadCountProvider);
    final unread = unreadAsync.valueOrNull ?? 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: MainLayout(
        selectedIndex: appNavSelectedIndex(ref, '/account'),
        accountMenuStyle: true,
        child: authLoading && user == null
            ? const Center(child: LoadingIndicator())
            : ColoredBox(
                color: AppBrandGradients.accountMenuPageBackground,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildHeaderAndProfile(
                        context: context,
                        scheme: scheme,
                        topInset: topInset,
                        user: user,
                        authLoading: authLoading,
                        coins: coins,
                        isCreator: isCreator,
                        unread: unread,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        child: _sectionTitle(context, 'Explore'),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          int count = 2;
                          double ratio = 2.15;
                          if (constraints.crossAxisExtent >= 1200) {
                            count = 5;
                            ratio = 2.25;
                          } else if (constraints.crossAxisExtent >= 900) {
                            count = 4;
                            ratio = 2.2;
                          } else if (constraints.crossAxisExtent >= 640) {
                            count = 3;
                            ratio = 2.15;
                          }
                          return SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: count,
                                  mainAxisSpacing: 4,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: ratio,
                                ),
                            delegate: SliverChildListDelegate(
                              _exploreTiles(
                                context: context,
                                user: user,
                                isCreator: isCreator,
                                isPlainUser: isPlainUser,
                                coins: coins,
                                momentsEnabled: ref
                                    .watch(appFeaturesProvider)
                                    .momentsEnabled,
                                showMomentsPremiumUi: ref
                                    .watch(momentsAccessStateProvider)
                                    .showPremiumUi,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _roundedListTile(
                            context: context,
                            leading: AccountSettingsIcon(
                              size: _accountListLeadingExtent,
                            ),
                            title: 'Account & privacy',
                            onTap: () =>
                                _showAccountSettingsBottomSheet(context),
                          ),
                          const SizedBox(height: 10),
                          _roundedListTile(
                            context: context,
                            leading: ReloadProfileIcon(
                              size: _accountListLeadingExtent,
                            ),
                            title: 'Reload Profile',
                            onTap: _reloadProfileAndRole,
                          ),
                          const SizedBox(height: 10),
                          _roundedListTile(
                            context: context,
                            leading: LogoutIcon(size: _accountListLeadingExtent),
                            title: 'Log Out',
                            onTap: _handleLogout,
                            destructive: true,
                          ),
                        ]),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                        child: _footer(context, scheme),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderAndProfile({
    required BuildContext context,
    required ColorScheme scheme,
    required double topInset,
    required UserModel? user,
    required bool authLoading,
    required int coins,
    required bool isCreator,
    required int unread,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: AppBrandGradients.accountMenuHeaderGradient,
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            topInset + 8,
            16,
            _headerOverlap + 10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Menu',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Bell → chat list (no separate notifications screen yet).
              IconButton(
                tooltip: 'Messages',
                onPressed: () => context.go('/chat-list'),
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
              InkWell(
                onTap: () => context.push('/wallet'),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      const GemIcon(size: 20),
                      const SizedBox(width: 4),
                      if (authLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: LoadingIndicator(size: 16),
                        )
                      else
                        Text(
                          '$coins',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          heightFactor: 0.88,
          child: Transform.translate(
            offset: const Offset(0, -_headerOverlap),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: _profileCard(
                context: context,
                scheme: scheme,
                user: user,
                isCreator: isCreator,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileCard({
    required BuildContext context,
    required ColorScheme scheme,
    required UserModel? user,
    required bool isCreator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(26),
        boxShadow: AppBrandGradients.accountMenuCardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppBrandGradients.avatarRing,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: AppAvatar(
                  avatarAsset: user?.avatarAsset,
                  size: 64,
                  fallbackText: user?.username?.isNotEmpty == true
                      ? user!.username![0]
                      : 'U',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName(user),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _profileSubtitle(user, isCreator),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.subtitle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    await context.push('/edit-profile');
                    if (mounted) {
                      ref.read(authProvider.notifier).refreshUser();
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: AppBrandGradients.accountMenuCtaGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (user?.role == 'creator') ...[
            const SizedBox(height: 10),
            _buildRoleBadge(
              gradient: AppBrandGradients.creatorBadge,
              icon: Icons.star,
              label: 'Creator',
            ),
          ],
          if (user?.role == 'admin') ...[
            const SizedBox(height: 10),
            _buildRoleBadge(
              gradient: AppBrandGradients.adminBadge,
              icon: Icons.admin_panel_settings,
              label: 'Admin',
            ),
          ],
          if (user?.isVipActive == true) ...[
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerLeft,
              child: VipBadge(),
            ),
          ],
          if (user?.role == 'admin') ...[
            const SizedBox(height: 12),
            _buildAdminViewToggle(scheme),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    );
  }

  List<Widget> _exploreTiles({
    required BuildContext context,
    required UserModel? user,
    required bool isCreator,
    required bool isPlainUser,
    required int coins,
    required bool momentsEnabled,
    required bool showMomentsPremiumUi,
  }) {
    final transactionsTile = _exploreTile(
      context: context,
      leading: TransactionsIcon(size: _exploreLeadingExtent),
      title: 'Transactions',
      onTap: () => _openTransactions(context),
    );
    final coinsTile = _exploreTile(
      context: context,
      leading: GemIcon(size: _exploreLeadingExtent),
      title: 'Coins',
      subtitle: '$coins',
      onTap: () => context.push('/wallet'),
    );
    final referralTile = _exploreTile(
      context: context,
      leading: ReferralIcon(size: _exploreLeadingExtent),
      title: 'Referral',
      onTap: () => _showReferralBottomSheet(context),
    );
    final supportTile = _exploreTile(
      context: context,
      leading: HelpSupportIcon(size: _exploreLeadingExtent),
      title: 'Support',
      onTap: () => _openSupport(context),
    );

    if (isPlainUser) {
      return [
        if (showMomentsPremiumUi)
          _exploreTile(
            context: context,
            icon: Icons.play_circle_outline,
            title: 'Moments Premium',
            onTap: () => context.push('/account/moments-plan'),
          ),
        transactionsTile,
        coinsTile,
        referralTile,
        supportTile,
        _exploreTile(
          context: context,
          leading: BecomeCreatorIcon(size: _exploreLeadingExtent),
          title: 'Become a Creator',
          subtitle: 'We\'ll contact you',
          onTap: () => _openBecomeCreator(context),
        ),
      ];
    }

    final tiles = <Widget>[
      transactionsTile,
      coinsTile,
      referralTile,
      supportTile,
    ];

    if (isCreator && momentsEnabled) {
      tiles.add(
        _exploreTile(
          context: context,
          icon: Icons.perm_media_outlined,
          title: 'My Moments',
          onTap: () => context.push('/account/my-moments'),
        ),
      );
    }

    return tiles;
  }

  Widget _exploreTile({
    required BuildContext context,
    IconData? icon,
    Widget? leading,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    assert(leading != null || icon != null);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_exploreTileRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(_exploreTileRadius),
            boxShadow: AppBrandGradients.accountMenuCardShadow,
          ),
          child: SizedBox.expand(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: _exploreLeadingExtent,
                    height: _exploreLeadingExtent,
                    child: Center(
                      child: leading ??
                          Icon(
                            icon!,
                            color: AppBrandGradients.accountMenuIconTint,
                            size: _exploreLeadingExtent,
                          ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface,
                                  ),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppPalette.subtitle,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundedListTile({
    required BuildContext context,
    IconData? icon,
    Widget? leading,
    required String title,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    assert(leading != null || icon != null);
    final scheme = Theme.of(context).colorScheme;
    final color = destructive ? scheme.error : scheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(22),
            boxShadow: AppBrandGradients.accountMenuCardShadow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              SizedBox(
                width: _accountListLeadingExtent,
                height: _accountListLeadingExtent,
                child: Center(
                  child: leading ??
                      Icon(
                        icon!,
                        color: color,
                        size: _accountListLeadingExtent,
                      ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppPalette.subtitle.withValues(alpha: 0.7),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, ColorScheme scheme) {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            children: [
              const TextSpan(text: 'Need Help? Please contact '),
              TextSpan(
                text: 'support@matchvibe.com',
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _appVersion != null && _buildNumber != null
              ? 'Version $_appVersion ($_buildNumber)'
              : 'Version 1.0.0 (1)',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildRoleBadge({
    required LinearGradient gradient,
    required IconData icon,
    required String label,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminViewToggle(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: AppBrandGradients.accountMenuPageBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'View Mode',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, child) {
              final viewMode = ref.watch(adminViewModeProvider);
              final notifier = ref.read(adminViewModeProvider.notifier);

              if (viewMode == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  notifier.setViewMode(AdminViewMode.user);
                });
              }

              final current = viewMode ?? AdminViewMode.user;

              return Row(
                children: [
                  _adminToggleButton(
                    scheme: scheme,
                    label: 'User View',
                    icon: Icons.person,
                    isActive: current == AdminViewMode.user,
                    activeColor: scheme.primary,
                    onTap: () => notifier.setViewMode(AdminViewMode.user),
                  ),
                  const SizedBox(width: 8),
                  _adminToggleButton(
                    scheme: scheme,
                    label: 'Creator View',
                    icon: Icons.star,
                    isActive: current == AdminViewMode.creator,
                    activeColor: scheme.secondary,
                    onTap: () => notifier.setViewMode(AdminViewMode.creator),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _adminToggleButton({
    required ColorScheme scheme,
    required String label,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor
                : scheme.surface.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? activeColor
                  : scheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? scheme.onPrimary : scheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
