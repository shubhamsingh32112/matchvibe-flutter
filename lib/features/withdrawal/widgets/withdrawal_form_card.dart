import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/gem_icon.dart';
import '../theme/withdrawal_tokens.dart';
import 'withdrawal_info_strip.dart';
import 'withdrawal_method_tabs.dart';
import 'withdrawal_section_header.dart';
import 'withdrawal_styled_field.dart';
import 'withdrawal_submit_button.dart';

class WithdrawalFormCard extends StatelessWidget {
  const WithdrawalFormCard({
    super.key,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WithdrawalTokens.cardDecoration(),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WithdrawalSectionHeader(
              title: 'Request Withdrawal',
              underlineWord: 'Request',
            ),
            const SizedBox(height: 16),
            const WithdrawalInfoStrip(),
            const SizedBox(height: 20),
            WithdrawalStyledField(
              controller: amountController,
              labelText: 'Amount (coins)',
              hintText: 'Min 100 coins',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              prefixIcon: const GemIcon(size: 20),
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
            const SizedBox(height: 16),
            WithdrawalStyledField(
              controller: nameController,
              labelText: 'Name',
              hintText: 'Enter your name',
              prefixIcon: Icon(
                Icons.person_outline,
                size: 20,
                color: WithdrawalTokens.primaryPurple,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            WithdrawalStyledField(
              controller: numberController,
              labelText: 'Phone Number',
              hintText: 'Enter your phone number',
              keyboardType: TextInputType.phone,
              prefixIcon: Icon(
                Icons.phone_outlined,
                size: 20,
                color: WithdrawalTokens.primaryPurple,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Phone number is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            WithdrawalMethodTabs(
              useUpi: useUpi,
              onUseUpiChanged: onUseUpiChanged,
            ),
            const SizedBox(height: 16),
            if (useUpi)
              WithdrawalStyledField(
                controller: upiController,
                labelText: 'UPI ID',
                hintText: 'yourname@paytm',
                prefixIcon: Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: WithdrawalTokens.primaryPurple,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'UPI ID is required';
                  }
                  return null;
                },
              )
            else ...[
              WithdrawalStyledField(
                controller: accountNumberController,
                labelText: 'Account Number',
                hintText: 'Enter account number',
                keyboardType: TextInputType.number,
                prefixIcon: Icon(
                  Icons.account_balance_outlined,
                  size: 20,
                  color: WithdrawalTokens.primaryPurple,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Account number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              WithdrawalStyledField(
                controller: ifscController,
                labelText: 'IFSC Code',
                hintText: 'ABCD0123456',
                textCapitalization: TextCapitalization.characters,
                prefixIcon: Icon(
                  Icons.code_outlined,
                  size: 20,
                  color: WithdrawalTokens.primaryPurple,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'IFSC code is required';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 24),
            WithdrawalSubmitButton(
              isSubmitting: isSubmitting,
              onPressed: onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
