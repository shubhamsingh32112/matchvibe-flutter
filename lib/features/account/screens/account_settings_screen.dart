import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../../shared/styles/app_brand_styles.dart';
import 'blocked_buddies_screen.dart';
import 'delete_account_screen.dart';

/// Bottom sheet wrapper for account settings screen
class AccountSettingsBottomSheet extends StatelessWidget {
  const AccountSettingsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => const AccountSettingsScreen(),
    );
  }
}

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoadingBlockedCount = true;
  int _blockedCreatorCount = 0;

  @override
  void initState() {
    super.initState();
    _loadBlockedCount();
  }

  Future<void> _loadBlockedCount() async {
    try {
      final response = await _apiClient.get('/user/blocked-creators/count');
      final count = (response.data['data']?['blockedCreatorCount'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      setState(() {
        _blockedCreatorCount = count;
        _isLoadingBlockedCount = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _blockedCreatorCount = 0;
        _isLoadingBlockedCount = false;
      });
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final url = '${AppConstants.websiteBaseUrl}/privacy-policy';
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open Privacy Policy right now')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: AppBrandGradients.appBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Account Settings',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _settingsTile(
                        context: context,
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        onTap: _openPrivacyPolicy,
                      ),
                      _divider(scheme),
                      _settingsTile(
                        context: context,
                        icon: Icons.block_outlined,
                        title: 'Blocked Buddies',
                        trailingText: _isLoadingBlockedCount ? '...' : _blockedCreatorCount.toString(),
                        onTap: () {
                          Navigator.of(context).pop(); // Close account settings bottom sheet
                          // Show blocked buddies bottom sheet
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const BlockedBuddiesBottomSheet(),
                          );
                        },
                      ),
                      _divider(scheme),
                      _settingsTile(
                        context: context,
                        icon: Icons.delete_outline,
                        title: 'Delete Account',
                        onTap: () {
                          Navigator.of(context).pop(); // Close account settings bottom sheet
                          // Show delete account bottom sheet
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const DeleteAccountBottomSheet(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? trailingText,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: scheme.onSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _divider(ColorScheme scheme) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: scheme.outlineVariant.withOpacity(0.5),
    );
  }
}
