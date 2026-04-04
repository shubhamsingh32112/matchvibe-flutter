import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/withdrawal_provider.dart';
import '../models/withdrawal_model.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../../shared/widgets/gem_icon.dart';
import '../../../shared/styles/app_brand_styles.dart';

class WithdrawalScreen extends ConsumerStatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  ConsumerState<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends ConsumerState<WithdrawalScreen> {
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _upiController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _useUpi = true; // Toggle between UPI and Bank Account

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _numberController.dispose();
    _upiController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final withdrawalState = ref.watch(withdrawalProvider);

    // Role guard — only creators
    if (user?.role != 'creator' && user?.role != 'admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
      });
      return const Scaffold(body: Center(child: Text('Unauthorized')));
    }

    final coins = user?.coins ?? 0;

    // Listen for success/error messages
    ref.listen<WithdrawalState>(withdrawalProvider, (prev, next) {
      if (next.successMessage != null && next.successMessage != prev?.successMessage) {
        AppToast.showSuccess(context, next.successMessage!);
        // Clear all form fields
        _amountController.clear();
        _nameController.clear();
        _numberController.clear();
        _upiController.clear();
        _accountNumberController.clear();
        _ifscController.clear();
        // Refresh user data to update balance
        ref.read(authProvider.notifier).refreshUser();
      }
      if (next.error != null && next.error != prev?.error) {
        AppToast.showError(context, next.error!);
      }
    });

    return AppScaffold(
      padded: false,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Withdraw',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _CoinsPill(coins: coins),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Balance Card
                  _BalanceCard(coins: coins),
                  const SizedBox(height: 20),

                  // Withdrawal Form
                  _WithdrawalForm(
                    formKey: _formKey,
                    amountController: _amountController,
                    nameController: _nameController,
                    numberController: _numberController,
                    upiController: _upiController,
                    accountNumberController: _accountNumberController,
                    ifscController: _ifscController,
                    useUpi: _useUpi,
                    onUseUpiChanged: (value) => setState(() => _useUpi = value),
                    availableBalance: coins,
                    isSubmitting: withdrawalState.isSubmitting,
                    onSubmit: _submitWithdrawal,
                  ),
                  const SizedBox(height: 24),

                  // Withdrawal History (in-session)
                  if (withdrawalState.withdrawals.isNotEmpty) ...[
                    Text(
                      'Recent Requests',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...withdrawalState.withdrawals.map(
                      (w) => _WithdrawalHistoryCard(withdrawal: w),
                    ),
                  ],

                  // Info section
                  const SizedBox(height: 16),
                  _InfoSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;

    await ref.read(withdrawalProvider.notifier).requestWithdrawal(
      amount: amount,
      name: _nameController.text.trim(),
      number: _numberController.text.trim(),
      upi: _useUpi ? _upiController.text.trim() : null,
      accountNumber: _useUpi ? null : _accountNumberController.text.trim(),
      ifsc: _useUpi ? null : _ifscController.text.trim(),
    );
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final int coins;
  const _BalanceCard({required this.coins});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Balance',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppBrandGradients.walletCoinGold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$coins',
                  style: const TextStyle(
                    color: AppBrandGradients.walletOnGold,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'coins',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WithdrawalForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController amountController;
  final TextEditingController nameController;
  final TextEditingController numberController;
  final TextEditingController upiController;
  final TextEditingController accountNumberController;
  final TextEditingController ifscController;
  final bool useUpi;
  final ValueChanged<bool> onUseUpiChanged;
  final int availableBalance;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _WithdrawalForm({
    required this.formKey,
    required this.amountController,
    required this.nameController,
    required this.numberController,
    required this.upiController,
    required this.accountNumberController,
    required this.ifscController,
    required this.useUpi,
    required this.onUseUpiChanged,
    required this.availableBalance,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request Withdrawal',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(color: scheme.onSurface, fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Amount (coins)',
                labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                hintText: 'Min 100 coins',
                hintStyle: TextStyle(color: scheme.onSurfaceVariant.withOpacity(0.5)),
                prefixIcon: GemIcon(size: 24, color: scheme.primary),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: scheme.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: scheme.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: scheme.error, width: 2),
                ),
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withOpacity(0.3),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = int.tryParse(value.trim());
                if (amount == null || amount <= 0) {
                  return 'Enter a valid amount';
                }
                if (amount < 100) {
                  return 'Minimum withdrawal is 100 coins';
                }
                if (amount > availableBalance) {
                  return 'Exceeds available balance ($availableBalance coins)';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            // Name field
            TextFormField(
              controller: nameController,
              style: TextStyle(color: scheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                prefixIcon: Icon(Icons.person_outline, color: scheme.primary),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: scheme.primary, width: 2),
                ),
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withOpacity(0.3),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Phone number field
            TextFormField(
              controller: numberController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: scheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Phone Number',
                labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                prefixIcon: Icon(Icons.phone_outlined, color: scheme.primary),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: scheme.primary, width: 2),
                ),
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withOpacity(0.3),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Phone number is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            // Payment method toggle
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('UPI'),
                    selected: useUpi,
                    onSelected: onUseUpiChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Bank Account'),
                    selected: !useUpi,
                    onSelected: (selected) => onUseUpiChanged(!selected),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // UPI or Bank Account fields
            if (useUpi) ...[
              TextFormField(
                controller: upiController,
                style: TextStyle(color: scheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'UPI ID',
                  labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                  hintText: 'yourname@paytm',
                  prefixIcon: Icon(Icons.account_circle_outlined, color: scheme.primary),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: scheme.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest.withOpacity(0.3),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'UPI ID is required';
                  }
                  return null;
                },
              ),
            ] else ...[
              TextFormField(
                controller: accountNumberController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: scheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Account Number',
                  labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                  prefixIcon: Icon(Icons.account_balance_outlined, color: scheme.primary),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: scheme.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest.withOpacity(0.3),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Account number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: ifscController,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(color: scheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'IFSC Code',
                  labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                  hintText: 'ABCD0123456',
                  prefixIcon: Icon(Icons.code_outlined, color: scheme.primary),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: scheme.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest.withOpacity(0.3),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'IFSC code is required';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  disabledBackgroundColor: scheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Submit Withdrawal Request',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WithdrawalHistoryCard extends StatelessWidget {
  final WithdrawalRequest withdrawal;
  const _WithdrawalHistoryCard({required this.withdrawal});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Color statusColor;
    IconData statusIcon;
    switch (withdrawal.status) {
      case 'pending':
        statusColor = Colors.amber;
        statusIcon = Icons.hourglass_top;
        break;
      case 'approved':
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'rejected':
        statusColor = scheme.error;
        statusIcon = Icons.cancel_outlined;
        break;
      case 'paid':
        statusColor = Colors.green;
        statusIcon = Icons.paid_outlined;
        break;
      default:
        statusColor = scheme.onSurfaceVariant;
        statusIcon = Icons.help_outline;
    }

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${withdrawal.amount.toInt()} coins',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(withdrawal.requestedAt),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              withdrawal.statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}, '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: scheme.onSurfaceVariant, size: 18),
              const SizedBox(width: 8),
              Text(
                'How withdrawals work',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.looks_one_outlined, text: 'Minimum withdrawal: 100 coins'),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.looks_two_outlined, text: 'Submit your request — coins stay in your wallet'),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.looks_3_outlined, text: 'Admin reviews & approves (coins deducted)'),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.looks_4_outlined, text: 'Payment processed & marked as paid'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _CoinsPill extends StatelessWidget {
  final int coins;
  const _CoinsPill({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: AppBrandGradients.walletCoinGold,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GemIcon(
            size: 16,
            color: AppBrandGradients.walletOnGold,
          ),
          const SizedBox(width: 4),
          Text(
            '$coins',
            style: const TextStyle(
              color: AppBrandGradients.walletOnGold,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
