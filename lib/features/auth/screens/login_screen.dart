import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// Phone login commented out - using Google Sign-In only
// import 'package:intl_phone_field/intl_phone_field.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _acceptTerms = true;
  final _referralController = TextEditingController();
  final _referralFocusNode = FocusNode();

  @override
  void dispose() {
    _referralController.dispose();
    _referralFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleFastLogin() async {
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('🖱️  [UI] Fast Login button pressed');
    debugPrint('═══════════════════════════════════════════════════════');

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the terms and conditions')),
      );
      return;
    }

    final refCode = _referralController.text.trim();
    if (refCode.isNotEmpty && refCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Referral code must be 6 characters (e.g. JO4832)')),
      );
      return;
    }

    ref.read(authProvider.notifier).setPendingReferralCode(refCode.isEmpty ? null : refCode);
    await ref.read(authProvider.notifier).signInWithFastLogin();
  }

  Future<void> _handleGoogleLogin() async {
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('🖱️  [UI] Google Sign-In button pressed');
    debugPrint('═══════════════════════════════════════════════════════');

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the terms and conditions')),
      );
      return;
    }

    final refCode = _referralController.text.trim();
    if (refCode.isNotEmpty && refCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Referral code must be 6 characters (e.g. JO4832)')),
      );
      return;
    }

    ref.read(authProvider.notifier).setPendingReferralCode(refCode.isEmpty ? null : refCode);
    await ref.read(authProvider.notifier).signInWithGoogle();
  }

  /// Show network error dialog with retry option
  void _showNetworkErrorDialog(BuildContext context, String errorMessage) {
    final scheme = Theme.of(context).colorScheme;
    final isNoRouteToHost = errorMessage.toLowerCase().contains('no route to host') ||
        errorMessage.toLowerCase().contains('errno: 113');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.wifi_off, color: scheme.error),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Network Error'),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (kDebugMode && isNoRouteToHost) ...[
                Text(
                  'Backend server is not reachable. Check backend URL and network.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
              ],
              Text(
                kDebugMode ? 'Check backend connectivity and try again.' : 'Please check your connection and try again.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(authProvider.notifier).clearError();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(authProvider.notifier).clearError();
              final currentState = ref.read(authProvider);
              if (currentState.firebaseUser != null) {
                ref.read(authProvider.notifier).syncUserToBackend();
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    ref.listen(authProvider, (previous, next) {
      // Navigate to home or gender selection when authenticated (Google Sign-In)
      if (next.isAuthenticated && mounted && previous?.isAuthenticated != true) {
        debugPrint('✅ [UI] User authenticated, navigating...');
        if (next.user?.gender == null || next.user!.gender!.isEmpty) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) context.go('/gender');
          });
        } else {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) context.go('/home');
          });
        }
      }
      if (next.error != null && mounted && !next.isLoading && previous?.error != next.error) {
        final errorMessage = next.error!;
        if (errorMessage.toLowerCase().contains('network') ||
            errorMessage.toLowerCase().contains('connection') ||
            errorMessage.toLowerCase().contains('no route to host')) {
          _showNetworkErrorDialog(context, errorMessage);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ErrorHandler.getHumanReadableError(errorMessage)),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    });

    return AppScaffold(
      padded: true,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Login to get started',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Sign in with Fast Login or Google to continue.',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              // Referral code (optional)
              TextField(
                controller: _referralController,
                focusNode: _referralFocusNode,
                decoration: InputDecoration(
                  labelText: 'Referral Code (optional)',
                  hintText: 'e.g. JO4832',
                  hintStyle: TextStyle(color: scheme.onSurfaceVariant.withOpacity(0.6)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: scheme.outline),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                onChanged: (v) {
                  if (v.length <= 6) {
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              // Fast Login (primary — one tap, no account picker)
              OutlinedButton.icon(
                onPressed: (authState.isLoading || !_acceptTerms) ? null : _handleFastLogin,
                icon: authState.isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.primary,
                        ),
                      )
                    : Icon(Icons.flash_on, size: 24, color: scheme.primary),
                label: Text(
                  authState.isLoading ? 'Signing in...' : 'Continue with Fast Login',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  side: BorderSide(color: scheme.outline),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Google Sign-In
              OutlinedButton.icon(
                onPressed: (authState.isLoading || !_acceptTerms) ? null : _handleGoogleLogin,
                icon: Icon(Icons.g_mobiledata, size: 28, color: scheme.primary),
                label: Text(
                  'Continue with Google',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  side: BorderSide(color: scheme.outline),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _acceptTerms,
                    onChanged: (value) {
                      setState(() => _acceptTerms = value ?? false);
                    },
                    activeColor: scheme.primary,
                    checkColor: scheme.onPrimary,
                    side: BorderSide(color: scheme.outlineVariant, width: 2),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: RichText(
                        text: TextSpan(
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(text: 'I accept '),
                            TextSpan(
                              text: 'terms & conditions',
                              style: TextStyle(decoration: TextDecoration.underline, color: scheme.primary),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'community guidelines',
                              style: TextStyle(decoration: TextDecoration.underline, color: scheme.primary),
                            ),
                            const TextSpan(text: ' of Match Vibe.'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
