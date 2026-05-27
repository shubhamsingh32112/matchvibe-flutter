import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/widgets/main_layout.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/brand_app_chrome.dart';
import '../../../shared/widgets/decorative_asset_image.dart';
import '../../account/constants/help_support_assets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../video/providers/call_billing_provider.dart';
import '../models/support_ticket_model.dart';
import '../providers/support_provider.dart';
import '../services/support_service.dart';

/// Legacy wrapper — redirects to full-screen route if still invoked.
class SupportBottomSheet extends StatelessWidget {
  const SupportBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.of(context).pop();
        context.push('/support');
      }
    });
    return const SizedBox.shrink();
  }
}

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  static const int _maxSubjectLength = 200;
  static const int _maxMessageLength = 1000;
  static const int _maxAttachments = 4;
  static const int _maxAttachmentBytes = 1500000;

  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _selectedCategory = 'billing';
  String _selectedPriority = 'medium';
  final List<_SupportAttachmentDraft> _attachments =
      <_SupportAttachmentDraft>[];
  _SupportAttachmentDraft? _screenshotAttachment;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supportState = ref.watch(supportProvider);
    final user = ref.watch(authProvider.select((s) => s.user));
    final isCreator = user?.role == 'creator' || user?.role == 'admin';
    final billingSlice = ref.watch(
      callBillingProvider.select((b) => (b.isActive, b.userCoins)),
    );
    final coins = billingSlice.$1 && !isCreator
        ? billingSlice.$2
        : (user?.coins ?? 0);
    final scheme = Theme.of(context).colorScheme;

    ref.listen<SupportState>(supportProvider, (prev, next) {
      if (next.successMessage != null &&
          next.successMessage != prev?.successMessage) {
        AppToast.showSuccess(context, next.successMessage!);
      }
      if (next.error != null && next.error != prev?.error) {
        AppToast.showError(context, next.error!);
      }
    });

    return MainLayout(
      selectedIndex: 3,
      accountMenuStyle: true,
      appBar: buildAccountFlowAppBar(
        context,
        title: 'Support',
        actions: [BrandHeaderCoinsChip(coins: coins)],
      ),
      child: ColoredBox(
        color: AppBrandGradients.accountMenuPageBackground,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderCard(context),
                  const SizedBox(height: 16),
                  _buildSection(
                    context: context,
                    title: 'Category',
                    child: _buildCategoryField(context),
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    context: context,
                    title: 'Priority',
                    child: _buildPrioritySelector(context),
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    context: context,
                    title: 'Subject',
                    child: TextFormField(
                      controller: _subjectController,
                      maxLength: _maxSubjectLength,
                      decoration: _inputDecoration(
                        scheme,
                        hint: 'Brief summary of your issue',
                        icon: Icons.edit_outlined,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Subject is required';
                        }
                        if (value.trim().length < 3) {
                          return 'Subject should be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    context: context,
                    title: 'Describe your issue',
                    child: TextFormField(
                      controller: _messageController,
                      maxLength: _maxMessageLength,
                      maxLines: 6,
                      minLines: 4,
                      decoration: _inputDecoration(
                        scheme,
                        hint: 'Please provide as much detail as possible...',
                        icon: Icons.chat_bubble_outline,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Description is required';
                        }
                        if (value.trim().length < 10) {
                          return 'Description should be at least 10 characters';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    context: context,
                    title: 'Attachments',
                    subtitle: 'Optional',
                    child: _buildAttachmentPicker(context),
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    context: context,
                    title: 'Add Screenshot',
                    subtitle: 'Optional',
                    child: _buildScreenshotPicker(context),
                  ),
                  const SizedBox(height: 16),
                  _buildSubmitButton(
                    context: context,
                    isSubmitting: supportState.isSubmitting,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppBrandGradients.accountMenuCardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create New Ticket',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E1A36),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'We\'re here to help you',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF655F7B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const SizedBox(
            width: 94,
            height: 94,
            child: DecorativeAssetImage(
              assetPath: HelpSupportAssets.headsetHero,
              width: 94,
              height: 94,
              fallbackIcon: Icons.headset_mic_outlined,
              fallbackIconSize: 54,
              fallbackIconColor: Color(0x996A1B9A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9E2F2)),
        boxShadow: AppBrandGradients.accountMenuCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2A2543),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF8E86A3),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildCategoryField(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      dropdownColor: scheme.surface,
      decoration: _inputDecoration(
        scheme,
        hint: 'Select category',
        icon: Icons.receipt_long_outlined,
      ),
      items: supportCategories
          .map(
            (category) => DropdownMenuItem<String>(
              value: category,
              child: Text(categoryLabel(category)),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedCategory = value);
        }
      },
    );
  }

  Widget _buildPrioritySelector(BuildContext context) {
    final options = <String>['low', 'medium', 'high'];
    return Row(
      children: options
          .map(
            (option) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _PriorityChip(
                  label: option[0].toUpperCase() + option.substring(1),
                  keyName: option,
                  isSelected: _selectedPriority == option,
                  onTap: () => setState(() => _selectedPriority = option),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildAttachmentPicker(BuildContext context) {
    final canAddMore = _attachments.length < _maxAttachments;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: canAddMore ? _pickAttachments : null,
          child: Ink(
            height: 110,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFFF8F4FC),
              border: Border.all(color: const Color(0xFFD4C3EA), width: 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  color: canAddMore
                      ? const Color(0xFF7C4DFF)
                      : const Color(0xFFB6A9CA),
                  size: 30,
                ),
                const SizedBox(height: 8),
                Text(
                  canAddMore
                      ? 'Tap to upload images'
                      : 'Attachment limit reached',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3E365C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_attachments.length}/$_maxAttachments selected',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7E7597),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_attachments.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _attachments
                .map(
                  (attachment) => _AttachmentPreviewTile(
                    draft: attachment,
                    onRemove: () =>
                        setState(() => _attachments.remove(attachment)),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildScreenshotPicker(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _pickScreenshot,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFFF8F4FC),
          border: Border.all(color: const Color(0xFFE2D7F0)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 2,
          ),
          leading: const Icon(
            Icons.photo_library_outlined,
            color: Color(0xFF7C4DFF),
          ),
          title: Text(
            _screenshotAttachment == null
                ? 'Take Screenshot'
                : _screenshotAttachment!.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF2F2949),
            ),
          ),
          subtitle: _screenshotAttachment == null
              ? const Text('Upload from gallery')
              : Text('${(_screenshotAttachment!.sizeBytes / 1024).ceil()} KB'),
          trailing: _screenshotAttachment == null
              ? const Icon(Icons.chevron_right_rounded)
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() => _screenshotAttachment = null),
                ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton({
    required BuildContext context,
    required bool isSubmitting,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6F2DFF), Color(0xFFFF0B8A)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppBrandGradients.accountMenuCardShadow,
      ),
      child: ElevatedButton.icon(
        onPressed: isSubmitting ? null : _submitTicket,
        icon: isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send_rounded),
        label: const Text(
          'Submit Ticket',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    ColorScheme scheme, {
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF7C4DFF)),
      counterStyle: const TextStyle(fontSize: 11),
      filled: true,
      fillColor: const Color(0xFFF6F3FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2D7F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error, width: 1.6),
      ),
    );
  }

  Future<void> _pickAttachments() async {
    final remainingSlots = _maxAttachments - _attachments.length;
    if (remainingSlots <= 0) {
      AppToast.showInfo(
        context,
        'You can upload up to $_maxAttachments files.',
      );
      return;
    }
    final picked = await _picker.pickMultiImage(
      limit: remainingSlots,
      maxWidth: 1400,
      maxHeight: 1400,
      imageQuality: 82,
    );
    if (picked.isEmpty) return;

    for (final file in picked) {
      if (_attachments.length >= _maxAttachments) break;
      final draft = await _draftFromFile(file, isScreenshot: false);
      if (draft == null) continue;
      setState(() => _attachments.add(draft));
    }
  }

  Future<void> _pickScreenshot() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 82,
    );
    if (file == null) return;
    final draft = await _draftFromFile(file, isScreenshot: true);
    if (draft == null) return;
    setState(() => _screenshotAttachment = draft);
  }

  Future<_SupportAttachmentDraft?> _draftFromFile(
    XFile file, {
    required bool isScreenshot,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    if (bytes.length > _maxAttachmentBytes) {
      if (!mounted) return null;
      AppToast.showInfo(
        context,
        '${file.name} is too large. Max allowed is 1.5 MB.',
      );
      return null;
    }
    final mimeType = _resolveMimeType(file);
    return _SupportAttachmentDraft(
      name: file.name,
      mimeType: mimeType,
      sizeBytes: bytes.length,
      dataBase64: base64Encode(bytes),
      bytes: bytes,
      isScreenshot: isScreenshot,
    );
  }

  String _resolveMimeType(XFile file) {
    final mimeType = file.mimeType;
    if (mimeType != null && mimeType.isNotEmpty) return mimeType;
    final lower = file.name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    final payloadAttachments = <SupportTicketAttachmentPayload>[
      ..._attachments.map(
        (attachment) => SupportTicketAttachmentPayload(
          name: attachment.name,
          mimeType: attachment.mimeType,
          sizeBytes: attachment.sizeBytes,
          dataBase64: attachment.dataBase64,
          isScreenshot: attachment.isScreenshot,
        ),
      ),
      if (_screenshotAttachment != null)
        SupportTicketAttachmentPayload(
          name: _screenshotAttachment!.name,
          mimeType: _screenshotAttachment!.mimeType,
          sizeBytes: _screenshotAttachment!.sizeBytes,
          dataBase64: _screenshotAttachment!.dataBase64,
          isScreenshot: true,
        ),
    ];

    final success = await ref
        .read(supportProvider.notifier)
        .createTicket(
          category: _selectedCategory,
          subject: _subjectController.text.trim(),
          message: _messageController.text.trim(),
          priority: _selectedPriority,
          attachments: payloadAttachments,
        );

    if (!success) return;

    _subjectController.clear();
    _messageController.clear();
    setState(() {
      _selectedCategory = 'billing';
      _selectedPriority = 'medium';
      _attachments.clear();
      _screenshotAttachment = null;
    });
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({
    required this.label,
    required this.keyName,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String keyName;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const lowColor = Color(0xFF2296F3);
    const mediumColor = Color(0xFFF8B100);
    const highColor = Color(0xFFE93357);
    final color = switch (keyName) {
      'low' => lowColor,
      'high' => highColor,
      _ => mediumColor,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isSelected ? 0.12 : 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.25),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF2D2745),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle, size: 16, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttachmentPreviewTile extends StatelessWidget {
  const _AttachmentPreviewTile({required this.draft, required this.onRemove});

  final _SupportAttachmentDraft draft;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD9CCE9)),
            image: DecorationImage(
              image: MemoryImage(draft.bytes),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.cancel_rounded),
            color: const Color(0xFF6A5A84),
          ),
        ),
      ],
    );
  }
}

class _SupportAttachmentDraft {
  const _SupportAttachmentDraft({
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.dataBase64,
    required this.bytes,
    required this.isScreenshot,
  });

  final String name;
  final String mimeType;
  final int sizeBytes;
  final String dataBase64;
  final Uint8List bytes;
  final bool isScreenshot;
}
