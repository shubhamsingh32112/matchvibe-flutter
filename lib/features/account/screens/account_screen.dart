import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../app/widgets/main_layout.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../../admin/providers/admin_view_provider.dart';
import '../../creator/providers/creator_status_provider.dart';
import '../../wallet/screens/wallet_screen.dart';
import '../../wallet/screens/transactions_screen.dart';
import 'help_support_screen.dart';
import '../../support/screens/support_screen.dart';
import 'account_settings_screen.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  String? _appVersion;
  String? _buildNumber;

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
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
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
    final becameCreator =
        previousRole != 'creator' && updatedRole == 'creator';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          becameCreator
              ? 'Promotion detected. Switched to creator home.'
              : 'Profile refreshed.',
        ),
        backgroundColor: becameCreator ? Colors.green : null,
      ),
    );

    if (becameCreator) {
      context.go('/home');
    }
  }

  void _showWalletBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const WalletBottomSheet(),
    );
  }

  void _showTransactionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const TransactionsBottomSheet(),
    );
  }

  void _showHelpSupportBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const HelpSupportBottomSheet(),
    );
  }

  void _showSupportBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SupportBottomSheet(),
    );
  }

  void _showAccountSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AccountSettingsBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final scheme = Theme.of(context).colorScheme;

    return MainLayout(
      selectedIndex: 3,
      child: authState.isLoading && user == null
          ? const Center(child: LoadingIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),

                    // ── Profile Header Card ──────────────────────────
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 28),
                            child: Center(
                              child: Column(
                                children: [
                                  // Profile Picture
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: AppBrandGradients.avatarRing,
                                      border: Border.all(
                                        color: scheme.surface,
                                        width: 3,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: AvatarWidget(
                                        user: user,
                                        size: 100,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // Username
                                  Text(
                                    user?.username ?? user?.id ?? 'N/A',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: scheme.onSurface,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),

                                  // Creator Badge
                                  if (user?.role == 'creator') ...[
                                    const SizedBox(height: 10),
                                    _buildRoleBadge(
                                      gradient:
                                          AppBrandGradients.creatorBadge,
                                      icon: Icons.star,
                                      label: 'Creator',
                                    ),
                                    const SizedBox(height: 16),
                                    _buildCreatorToggle(scheme),
                                  ],

                                  // Admin Badge & View‑mode Toggle
                                  if (user?.role == 'admin') ...[
                                    const SizedBox(height: 10),
                                    _buildRoleBadge(
                                      gradient: AppBrandGradients.adminBadge,
                                      icon: Icons.admin_panel_settings,
                                      label: 'Admin',
                                    ),
                                    const SizedBox(height: 16),
                                    _buildAdminViewToggle(scheme),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          // Edit Button (top‑right)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: IconButton(
                              onPressed: () async {
                                await context.push('/edit-profile');
                                if (mounted) {
                                  ref
                                      .read(authProvider.notifier)
                                      .refreshUser();
                                }
                              },
                              icon: Icon(
                                Icons.edit_outlined,
                                color: scheme.onSurface,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Menu Items (grouped in one card) ─────────────
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _buildMenuItem(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'Wallet',
                            onTap: () => _showWalletBottomSheet(context),
                          ),
                          _divider(scheme),
                          _buildMenuItem(
                            icon: Icons.receipt_long_outlined,
                            title: 'Transactions',
                            onTap: () => _showTransactionsBottomSheet(context),
                          ),
                          _divider(scheme),
                          _buildMenuItem(
                            icon: Icons.headset_mic_outlined,
                            title: 'Help & Support',
                            onTap: () => _showHelpSupportBottomSheet(context),
                          ),
                          _divider(scheme),
                          _buildMenuItem(
                            icon: Icons.support_agent_outlined,
                            title: 'Contact Support',
                            onTap: () => _showSupportBottomSheet(context),
                          ),
                          _divider(scheme),
                          _buildMenuItem(
                            icon: Icons.manage_accounts_outlined,
                            title: 'Account Settings',
                            onTap: () => _showAccountSettingsBottomSheet(context),
                          ),
                          _divider(scheme),
                          _buildMenuItem(
                            icon: Icons.refresh,
                            title: 'Reload Profile',
                            onTap: _reloadProfileAndRole,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Log Out (separate card) ──────────────────────
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: _buildMenuItem(
                        icon: Icons.logout,
                        title: 'Log Out',
                        onTap: _handleLogout,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Footer ───────────────────────────────────────
                    Column(
                      children: [
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                            children: [
                              const TextSpan(
                                  text: 'Need Help? Please contact '),
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
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────

  /// A single menu row: icon · title ··· chevron
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: scheme.onSurface, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: scheme.onSurfaceVariant,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  /// Thin divider that matches the screenshot.
  Widget _divider(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: scheme.outlineVariant.withOpacity(0.5),
      ),
    );
  }

  /// Role badge pill (Creator / Admin).
  Widget _buildRoleBadge({
    required LinearGradient gradient,
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Creator online/offline toggle.
  Widget _buildCreatorToggle(ColorScheme scheme) {
    return AppCard(
      padding: const EdgeInsets.all(16),
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
                                color: scheme.primary.withOpacity(0.5),
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
                  // Status indicator (read-only, no toggle)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline ? Colors.green : Colors.grey,
                      border: Border.all(
                        color: scheme.surface,
                        width: 2,
                      ),
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

  /// Admin user/creator view‑mode toggle.
  Widget _buildAdminViewToggle(ColorScheme scheme) {
    return AppCard(
      padding: const EdgeInsets.all(16),
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
                    onTap: () =>
                        notifier.setViewMode(AdminViewMode.user),
                  ),
                  const SizedBox(width: 8),
                  _adminToggleButton(
                    scheme: scheme,
                    label: 'Creator View',
                    icon: Icons.star,
                    isActive: current == AdminViewMode.creator,
                    activeColor: scheme.secondary,
                    onTap: () =>
                        notifier.setViewMode(AdminViewMode.creator),
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
            color: isActive ? activeColor : scheme.surface.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? activeColor
                  : scheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive
                    ? scheme.onPrimary
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive
                      ? scheme.onPrimary
                      : scheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight:
                      isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
