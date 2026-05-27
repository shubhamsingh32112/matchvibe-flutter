import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/main_layout.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/brand_app_chrome.dart';
import '../../auth/providers/auth_provider.dart';
import '../../support/providers/support_provider.dart';
import '../../video/providers/call_billing_provider.dart';
import '../../video/providers/call_billing_selectors.dart';
import '../utils/creator_whatsapp_launcher.dart';
import '../widgets/become_creator_hero_banner.dart';
import '../widgets/become_creator_how_it_works.dart';
import '../widgets/become_creator_trust_bar.dart';
import '../widgets/become_creator_whatsapp_cta.dart';
import '../widgets/whatsapp_number_dialog.dart';

class BecomeCreatorScreen extends ConsumerStatefulWidget {
  const BecomeCreatorScreen({super.key});

  @override
  ConsumerState<BecomeCreatorScreen> createState() =>
      _BecomeCreatorScreenState();
}

class _BecomeCreatorScreenState extends ConsumerState<BecomeCreatorScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _redirectIfNotEligible(),
    );
  }

  void _redirectIfNotEligible() {
    if (!mounted) return;
    final user = ref.read(authProvider).user;
    final isCreator = user?.role == 'creator' || user?.role == 'admin';
    if (isCreator) {
      context.go('/home');
    }
  }

  Future<void> _onApplyOnWhatsapp() async {
    final whatsapp = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const WhatsappNumberDialog(),
    );
    if (!mounted || whatsapp == null) return;

    final trimmed = whatsapp.trim();
    if (trimmed.isEmpty) {
      AppToast.showInfo(context, 'Please enter your WhatsApp number.');
      return;
    }
    if (!looksLikeWhatsappNumber(trimmed)) {
      AppToast.showInfo(
        context,
        'Enter a valid number with country code (8–15 digits).',
      );
      return;
    }

    final user = ref.read(authProvider).user;
    final buffer = StringBuffer()
      ..writeln('Creator program interest')
      ..writeln('WhatsApp: $trimmed')
      ..writeln('User id: ${user?.id ?? "unknown"}');

    final ok = await ref
        .read(supportProvider.notifier)
        .createTicket(
          category: 'general',
          subject: 'Become a Creator — contact me',
          message: buffer.toString(),
          priority: 'medium',
        );
    if (!mounted) return;

    if (!ok) return;

    final launched = await CreatorWhatsappLauncher.launchApplyChat(
      userWhatsapp: trimmed,
      userId: user?.id ?? 'unknown',
    );

    if (!mounted) return;

    if (launched) {
      AppToast.showSuccess(
        context,
        'Thanks! Opening WhatsApp — our team will guide you.',
      );
      context.pop();
      return;
    }

    if (AppConstants.creatorWhatsappNumber.isEmpty) {
      AppToast.showSuccess(
        context,
        'Thanks! Your request was submitted. Our team will reach out soon.',
      );
    } else {
      AppToast.showSuccess(
        context,
        'Request submitted. Could not open WhatsApp — our team will contact you.',
      );
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider.select((s) => s.user));
    final isCreator = user?.role == 'creator' || user?.role == 'admin';
    final billing = ref.watch(callBillingProvider);
    final coins = shouldShowLiveUserCoins(isCreator: isCreator, billing: billing)
        ? billing.userCoins
        : (user?.coins ?? 0);
    final isSubmitting = ref.watch(
      supportProvider.select((s) => s.isSubmitting),
    );

    if (isCreator) {
      return const SizedBox.shrink();
    }

    ref.listen<SupportState>(supportProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        AppToast.showError(context, next.error!);
      }
    });

    return MainLayout(
      selectedIndex: 3,
      accountMenuStyle: true,
      appBar: buildAccountFlowAppBar(
        context,
        title: 'Become a Creator',
        actions: [BrandHeaderCoinsChip(coins: coins)],
      ),
      child: ColoredBox(
        color: AppBrandGradients.accountMenuPageBackground,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
            const SliverToBoxAdapter(child: BecomeCreatorHeroBanner()),
            const SliverToBoxAdapter(child: BecomeCreatorHowItWorks()),
            SliverToBoxAdapter(
              child: BecomeCreatorWhatsappCta(
                isSubmitting: isSubmitting,
                onApply: _onApplyOnWhatsapp,
              ),
            ),
            const SliverToBoxAdapter(child: BecomeCreatorTrustBar()),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ],
        ),
      ),
    );
  }
}

/// Legacy wrapper — redirects to full-screen route if still invoked.
class BecomeCreatorBottomSheet extends StatelessWidget {
  const BecomeCreatorBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.of(context).pop();
        context.push('/account/become-creator');
      }
    });
    return const SizedBox.shrink();
  }
}
