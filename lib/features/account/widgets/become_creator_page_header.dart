import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/gem_icon.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/stream_chat_provider.dart';
import '../../video/providers/call_billing_provider.dart';
import '../../video/providers/call_billing_selectors.dart';

class BecomeCreatorPageHeader extends ConsumerWidget {
  const BecomeCreatorPageHeader({super.key});

  static String displayName(UserModel? user) {
    if (user == null) return '…';
    return user.username ?? user.name ?? user.id;
  }

  static String profileSubtitle(UserModel? user) {
    if (user == null) return '';
    if (user.referralCode != null && user.referralCode!.isNotEmpty) {
      return 'Invite friends · ${user.referralCode}';
    }
    return 'Member';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider.select((s) => s.user));
    final authLoading = ref.watch(authProvider.select((s) => s.isLoading));
    final isCreator = user?.role == 'creator' || user?.role == 'admin';
    final billing = ref.watch(callBillingProvider);
    final coins = shouldShowLiveUserCoins(isCreator: isCreator, billing: billing)
        ? billing.userCoins
        : (user?.coins ?? 0);
    final unread = ref.watch(
      chatUnreadCountProvider.select((a) => a.valueOrNull ?? 0),
    );
    final topInset = MediaQuery.paddingOf(context).top;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        topInset + AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _AvatarLeading(user: user),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName(user),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  profileSubtitle(user),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6B6B6B),
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Messages',
            onPressed: () => context.go('/chat-list'),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF2D2D2D),
              ),
            ),
          ),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () => context.push('/wallet'),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const GemIcon(size: 18),
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
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF2D2D2D),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarLeading extends StatelessWidget {
  final UserModel? user;

  const _AvatarLeading({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppBrandGradients.accountMenuHeaderGradient,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: AppAvatar(
        avatarAsset: user?.avatarAsset,
        size: 40,
        fallbackText: user?.username?.isNotEmpty == true
            ? user!.username![0]
            : 'U',
      ),
    );
  }
}
