import 'package:flutter/material.dart';

import '../theme/withdrawal_tokens.dart';

class WithdrawalSubmitButton extends StatelessWidget {
  const WithdrawalSubmitButton({
    super.key,
    required this.isSubmitting,
    required this.onPressed,
  });

  final bool isSubmitting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isSubmitting ? null : WithdrawalTokens.submitGradient,
          color: isSubmitting ? WithdrawalTokens.borderGrey : null,
          borderRadius: BorderRadius.circular(WithdrawalTokens.submitRadius),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isSubmitting ? null : onPressed,
            borderRadius: BorderRadius.circular(WithdrawalTokens.submitRadius),
            child: Center(
              child: isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Submit Withdrawal Request',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
