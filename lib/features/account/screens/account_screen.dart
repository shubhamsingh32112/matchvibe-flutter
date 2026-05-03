import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../app/widgets/main_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/gem_icon.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/app_modal_bottom_sheet.dart';
import '../../admin/providers/admin_view_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/stream_chat_provider.dart';
import '../../creator/models/creator_dashboard_model.dart';
import '../../creator/providers/creator_dashboard_provider.dart';
import '../../creator/providers/creator_status_provider.dart';
import '../../referral/screens/referral_screen.dart';
import '../../support/screens/support_screen.dart';
import '../../video/providers/call_billing_provider.dart';
import '../../wallet/screens/transactions_screen.dart';
import '../widgets/become_creator_bottom_sheet.dart';
import 'account_settings_screen.dart';
import 'help_support_screen.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  String? _appVersion;
  String? _buildNumber;

  static const double _headerOverlap = 28;
  static const double _gridTileRadius = 20;

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

    final updatedRole = ref.read(authProvider).user?.role;
    final becameCreator = previousRole != 'creator' && updatedRole == 'creator';

    if (becameCreator) {
      AppToast.showSuccess(
        context,
        'Promotion detected. Switched to creator home.',
      );
    } else {
      AppToast.showSuccess(context, 'Profile refreshed.');
    }

    if (becameCreator) {
      context.go('/home');
    }
  }

  void _showTransactionsBottomSheet(BuildContext context) {
    showAppModalBottomSheet(
      context: context,
      builder: (context) => const TransactionsBottomSheet(),
    );
  }

  void _showHelpSupportBottomSheet(BuildContext context) {
    showAppModalBottomSheet(
      context: context,
      builder: (context) => const HelpSupportBottomSheet(),
    );
  }

  void _showSupportBottomSheet(BuildContext context) {
    showAppModalBottomSheet(
      context: context,
      builder: (context) => const SupportBottomSheet(),
    );
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

  void _showBecomeCreatorBottomSheet(BuildContext context) {
    showAppModalBottomSheet(
      context: context,
      builder: (context) => const BecomeCreatorBottomSheet(),
    );
  }

  String _displayName(UserModel? user) {
    if (user == null) return '…';
    return user.username ?? user.name ?? user.id;
  }

  String _profileSubtitle(UserModel? user, bool isCreator) {
    if (user == null) return '';
    if (isCreator) return 'Creator';
    if (user.referralCode != null && user.referralCode!.isNotEmpty) {
      return 'Invite friends · ${user.referralCode}';
    }
    return 'Member';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;
    final isCreator = user?.role == 'creator' || user?.role == 'admin';
    final isPlainUser = user?.role == 'user';
    final billingState = ref.watch(callBillingProvider);
    final coins = billingState.isActive && !isCreator
        ? billingState.userCoins
        : (user?.coins ?? 0);
    final unreadAsync = ref.watch(chatUnreadCountProvider);
    final unread = unreadAsync.valueOrNull ?? 0;
    final dashboardAsync = isCreator
        ? ref.watch(creatorDashboardProvider)
        : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: MainLayout(
        selectedIndex: 3,
        accountMenuStyle: true,
        child: authState.isLoading && user == null
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
                        authLoading: authState.isLoading,
                        coins: coins,
                        isCreator: isCreator,
                        unread: unread,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: _sectionTitle(context, 'Explore'),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          int count = 2;
                          double ratio = 1.58;
                          if (constraints.crossAxisExtent >= 1200) {
                            count = 5;
                            ratio = 1.8;
                          } else if (constraints.crossAxisExtent >= 900) {
                            count = 4;
                            ratio = 1.75;
                          } else if (constraints.crossAxisExtent >= 640) {
                            count = 3;
                            ratio = 1.65;
                          }
                          return SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: count,
                                  mainAxisSpacing: 10,
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
                                dashboardAsync: dashboardAsync,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _roundedListTile(
                            context: context,
                            icon: Icons.settings_outlined,
                            title: 'Account & privacy',
                            onTap: () =>
                                _showAccountSettingsBottomSheet(context),
                          ),
                          const SizedBox(height: 10),
                          _roundedListTile(
                            context: context,
                            icon: Icons.refresh,
                            title: 'Reload Profile',
                            onTap: _reloadProfileAndRole,
                          ),
                          const SizedBox(height: 10),
                          _roundedListTile(
                            context: context,
                            icon: Icons.logout,
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
            _headerOverlap + 20,
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
        Transform.translate(
          offset: const Offset(0, -_headerOverlap),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _profileCard(
              context: context,
              scheme: scheme,
              user: user,
              isCreator: isCreator,
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
        color: Colors.white,
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
                child: ClipOval(child: AvatarWidget(user: user, size: 64)),
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
                        color: const Color(0xFF1A1A1A),
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
          if (user?.referralCode != null && user!.referralCode!.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final code = user.referralCode!;
                await Clipboard.setData(ClipboardData(text: code));
                if (!context.mounted) return;
                AppToast.showSuccess(context, 'Referral code copied');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppBrandGradients.accountMenuPageBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.card_giftcard_outlined,
                      size: 16,
                      color: AppBrandGradients.accountMenuIconTint,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      user.referralCode!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.copy, size: 14, color: AppPalette.subtitle),
                  ],
                ),
              ),
            ),
          ],
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
          if (user?.role == 'creator') ...[
            const SizedBox(height: 12),
            _buildCreatorToggle(scheme),
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
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: const Color(0xFF2D2D2D),
      ),
    );
  }

  List<Widget> _exploreTiles({
    required BuildContext context,
    required UserModel? user,
    required bool isCreator,
    required bool isPlainUser,
    required int coins,
    required AsyncValue<CreatorDashboard>? dashboardAsync,
  }) {
    final tiles = <Widget>[
      _exploreTile(
        context: context,
        icon: Icons.support_agent_outlined,
        title: 'Contact us',
        subtitle: 'Support & tickets',
        onTap: () => _showSupportBottomSheet(context),
      ),
      _exploreTile(
        context: context,
        icon: Icons.headset_mic_outlined,
        title: 'Help & Support',
        subtitle: 'FAQs & guides',
        onTap: () => _showHelpSupportBottomSheet(context),
      ),
      _exploreTile(
        context: context,
        icon: Icons.receipt_long_outlined,
        title: 'Transactions',
        subtitle: 'Payment history',
        onTap: () => _showTransactionsBottomSheet(context),
      ),
      _exploreTile(
        context: context,
        leading: const GemIcon(size: 24),
        title: 'Coins',
        subtitle: '$coins',
        onTap: () => context.push('/wallet'),
      ),
      _exploreTile(
        context: context,
        icon: Icons.card_giftcard_outlined,
        title: 'Referral',
        subtitle: (user?.referralCode != null && user!.referralCode!.isNotEmpty)
            ? user.referralCode!
            : 'Get your code',
        onTap: () => _showReferralBottomSheet(context),
      ),
    ];

    if (isCreator) {
      tiles.add(
        _exploreTile(
          context: context,
          icon: Icons.task_alt_rounded,
          title: 'Tasks',
          subtitle: _tasksSubtitle(dashboardAsync),
          onTap: () => context.push('/creator/tasks'),
        ),
      );
    } else if (isPlainUser) {
      tiles.add(
        _exploreTile(
          context: context,
          icon: Icons.auto_awesome_outlined,
          title: 'Become a Creator',
          subtitle: 'We\'ll contact you',
          onTap: () => _showBecomeCreatorBottomSheet(context),
        ),
      );
    }

    return tiles;
  }

  String _tasksSubtitle(AsyncValue<CreatorDashboard>? async) {
    if (async == null) return '—';
    return async.when(
      data: (d) {
        final tasks = d.tasks.tasks;
        if (tasks.isEmpty) return 'No tasks';
        final done = tasks.where((t) => t.isCompleted).length;
        return '$done/${tasks.length} done';
      },
      loading: () => '…',
      error: (err, stack) => '—',
    );
  }

  Widget _exploreTile({
    required BuildContext context,
    IconData? icon,
    Widget? leading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    assert(leading != null || icon != null);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_gridTileRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_gridTileRadius),
            boxShadow: AppBrandGradients.accountMenuCardShadow,
          ),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              leading ??
                  Icon(
                    icon!,
                    color: AppBrandGradients.accountMenuIconTint,
                    size: 24,
                  ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundedListTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : const Color(0xFF1A1A1A);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: AppBrandGradients.accountMenuCardShadow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
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

  Widget _buildCreatorToggle(ColorScheme scheme) {
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
            'Availability Status',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Consumer(
            builder: (context, ref, child) {
              final status = ref.watch(creatorStatusProvider);
              final isOnline = status == CreatorStatus.online;

              return Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline ? scheme.primary : scheme.outlineVariant,
                      boxShadow: isOnline
                          ? [
                              BoxShadow(
                                color: scheme.primary.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Status is automatic based on app open/close',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline ? Colors.green : Colors.grey,
                      border: Border.all(color: scheme.surface, width: 2),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
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
