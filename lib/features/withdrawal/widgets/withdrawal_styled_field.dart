import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/withdrawal_tokens.dart';

class WithdrawalStyledField extends StatelessWidget {
  const WithdrawalStyledField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.prefixIcon,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      style: const TextStyle(
        color: WithdrawalTokens.valueDark,
        fontSize: 16,
      ),
      decoration: WithdrawalTokens.fieldDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon != null
            ? WithdrawalTokens.prefixIconCircle(prefixIcon!)
            : null,
      ),
      validator: validator,
    );
  }
}
