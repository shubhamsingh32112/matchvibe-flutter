import 'dart:async';
import 'package:flutter/material.dart';
import 'app_toast.dart';

/// Welcome bottom sheet that appears on first app launch, first login, or after reinstall
class WelcomeBottomSheet extends StatelessWidget {
  final Future<void> Function() onAgree;
  final VoidCallback? onNotNow;

  const WelcomeBottomSheet({super.key, required this.onAgree, this.onNotNow});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) => _WelcomeBottomSheetContent(
        scrollController: scrollController,
        onAgree: onAgree,
        onNotNow: onNotNow,
      ),
    );
  }
}

class _WelcomeBottomSheetContent extends StatefulWidget {
  final ScrollController scrollController;
  final Future<void> Function() onAgree;
  final VoidCallback? onNotNow;

  const _WelcomeBottomSheetContent({
    required this.scrollController,
    required this.onAgree,
    this.onNotNow,
  });

  @override
  State<_WelcomeBottomSheetContent> createState() =>
      _WelcomeBottomSheetContentState();
}

class _WelcomeBottomSheetContentState
    extends State<_WelcomeBottomSheetContent> {
  bool _isProcessing = false;

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

    // If callback succeeded but bottom sheet is still open, close it
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        'M',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFF6B35),
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
                    description:
                        'Treat others the way you\'d like to be treated.',
                  ),
                  const SizedBox(height: 16),
                  _buildGuideline(
                    icon: Icons.shield,
                    title: 'Protect yourself',
                    description:
                        'Be cautious about sharing personal information.',
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
                        backgroundColor: const Color(
                          0xFFE8B4CB,
                        ), // Light pink/purple
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: const Color(
                          0xFFE8B4CB,
                        ).withOpacity(0.6),
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
                        onPressed: _isProcessing ? null : widget.onNotNow,
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
                  // Bottom padding for safe area
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ),
        ],
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
