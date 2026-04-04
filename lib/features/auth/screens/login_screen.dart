import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/loader_bg_wordmark_cover.dart';
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

  void _showPhoneLoginSheet() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    String? phoneValue;
    var isSending = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Continue with Phone Number',
                      style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your phone number. We\'ll send you a verification code.',
                      style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 20),
                    IntlPhoneField(
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      initialCountryCode: 'IN',
                      enabled: !isSending,
                      onChanged: (phone) {
                        phoneValue = phone.completeNumber;
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: isSending
                          ? null
                          : () async {
                              final phone = phoneValue?.trim();
                              if (phone == null || phone.isEmpty) {
                                AppToast.showInfo(
                                  sheetContext,
                                  'Please enter your phone number',
                                );
                                return;
                              }
                              if (!_acceptTerms) {
                                AppToast.showInfo(
                                  sheetContext,
                                  'Please accept the terms and conditions',
                                );
                                return;
                              }
                              final refCode = _referralController.text.trim();
                              if (refCode.isNotEmpty && refCode.length != 6) {
                                AppToast.showInfo(
                                  sheetContext,
                                  'Referral code must be 6 characters (e.g. JO4832)',
                                );
                                return;
                              }

                              setModalState(() => isSending = true);
                              ref.read(authProvider.notifier).setPendingReferralCode(
                                    refCode.isEmpty ? null : refCode,
                                  );
                              await ref.read(authProvider.notifier).signInWithPhone(phone);

                              if (!sheetContext.mounted) return;
                              final s = ref.read(authProvider);
                              if (s.error != null) {
                                setModalState(() => isSending = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isSending
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send Code'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _handleGoogleLogin() async {
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('🖱️  [UI] Google Sign-In button pressed');
    debugPrint('═══════════════════════════════════════════════════════');

    if (!_acceptTerms) {
      AppToast.showInfo(context, 'Please accept the terms and conditions');
      return;
    }

    final refCode = _referralController.text.trim();
    if (refCode.isNotEmpty && refCode.length != 6) {
      AppToast.showInfo(
        context,
        'Referral code must be 6 characters (e.g. JO4832)',
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

  bool _isLoginBusy(AuthState authState) {
    return authState.isLoading ||
        (authState.firebaseUser != null &&
            authState.user == null &&
            authState.error == null);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isLoginBusy = _isLoginBusy(authState);
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.6;

    ref.listen(authProvider, (previous, next) {
      if (next.verificationId != null &&
          next.phoneNumber != null &&
          !next.isLoading &&
          mounted &&
          previous?.verificationId != next.verificationId) {
        debugPrint('✅ [UI] OTP sent, navigating to OTP screen...');
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!context.mounted) return;
          final nav = Navigator.of(context);
          if (nav.canPop()) {
            nav.pop();
          }
          context.push('/otp', extra: {
            'phoneNumber': next.phoneNumber!,
            'verificationId': next.verificationId!,
          });
        });
      }
      if (next.isAuthenticated && mounted && previous?.isAuthenticated != true) {
        debugPrint('✅ [UI] User authenticated, navigating...');
        if (next.user?.gender == null || next.user!.gender!.isEmpty) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!context.mounted) return;
            context.go('/gender');
          });
        } else {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!context.mounted) return;
            context.go('/home');
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
          AppToast.showError(
            context,
            ErrorHandler.getHumanReadableError(errorMessage),
            duration: const Duration(seconds: 5),
          );
        }
      }
    });

    Widget authButtonContent({
      required bool busy,
      required Widget icon,
      required String label,
      required String busyLabel,
    }) {
      if (!busy) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      }
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              busyLabel,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    final sheetBody = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + viewInsetsBottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  AppConstants.appLogoAsset,
                  height: 56,
                  fit: BoxFit.contain,
                  semanticLabel: AppConstants.appName,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Login to get started',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Sign in with Google or your phone number to continue.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _referralController,
                  focusNode: _referralFocusNode,
                  enabled: !isLoginBusy,
                  decoration: InputDecoration(
                    labelText: 'Referral Code (optional)',
                    hintText: 'e.g. JO4832',
                    hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
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
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(
                  onPressed: (isLoginBusy || !_acceptTerms) ? null : _handleGoogleLogin,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                    side: BorderSide(color: scheme.outline),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: authButtonContent(
                    busy: isLoginBusy,
                    icon: Icon(Icons.g_mobiledata, size: 28, color: scheme.primary),
                    label: 'Continue with Google',
                    busyLabel: 'Signing in…',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: (isLoginBusy || !_acceptTerms) ? null : _showPhoneLoginSheet,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                    side: BorderSide(color: scheme.outline),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: authButtonContent(
                    busy: isLoginBusy,
                    icon: Icon(Icons.phone_android, size: 24, color: scheme.primary),
                    label: 'Continue with Phone Number',
                    busyLabel: 'Signing in…',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _acceptTerms,
                      onChanged: isLoginBusy
                          ? null
                          : (value) {
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
              ],
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(AppConstants.loaderBackgroundAsset),
                fit: BoxFit.cover,
              ),
            ),
            child: SizedBox.expand(),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.12),
                  Colors.black.withValues(alpha: 0.28),
                ],
              ),
            ),
            child: const SizedBox.expand(),
          ),
          const Positioned.fill(
            child: LoaderBgWordmarkCover(),
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: sheetHeight,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Material(
                    color: scheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isLoginBusy)
                          LinearProgressIndicator(
                            minHeight: 2,
                            backgroundColor: scheme.surfaceContainerHighest,
                            color: scheme.primary,
                          ),
                        Expanded(child: sheetBody),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
