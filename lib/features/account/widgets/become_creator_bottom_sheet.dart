import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/brand_app_chrome.dart';
import '../../auth/providers/auth_provider.dart';
import '../../support/providers/support_provider.dart';

/// Account tab: interest in the creator program — copy, optional notes, WhatsApp via dialog.
class BecomeCreatorBottomSheet extends ConsumerStatefulWidget {
  const BecomeCreatorBottomSheet({super.key});

  @override
  ConsumerState<BecomeCreatorBottomSheet> createState() =>
      _BecomeCreatorBottomSheetState();
}

class _BecomeCreatorBottomSheetState
    extends ConsumerState<BecomeCreatorBottomSheet> {
  final _detailsController = TextEditingController();

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  bool _looksLikeWhatsapp(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 8 && digits.length <= 15;
  }

  Future<void> _submitInterest(String whatsapp) async {
    final details = _detailsController.text.trim();
    final user = ref.read(authProvider).user;
    final buffer = StringBuffer()
      ..writeln('Creator program interest')
      ..writeln('WhatsApp: $whatsapp')
      ..writeln('User id: ${user?.id ?? "unknown"}');
    if (details.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Additional details:')
        ..writeln(details);
    }

    final ok = await ref.read(supportProvider.notifier).createTicket(
          category: 'general',
          subject: 'Become a Creator — contact me',
          message: buffer.toString(),
          priority: 'medium',
        );
    if (!mounted) return;
    if (ok) {
      AppToast.showSuccess(
        context,
        'Thanks! The MatchVibe team will reach out soon.',
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _onShareWhatsappTap() async {
    final whatsapp = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _WhatsappNumberDialog(),
    );
    if (!mounted || whatsapp == null) return;
    final trimmed = whatsapp.trim();
    if (trimmed.isEmpty) {
      AppToast.showInfo(context, 'Please enter your WhatsApp number.');
      return;
    }
    if (!_looksLikeWhatsapp(trimmed)) {
      AppToast.showInfo(
        context,
        'Enter a valid number with country code (8–15 digits).',
      );
      return;
    }
    await _submitInterest(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    ref.listen<SupportState>(supportProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        AppToast.showError(context, next.error!);
      }
    });

    return DraggableScrollableSheet(
      initialChildSize: 0.52,
      minChildSize: 0.38,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: ColoredBox(
            color: AppBrandGradients.accountMenuPageBackground,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const BrandSheetHeader(title: 'Become a Creator'),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        Text(
                          'Want to become a creator on MatchVibe?',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1A1A1A),
                                  ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Drop your details below and tap the button to share '
                          'your WhatsApp number. Our team will contact you with '
                          'next steps.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.45,
                                  ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _detailsController,
                          maxLines: 4,
                          maxLength: 800,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText:
                                'Optional: a short intro, niche, or questions',
                            hintStyle: TextStyle(
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.55),
                            ),
                            filled: true,
                            fillColor: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.35),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: scheme.outlineVariant,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: scheme.outlineVariant,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: scheme.primary,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(14),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Center(
                          child: FilledButton(
                            onPressed: ref.watch(supportProvider).isSubmitting
                                ? null
                                : _onShareWhatsappTap,
                            style: FilledButton.styleFrom(
                              backgroundColor: scheme.primary,
                              foregroundColor: scheme.onPrimary,
                              disabledBackgroundColor:
                                  scheme.surfaceContainerHighest,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 14,
                              ),
                            ),
                            child: ref.watch(supportProvider).isSubmitting
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: scheme.onPrimary,
                                    ),
                                  )
                                : const Text(
                                    'Share WhatsApp number',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
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
      },
    );
  }
}

class _WhatsappNumberDialog extends StatefulWidget {
  const _WhatsappNumberDialog();

  @override
  State<_WhatsappNumberDialog> createState() => _WhatsappNumberDialogState();
}

class _WhatsappNumberDialogState extends State<_WhatsappNumberDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: scheme.surface,
      title: Text(
        'WhatsApp number',
        style: TextStyle(color: scheme.onSurface),
      ),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.phone,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Include country code, e.g. +1 555 123 4567',
          hintStyle: TextStyle(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
          ),
          filled: true,
          fillColor:
              scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.primary, width: 2),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop<String>(_controller.text.trim()),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
