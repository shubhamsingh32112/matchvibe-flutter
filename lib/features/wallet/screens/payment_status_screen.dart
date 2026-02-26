import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/ui_primitives.dart';

class PaymentStatusScreen extends StatelessWidget {
  final bool isSuccess;
  final int coinsAdded;
  final String? message;

  const PaymentStatusScreen({
    super.key,
    required this.isSuccess,
    this.coinsAdded = 0,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = isSuccess ? 'Payment Successful' : 'Payment Failed';
    final subtitle = message ??
        (isSuccess
            ? (coinsAdded > 0
                ? '$coinsAdded coins were added to your wallet.'
                : 'Your wallet is updated.')
            : 'Your payment was not completed. You can try again.');

    return AppScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 70,
                  color: isSuccess ? Colors.greenAccent : scheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 15,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Go to Wallet',
                  onPressed: () => context.go('/wallet'),
                ),
                const SizedBox(height: 10),
                SecondaryButton(
                  label: 'Go to Home',
                  onPressed: () => context.go('/home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
