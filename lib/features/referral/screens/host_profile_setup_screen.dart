import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/image_upload_service.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/brand_app_chrome.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/host_onboarding_service.dart';

class HostProfileSetupScreen extends ConsumerStatefulWidget {
  const HostProfileSetupScreen({super.key});

  @override
  ConsumerState<HostProfileSetupScreen> createState() =>
      _HostProfileSetupScreenState();
}

class _HostProfileSetupScreenState extends ConsumerState<HostProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  final _hostOnboarding = HostOnboardingService();
  final _picker = ImagePicker();

  final Set<String> _selectedCategories = {};
  Uint8List? _photoBytes;
  String? _photoFileName;
  bool _submitting = false;

  static const _categories = [
    'Trauma',
    'Health',
    'Breakup',
    'Low confidence',
    'Loneliness',
    'Stress',
    'Work',
    'Family',
    'Relationship',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photoBytes = bytes;
      _photoFileName = picked.name;
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final about = _aboutController.text.trim();
    if (name.length < 2) {
      AppToast.showError(context, 'Display name must be at least 2 characters');
      return;
    }
    if (about.length < 10) {
      AppToast.showError(context, 'About must be at least 10 characters');
      return;
    }
    if (_photoBytes == null) {
      AppToast.showError(context, 'Please add a profile photo');
      return;
    }

    setState(() => _submitting = true);
    try {
      final upload = await ImageUploadService.uploadAvatar(
        bytes: _photoBytes!,
        purpose: ImageUploadPurpose.creatorAvatar,
        fileName: _photoFileName,
        draftSlot: 'host-profile-setup',
      );

      await _hostOnboarding.completeHostProfile(
        name: name,
        about: about,
        avatarUploadSessionId: upload.sessionId,
        categories: _selectedCategories.toList(),
      );

      await ref.read(authProvider.notifier).refreshUser();
      if (!mounted) return;
      AppToast.showSuccess(context, 'Your host profile is live');
      context.go('/home');
    } on HostOnboardingException catch (e) {
      if (mounted) AppToast.showError(context, e.message);
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, 'Could not save profile. Try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      padded: false,
      appBar: buildBrandAppBar(
        context,
        title: 'Complete host profile',
        automaticallyImplyLeading: false,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'You\'ve been approved as a host. Add your profile details to go live.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _aboutController,
              decoration: const InputDecoration(
                labelText: 'About you',
                hintText: 'Tell listeners what you offer (min 10 characters)',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            Text('Profile photo', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_photoBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _photoBytes!,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_outline),
                  ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _pickPhoto,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose photo'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Topics (optional)', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final selected = _selectedCategories.contains(cat);
                return FilterChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: _submitting
                      ? null
                      : (v) {
                          setState(() {
                            if (v) {
                              if (_selectedCategories.length < 4) {
                                _selectedCategories.add(cat);
                              }
                            } else {
                              _selectedCategories.remove(cat);
                            }
                          });
                        },
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: LoadingIndicator(size: 22),
                    )
                  : const Text('Go live as host'),
            ),
          ],
        ),
      ),
    );
  }
}
