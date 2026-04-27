import 'dart:async';
import 'package:flutter/material.dart';
import 'app_toast.dart';

/// Welcome modal content (shown during onboarding).
class WelcomeBottomSheet extends StatelessWidget {
  final Future<void> Function() onAgree;
  final Future<void> Function()? onNotNow;
  final VoidCallback? onPresented;

  const WelcomeBottomSheet({
    super.key,
    required this.onAgree,
    this.onNotNow,
    this.onPresented,
  });

  @override
  Widget build(BuildContext context) {
    return _WelcomeModalContent(
      onAgree: onAgree,
      onNotNow: onNotNow,
      onPresented: onPresented,
    );
  }
}

class _WelcomeModalContent extends StatefulWidget {
  final Future<void> Function() onAgree;
  final Future<void> Function()? onNotNow;
  final VoidCallback? onPresented;

  const _WelcomeModalContent({
    required this.onAgree,
    this.onNotNow,
    this.onPresented,
  });

  @override
  State<_WelcomeModalContent> createState() =>
      _WelcomeBottomSheetContentState();
}

class _WelcomeBottomSheetContentState
    extends State<_WelcomeModalContent> {
  bool _isProcessing = false;
  bool _presentedFired = false;

  @override
  void initState() {
    super.initState();
    if (widget.onPresented != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _presentedFired) return;
        _presentedFired = true;
        widget.onPresented?.call();
      });
    }
  }

  Future<void> _handleAgree() async {
    // ✅ TASK 2: Prevent double-clicks and ensure button always works
    if (_isProcessing) {
      debugPrint('⏭️  [WELCOME] Button already processing, ignoring click');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // ✅ TASK 2: Add timeout to prevent infinite waiting (scalable for 1000 users/day)
      // Call the onAgree callback with timeout protection
      await widget.onAgree().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint(
            '⚠️  [WELCOME] onAgree callback timed out after 5 seconds',
          );
          throw TimeoutException(
            'Operation timed out',
            const Duration(seconds: 5),
          );
        },
      );

      debugPrint('✅ [WELCOME] onAgree callback completed successfully');
    } catch (e) {
      debugPrint('❌ [WELCOME] Error in onAgree callback: $e');

      // ✅ TASK 2: Always reset processing state on error to prevent stuck button
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        // Show user-friendly error message
        AppToast.showErrorWithAction(
          context,
          'Something went wrong. Please try again.',
          actionLabel: 'Retry',
          onAction: _handleAgree,
          duration: const Duration(seconds: 3),
        );
      }
      return;
    }

    // ✅ TASK 2: Ensure button state is reset even if callback succeeds
    // This prevents any edge cases where button might stay disabled
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }

    // Do not pop here: [onAgree] (e.g. home onboarding) already dismisses the
    // modal sheet. A second pop can remove the underlying route and break flow.
  }

  Future<void> _handleNotNow() async {
    if (widget.onNotNow == null) return;
    if (_isProcessing) {
      debugPrint('⏭️  [WELCOME] Not now ignored while processing');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await widget.onNotNow!().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint(
            '⚠️  [WELCOME] onNotNow callback timed out after 5 seconds',
          );
          throw TimeoutException(
            'Operation timed out',
            const Duration(seconds: 5),
          );
        },
      );
      debugPrint('✅ [WELCOME] onNotNow callback completed successfully');
    } catch (e) {
      debugPrint('❌ [WELCOME] Error in onNotNow callback: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        AppToast.showErrorWithAction(
          context,
          'Something went wrong. Please try again.',
          actionLabel: 'Retry',
          onAction: _handleNotNow,
          duration: const Duration(seconds: 3),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFF6B35), // Bright orange
            const Color(0xFFC1121F), // Deep red
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            // Allow scroll on small screens while keeping dialog reasonably sized.
            maxHeight: MediaQuery.of(context).size.height * 0.82,
            minWidth: 280,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'M',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF6B35),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                const Text(
                  'Welcome to Match Vibe',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                const Text(
                  'We aim to create a safe and respectful environment for everyone.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Guidelines
                _buildGuideline(
                  icon: Icons.handshake,
                  title: 'Stay respectful',
                  description: 'Treat others the way you\'d like to be treated.',
                ),
                const SizedBox(height: 16),
                _buildGuideline(
                  icon: Icons.shield,
                  title: 'Protect yourself',
                  description: 'Be cautious about sharing personal information.',
                ),
                const SizedBox(height: 16),
                _buildGuideline(
                  icon: Icons.campaign,
                  title: 'Take action',
                  description: 'Always report inappropriate behaviour.',
                ),
                const SizedBox(height: 24),

                // Agreement text
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(
                        text:
                            'By using Match Vibe, you\'re agreeing to adhere to our values as well as our ',
                      ),
                      TextSpan(
                        text: 'guidelines',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      TextSpan(text: '.'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // I agree button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _handleAgree,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8B4CB), // Light pink/purple
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      disabledBackgroundColor:
                          const Color(0xFFE8B4CB).withOpacity(0.6),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'I agree',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                if (widget.onNotNow != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _isProcessing ? null : _handleNotNow,
                      child: const Text(
                        'Not now',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                // Bottom padding for safe area (esp. gesture nav).
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuideline({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Legacy class name for backward compatibility
/// Use WelcomeBottomSheet instead
@Deprecated('Use WelcomeBottomSheet with showModalBottomSheet instead')
class WelcomeDialog extends StatelessWidget {
  final Future<void> Function() onAgree;

  const WelcomeDialog({super.key, required this.onAgree});

  @override
  Widget build(BuildContext context) {
    return WelcomeBottomSheet(onAgree: onAgree);
  }
}
