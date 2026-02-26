import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  String _completePhoneNumber = ''; // Store complete number with country code (e.g., +919876543210)
  bool _acceptTerms = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('🖱️  [UI] Google sign in button pressed');
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('   ⏰ Timestamp: ${DateTime.now().toIso8601String()}');
    debugPrint('   📱 Screen: Login Screen');
    debugPrint('   🔘 Action: Google Sign In');

    final startTime = DateTime.now();
    await ref.read(authProvider.notifier).signInWithGoogle();
    final duration = DateTime.now().difference(startTime);

    debugPrint('───────────────────────────────────────────────────────');
    debugPrint('📊 [UI] Google sign in initiated');
    debugPrint('───────────────────────────────────────────────────────');
    debugPrint('   ⏱️  Sign-in call duration: ${duration.inMilliseconds}ms');
    debugPrint('   💡 Auth state listener will handle navigation');
    debugPrint('   💡 Backend sync is in progress...');
    
    // The auth state listener in initState will handle navigation
    // when authentication completes. We don't need to check here
    // because the backend sync happens asynchronously via the auth
    // state listener in auth_provider.dart
  }

  Future<void> _handlePhoneLogin() async {
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('🖱️  [UI] Phone login button pressed');
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('   ⏰ Timestamp: ${DateTime.now().toIso8601String()}');
    debugPrint('   📱 Screen: Login Screen');
    debugPrint('   🔘 Action: Phone Sign In');

    final digits = _phoneController.text.trim();

    if (digits.isEmpty) {
      debugPrint('   ❌ Phone number field is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number')),
      );
      return;
    }

    if (digits.length != 10 || !RegExp(r'^\d{10}$').hasMatch(digits)) {
      debugPrint('   ❌ Invalid phone number length: ${digits.length}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit mobile number')),
      );
      return;
    }

    if (!_acceptTerms) {
      debugPrint('   ❌ Terms and conditions not accepted');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the terms and conditions')),
      );
      return;
    }

    // Prepend +91 country code
    final phoneNumber = '+91$digits';
    debugPrint('───────────────────────────────────────────────────────');
    debugPrint('📱 [UI] Phone number entered');
    debugPrint('───────────────────────────────────────────────────────');
    debugPrint('   📞 Phone: $phoneNumber');
    debugPrint('   📏 Digits: ${digits.length}');
    debugPrint('   🔄 Calling signInWithPhone()...');

    final startTime = DateTime.now();
    await ref.read(authProvider.notifier).signInWithPhone(phoneNumber);
    final duration = DateTime.now().difference(startTime);

    debugPrint('───────────────────────────────────────────────────────');
    debugPrint('📊 [UI] Phone sign in initiated');
    debugPrint('───────────────────────────────────────────────────────');
    debugPrint('   ⏱️  Duration: ${duration.inMilliseconds}ms');
    debugPrint('   💡 Auth state listener will handle navigation when verification ID is received');
    
    // The auth state listener in build() will handle navigation
    // when verificationId is set in the state
  }

  /// Show network error dialog with retry option
  /// This error indicates OS-level network routing failure (errno 113)
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
              child: Text('Network Routing Error'),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isNoRouteToHost) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: scheme.onErrorContainer, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'OS-Level Network Routing Failure',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: scheme.onErrorContainer,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Error 113 = Phone has NO network path to backend.\n\n'
                        'This is NOT a code issue. Your phone cannot route to 192.168.1.11.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onErrorContainer,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                '🔧 FIX (Do in this exact order):',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              _buildChecklistItem(
                context,
                scheme,
                '1. FORCE Wi-Fi Only (CRITICAL)',
                'On phone:\n• Turn OFF mobile data\n• Turn ON airplane mode\n• Then manually turn Wi-Fi ON\n\nThis guarantees routing stays on LAN.',
              ),
              _buildChecklistItem(
                context,
                scheme,
                '2. Verify IP from Backend Machine',
                'On laptop:\n• Windows: ipconfig\n• Mac/Linux: ifconfig\n• Look for IPv4: 192.168.1.11\n\n⚠️ If different subnet (192.168.0.x or 10.x.x.x), update IP in app.',
              ),
              _buildChecklistItem(
                context,
                scheme,
                '3. Test in Phone Browser (REQUIRED)',
                'Open Chrome on phone:\nhttp://192.168.1.11:3000/health\n\n❌ If fails → Router/Wi-Fi issue\n✅ If works → Flutter config issue',
              ),
              _buildChecklistItem(
                context,
                scheme,
                '4. Check Router Settings',
                'Disable:\n• AP Isolation\n• Client Isolation\n• Guest Wi-Fi (use main network)\n\nGuest Wi-Fi = sandbox = no LAN access.',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: scheme.primary,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.usb, color: scheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'USB Reverse Tunnel (100% Works)',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: scheme.onPrimaryContainer,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Run on laptop:\n'
                      'adb reverse tcp:3000 tcp:3000',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Then change baseUrl to:\n'
                      'http://localhost:3000',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontFamily: 'monospace',
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '✅ If this works → Confirms router/Wi-Fi isolation issue',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: scheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Current Server Address:',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'http://192.168.1.11:3000',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.primary,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
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

  Widget _buildChecklistItem(
    BuildContext context,
    ColorScheme scheme,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: scheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                ),
              ],
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
    
    // Listen for authentication state changes to navigate automatically
    // ref.listen MUST be called directly in build() method
    ref.listen(authProvider, (previous, next) {
      // Navigate to OTP screen when verification ID is received
      if (next.verificationId != null && 
          previous?.verificationId != next.verificationId && 
          next.phoneNumber != null &&
          mounted) {
        debugPrint('───────────────────────────────────────────────────────');
        debugPrint('✅ [UI] Auth state listener: Verification ID received');
        debugPrint('───────────────────────────────────────────────────────');
        debugPrint('   🆔 Verification ID: ${next.verificationId}');
        debugPrint('   📱 Phone: ${next.phoneNumber}');
        debugPrint('   🧭 Navigating to OTP screen...');
        context.push(
          '/otp?phone=${Uri.encodeComponent(next.phoneNumber!)}&verificationId=${Uri.encodeComponent(next.verificationId!)}',
        );
        debugPrint('   ✅ Navigation completed');
      }
      // Navigate to home or gender selection when authenticated
      else if (next.isAuthenticated && mounted && previous?.isAuthenticated != true) {
        debugPrint('───────────────────────────────────────────────────────');
        debugPrint('✅ [UI] Auth state listener: User authenticated');
        debugPrint('───────────────────────────────────────────────────────');
        debugPrint('   🆔 User ID: ${next.user?.id}');
        debugPrint('   📧 Email: ${next.user?.email ?? "N/A"}');
        debugPrint('   👤 Gender: ${next.user?.gender ?? "Not set"}');
        
        // Check if user has completed onboarding (has gender)
        if (next.user?.gender == null || next.user!.gender!.isEmpty) {
          debugPrint('   🎯 Navigating to gender selection screen...');
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              context.go('/gender');
            }
          });
        } else {
          debugPrint('   🏠 Navigating to home screen...');
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              context.go('/home');
            }
          });
        }
      } 
      // Show error messages
      else if (next.error != null && mounted && !next.isLoading && previous?.error != next.error) {
        debugPrint('───────────────────────────────────────────────────────');
        debugPrint('❌ [UI] Auth state listener: Authentication error');
        debugPrint('───────────────────────────────────────────────────────');
        debugPrint('   Error: ${next.error}');
        
        // Show network error dialog instead of snackbar for better UX
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
              IntlPhoneField(
                initialCountryCode: 'IN', // 🇮🇳 Default to India (+91)
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                disableLengthCheck: false,
                decoration: InputDecoration(
                  labelText: 'Mobile Number',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '+91',
                          style: textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 24,
                          color: scheme.outlineVariant,
                        ),
                      ],
                    ),
                  ),
                  counterText: '', // hide the "0/10" counter
                ),
                onChanged: (phone) {
                  // Store complete number with country code (e.g., +919876543210)
                  _completePhoneNumber = phone.completeNumber;
                  debugPrint('📱 Phone number changed: $_completePhoneNumber');
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'You will receive an OTP on this number.',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _acceptTerms,
                    onChanged: (value) {
                      setState(() {
                        _acceptTerms = value ?? false;
                      });
                    },
                    activeColor: scheme.primary,
                    checkColor: scheme.onPrimary,
                    side: BorderSide(
                      color: scheme.outlineVariant,
                      width: 2,
                    ),
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
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                                color: scheme.primary,
                              ),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'community guidelines',
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                                color: scheme.primary,
                              ),
                            ),
                            const TextSpan(
                              text:
                                  ' of Match Vibe. I also agree to receiving updates on WhatsApp/SMS.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Get OTP',
                onPressed: (authState.isLoading || !_acceptTerms)
                    ? null
                    : _handlePhoneLogin,
                isLoading: authState.isLoading,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: scheme.outlineVariant,
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Text(
                      'OR',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: scheme.outlineVariant,
                      thickness: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                label: 'Continue with Google',
                onPressed:
                    authState.isLoading ? null : _handleGoogleSignIn,
                leading: authState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: LoadingIndicator(size: 20),
                      )
                    : Icon(
                        Icons.g_mobiledata,
                        size: 28,
                        color: scheme.primary,
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

}
