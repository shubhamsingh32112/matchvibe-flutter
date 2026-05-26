import 'package:flutter/material.dart';

class WhatsappNumberDialog extends StatefulWidget {
  const WhatsappNumberDialog({super.key});

  @override
  State<WhatsappNumberDialog> createState() => _WhatsappNumberDialogState();
}

class _WhatsappNumberDialogState extends State<WhatsappNumberDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: scheme.surface,
      title: Text(
        'WhatsApp number',
        style: TextStyle(color: scheme.onSurface),
      ),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.phone,
        autofocus: true,
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop<String>(_controller.text.trim()),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
