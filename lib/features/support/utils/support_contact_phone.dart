import 'package:flutter/material.dart';

/// E.164-style phone validation for support tickets.
bool isValidSupportContactPhone(String raw) {
  final trimmed = raw.trim();
  if (!trimmed.startsWith('+')) return false;
  if (trimmed.length > 20) return false;
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 10;
}

String? supportContactPhoneValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Phone number is required';
  }
  if (!isValidSupportContactPhone(value)) {
    return 'Include country code (e.g. +91 98765 43210)';
  }
  return null;
}

/// Shows a dialog to collect contact phone; returns normalized trimmed value or null.
Future<String?> collectSupportContactPhone(
  BuildContext context, {
  String? initialValue,
}) async {
  final controller = TextEditingController(text: initialValue?.trim() ?? '');
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        backgroundColor: scheme.surface,
        title: Text(
          'Contact phone',
          style: TextStyle(color: scheme.onSurface),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            autofocus: true,
            validator: supportContactPhoneValidator,
            decoration: InputDecoration(
              hintText: 'Include country code, e.g. +91 98765 43210',
              hintStyle: TextStyle(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
              ),
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: scheme.primary, width: 2),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.of(dialogContext).pop(controller.text.trim());
            },
            child: const Text('Continue'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}
