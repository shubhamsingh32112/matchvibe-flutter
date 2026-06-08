import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/withdrawal_provider.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/brand_app_chrome.dart';
import '../widgets/withdrawal_balance_card.dart';
import '../widgets/withdrawal_form_card.dart';
import '../widgets/withdrawal_history_card.dart';
import '../widgets/withdrawal_how_it_works.dart';
import '../theme/withdrawal_tokens.dart';

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
  bool _useUpi = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(withdrawalProvider.notifier).loadWithdrawals();
    });
  }

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
    final user = ref.watch(authProvider.select((s) => s.user));
    final withdrawalState = ref.watch(withdrawalProvider);

    if (user?.role != 'creator' && user?.role != 'admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
      });
      return const Scaffold(body: Center(child: Text('Unauthorized')));
    }

    final coins = user?.coins ?? 0;

    ref.listen<WithdrawalState>(withdrawalProvider, (prev, next) {
      if (next.successMessage != null &&
          next.successMessage != prev?.successMessage) {
        AppToast.showSuccess(context, next.successMessage!);
        _amountController.clear();
        _nameController.clear();
        _numberController.clear();
        _upiController.clear();
        _accountNumberController.clear();
        _ifscController.clear();
        ref.read(authProvider.notifier).refreshUser();
      }
      if (next.error != null && next.error != prev?.error) {
        AppToast.showError(context, next.error!);
      }
    });

    return Scaffold(
      backgroundColor: AppBrandGradients.accountMenuPageBackground,
      appBar: buildAccountFlowAppBar(
        context,
        title: 'Withdraw',
        actions: [BrandHeaderCoinsChip(coins: coins)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WithdrawalBalanceCard(coins: coins),
            const SizedBox(height: 16),
            WithdrawalFormCard(
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
            if (withdrawalState.withdrawals.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Recent Requests',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: WithdrawalTokens.valueDark,
                ),
              ),
              const SizedBox(height: 12),
              ...withdrawalState.withdrawals.map(
                (w) => WithdrawalHistoryCard(withdrawal: w),
              ),
            ],
            const SizedBox(height: 16),
            const WithdrawalHowItWorks(),
          ],
        ),
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
          accountNumber:
              _useUpi ? null : _accountNumberController.text.trim(),
          ifsc: _useUpi ? null : _ifscController.text.trim(),
        );
  }
}
