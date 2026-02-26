import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/providers/auth_provider.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  static const List<String> _reasons = [
    'Other',
    'Asked for money',
    'Not Interested',
    'Buddy not polite',
    'Abusive Language',
    'Unable to hear',
  ];

  final ApiClient _apiClient = ApiClient();
  final TextEditingController _noteController = TextEditingController();
  final Set<String> _selectedReasons = {};
  bool _isSubmitting = false;
  bool _expandedInfo = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _openSupportEmail() async {
    final uri = Uri.parse('mailto:support@eazeapp.in');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _deleteAccount() async {
    if (_selectedReasons.isEmpty || _isSubmitting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This action is permanent. Your account data will be removed and you will be logged out.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _apiClient.post(
        '/user/delete-account',
        data: {
          'reasons': _selectedReasons.toList(),
          'note': _noteController.text.trim(),
        },
      );

      await ref.read(authProvider.notifier).signOut();
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canDelete = _selectedReasons.isNotEmpty && !_isSubmitting;

    return AppScaffold(
      appBar: AppBar(title: const Text('Delete Account')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton(
            onPressed: canDelete ? _deleteAccount : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: canDelete ? scheme.error : scheme.outline.withOpacity(0.4),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Delete Account'),
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFB71C1C), Color(0xFF2A1B22)],
                ),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Icon(Icons.error_outline, color: Colors.white, size: 56),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Information related to account will be kept for 30 days and will be completely purged after no activity for continuous 30 days.',
                    style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  if (_expandedInfo)
                    const Text(
                      'After the account is deleted, you will no longer be able to log in or use the account, and the account cannot be recovered.',
                      style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                    ),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _expandedInfo = !_expandedInfo;
                        });
                      },
                      icon: Icon(
                        _expandedInfo ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.white,
                      ),
                      label: Text(
                        _expandedInfo ? 'View less' : 'View more',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Please select at least one reason for deleting your account',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _reasons.map((reason) {
                final selected = _selectedReasons.contains(reason);
                return FilterChip(
                  selected: selected,
                  label: Text(reason),
                  onSelected: (isSelected) {
                    setState(() {
                      if (isSelected) {
                        _selectedReasons.add(reason);
                      } else {
                        _selectedReasons.remove(reason);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            if (_selectedReasons.contains('Other')) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Tell us more (optional)',
                ),
              ),
            ],
            const SizedBox(height: 36),
            Center(
              child: TextButton(
                onPressed: _openSupportEmail,
                child: const Text('Need help? Please write to: support@eazeapp.in'),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
