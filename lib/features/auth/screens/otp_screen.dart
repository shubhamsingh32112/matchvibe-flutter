import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../../../shared/widgets/app_toast.dart';
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
      AppToast.showInfo(context, 'Please enter the complete 6-digit code');
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
          AppToast.showError(
            context,
            ErrorHandler.getHumanReadableError(authState.error!),
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
        AppToast.showError(
          context,
          UserMessageMapper.userMessageFor(
            e,
            fallback: 'Verification failed. Please try again.',
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
        AppToast.showError(
          context,
          ErrorHandler.getHumanReadableError(authState.error!),
        );
      } else if (authState.verificationId != null && mounted) {
        // Update verification ID if we got a new one
        setState(() {
          _currentVerificationId = authState.verificationId!;
        });
        
        AppToast.showSuccess(context, 'Verification code resent successfully');
        _startResendCountdown();
      }
    } catch (e) {
      debugPrint('❌ [OTP] Resend error: $e');
      if (mounted) {
        AppToast.showError(
          context,
          UserMessageMapper.userMessageFor(
            e,
            fallback: 'Couldn\'t resend the code. Please try again.',
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
    
    const otpOnDark = Color(0xFF1A1A1A);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Verify Phone Number',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.92),
                const Color(0xFF1C1024),
                Colors.black.withValues(alpha: 0.98),
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.sms_outlined,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.9),
                  )
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .scale(delay: 200.ms),
                  const SizedBox(height: 24),
                  Text(
                    'Enter Verification Code',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                    textAlign: TextAlign.center,
                  )
                      .animate()
                      .fadeIn(delay: 300.ms),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a 6-digit code to\n${widget.phoneNumber}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
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
                          style:
                              Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: otpOnDark,
                                  ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.94),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF7C4DFF),
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            if (value.length > 1) {
                              _onPaste(value);
                              return;
                            }
                            _onCodeChanged(index, value);
                          },
                          onTap: () {
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

                  Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: Colors.white.withValues(alpha: 0.94),
                        onPrimary: otpOnDark,
                      ),
                      elevatedButtonTheme: ElevatedButtonThemeData(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.94),
                          foregroundColor: otpOnDark,
                          disabledBackgroundColor:
                              Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    child: PrimaryButton(
                      label: 'Verify',
                      onPressed: _isLoading ? null : _verifyOtp,
                      isLoading: _isLoading,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 600.ms),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Didn't receive the code? ",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                      ),
                      if (_canResend)
                        TextButton(
                          onPressed: _isLoading ? null : _resendCode,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Resend'),
                        )
                      else
                        Text(
                          'Resend in ${_resendCountdown}s',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                        ),
                    ],
                  )
                      .animate()
                      .fadeIn(delay: 700.ms),

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            debugPrint(
                                '🔄 [OTP] User wants to change phone number');
                            ref
                                .read(authProvider.notifier)
                                .clearVerificationState();
                            context.pop();
                          },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.85),
                    ),
                    child: const Text('Change Phone Number'),
                  )
                      .animate()
                      .fadeIn(delay: 800.ms),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
