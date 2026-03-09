import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/utils/error_handler.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (_) => FocusNode(),
  );
  bool _isLoading = false;
  bool _canResend = false;
  int _resendCountdown = 60;
  late String _currentVerificationId;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _startResendCountdown();
    // Auto-focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }
  

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendCountdown() {
    _canResend = false;
    _resendCountdown = 60;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) {
        return false;
      }
      
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) {
          _canResend = true;
        }
      });
      
      return _resendCountdown > 0;
    });
  }

  void _onCodeChanged(int index, String value) {
    debugPrint('🔢 [OTP] Code changed at index $index: $value');
    
    if (value.length == 1) {
      // Move to next field
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Last field filled, verify OTP
        _focusNodes[index].unfocus();
        _verifyOtp();
      }
    } else if (value.isEmpty && index > 0) {
      // Move to previous field on backspace
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _onPaste(String value) {
    debugPrint('📋 [OTP] Pasted value: $value');
    
    // Only take first 6 digits (safe against short/empty strings)
    final rawDigits = value.replaceAll(RegExp(r'[^0-9]'), '');
    final digits = rawDigits.length > 6 ? rawDigits.substring(0, 6) : rawDigits;
    
    for (int i = 0; i < digits.length && i < 6; i++) {
      _controllers[i].text = digits[i];
    }
    
    // Focus last filled field
    final lastIndex = digits.isEmpty ? -1 : digits.length - 1;
    if (lastIndex >= 0) {
      _focusNodes[lastIndex].requestFocus();
    }
    
    // If 6 digits pasted, verify
    if (digits.length == 6) {
      _verifyOtp();
    }
  }

  Future<void> _verifyOtp() async {
    // Prevent multiple simultaneous verification attempts
    if (_isVerifying || _isLoading) {
      debugPrint('⚠️  [OTP] Verification already in progress');
      return;
    }

    final otp = _controllers.map((c) => c.text).join();
    
    if (otp.length != 6) {
      debugPrint('⚠️  [OTP] Invalid OTP length: ${otp.length}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter the complete 6-digit code'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
      return;
    }

    debugPrint('✅ [OTP] Verifying OTP: $otp');
    setState(() {
      _isLoading = true;
      _isVerifying = true;
    });

    try {
      await ref.read(authProvider.notifier).verifyOtp(
            _currentVerificationId,
            otp,
          );

      // Wait a moment for auth state to update
      await Future.delayed(const Duration(milliseconds: 500));
      
      final authState = ref.read(authProvider);
      
      if (authState.error != null && !authState.isAuthenticated) {
        debugPrint('❌ [OTP] Verification failed: ${authState.error}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ErrorHandler.getHumanReadableError(authState.error!)),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        // Clear OTP fields on error
        for (var controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      } else if (authState.isAuthenticated && mounted) {
        debugPrint('✅ [OTP] Verification successful, navigating to home');
        // Clear OTP fields
        for (var controller in _controllers) {
          controller.clear();
        }
        context.go('/home');
        return;
      }
    } catch (e) {
      debugPrint('❌ [OTP] Verification error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        // Clear OTP fields on error
        for (var controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    debugPrint('🔄 [OTP] Resending verification code...');
    
    setState(() {
      _canResend = false;
      _isLoading = true;
    });

    // Clear OTP fields
    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();

    try {
      await ref.read(authProvider.notifier).signInWithPhone(widget.phoneNumber);
      
      final authState = ref.read(authProvider);
      if (authState.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getHumanReadableError(authState.error!)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else if (authState.verificationId != null && mounted) {
        // Update verification ID if we got a new one
        setState(() {
          _currentVerificationId = authState.verificationId!;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Verification code resent successfully'),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          ),
        );
        _startResendCountdown();
      }
    } catch (e) {
      debugPrint('❌ [OTP] Resend error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend code: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes to auto-navigate on success
    // ref.listen MUST be called directly in build() method
    ref.listen(authProvider, (previous, next) {
      if (next.isAuthenticated && mounted && previous?.isAuthenticated != true) {
        debugPrint('✅ [OTP] Auth state changed - user authenticated');
        debugPrint('   👤 Gender: ${next.user?.gender ?? "Not set"}');
        
        // Check if user has completed onboarding (has gender)
        if (next.user?.gender == null || next.user!.gender!.isEmpty) {
          debugPrint('   🎯 Navigating to gender selection screen...');
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              context.go('/gender');
            }
          });
        } else {
          debugPrint('   🏠 Navigating to home screen...');
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              context.go('/home');
            }
          });
        }
      }
    });
    
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Verify Phone Number'),
      ),
      padded: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.sms_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .scale(delay: 200.ms),
            const SizedBox(height: 24),
            Text(
              'Enter Verification Code',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            )
                .animate()
                .fadeIn(delay: 300.ms),
            const SizedBox(height: 8),
            Text(
              'We sent a 6-digit code to\n${widget.phoneNumber}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            )
                .animate()
                .fadeIn(delay: 400.ms),
            const SizedBox(height: 48),

            // OTP Input Fields
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 45,
                  height: 60,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      // If user pastes the whole OTP into any field, spread it across fields.
                      if (value.length > 1) {
                        _onPaste(value);
                        return;
                      }
                      _onCodeChanged(index, value);
                    },
                    onTap: () {
                      // Select all text when tapped
                      _controllers[index].selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _controllers[index].text.length,
                      );
                    },
                  ),
                )
                    .animate(delay: (index * 50).ms)
                    .fadeIn()
                    .scale(begin: const Offset(0.8, 0.8));
              }),
            ),

            const SizedBox(height: 32),

            // Verify Button
            PrimaryButton(
              label: 'Verify',
              onPressed: _isLoading ? null : _verifyOtp,
              isLoading: _isLoading,
            )
                .animate()
                .fadeIn(delay: 600.ms),

            const SizedBox(height: 24),

            // Resend Code
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Didn't receive the code? ",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (_canResend)
                  TextButton(
                    onPressed: _isLoading ? null : _resendCode,
                    child: const Text('Resend'),
                  )
                else
                  Text(
                    'Resend in ${_resendCountdown}s',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            )
                .animate()
                .fadeIn(delay: 700.ms),

            const SizedBox(height: 16),

            // Change Phone Number
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      debugPrint('🔄 [OTP] User wants to change phone number');
                      // Clear verification state
                      ref.read(authProvider.notifier).clearVerificationState();
                      context.pop();
                    },
              child: const Text('Change Phone Number'),
            )
                .animate()
                .fadeIn(delay: 800.ms),
            const SizedBox(height: 24), // Extra bottom padding for keyboard
          ],
        ),
      ),
    );
  }
}
