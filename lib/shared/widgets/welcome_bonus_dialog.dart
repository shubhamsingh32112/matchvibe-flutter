import 'package:flutter/material.dart';
import 'gem_icon.dart';

/// Bottom sheet that offers 30 free coins to new users.
/// Only shown for users with `role == 'user'` and `welcomeBonusClaimed == false`.
class WelcomeBonusBottomSheet extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback? onSkip;
  final bool isLoading;

  const WelcomeBonusBottomSheet({
    super.key,
    required this.onAccept,
    this.onSkip,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.5,
        maxChildSize: 0.85,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFC107), // Amber
                Color(0xFFFF9800), // Orange
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
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
                  controller: scrollController,
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Coin icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(child: GemIcon(size: 48)),
                      ),
                      const SizedBox(height: 20),

                      // Title
                      const Text(
                        '🎉 Welcome Gift!',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Body
                      const Text(
                        'As a new user, you get 30 free coins to start making video calls with creators!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Coin amount highlight
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GemIcon(size: 28),
                            SizedBox(width: 8),
                            Text(
                              '30 Coins',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Accept button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : onAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFFF9800),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Claim My Coins! 🪙',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      if (onSkip != null) ...[
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: isLoading ? null : onSkip,
                          child: const Text(
                            'Not now',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: MediaQuery.of(context).padding.bottom),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Legacy class name for backward compatibility
/// Use WelcomeBonusBottomSheet with showModalBottomSheet instead
@Deprecated('Use WelcomeBonusBottomSheet with showModalBottomSheet instead')
class WelcomeBonusDialog extends StatelessWidget {
  final VoidCallback onAccept;
  final bool isLoading;

  const WelcomeBonusDialog({
    super.key,
    required this.onAccept,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return WelcomeBonusBottomSheet(onAccept: onAccept, isLoading: isLoading);
  }
}
