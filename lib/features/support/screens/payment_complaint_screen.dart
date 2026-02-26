import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../wallet/models/transaction_model.dart';
import '../services/support_service.dart';
import '../../../shared/widgets/ui_primitives.dart';

class PaymentComplaintScreen extends StatefulWidget {
  final TransactionModel transaction;

  const PaymentComplaintScreen({
    super.key,
    required this.transaction,
  });

  @override
  State<PaymentComplaintScreen> createState() => _PaymentComplaintScreenState();
}

class _PaymentComplaintScreenState extends State<PaymentComplaintScreen> {
  static const List<String> _reasons = [
    'Amount debited but coins not added',
    'Duplicate charge',
    'Wrong amount charged',
    'Payment failed but money deducted',
    'Other payment issue',
  ];

  final SupportService _supportService = SupportService();
  final TextEditingController _detailsController = TextEditingController();
  String? _selectedReason;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitComplaint() async {
    if (_selectedReason == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final tx = widget.transaction;
      final details = _detailsController.text.trim();
      final subject = 'Payment issue: ${tx.transactionId.isEmpty ? tx.id : tx.transactionId}';
      final message = [
        'Reason: $_selectedReason',
        'Transaction ID: ${tx.transactionId.isEmpty ? tx.id : tx.transactionId}',
        'Amount: ${tx.amount}',
        'Type: ${tx.type}',
        'Source: ${tx.source}',
        'Status: ${tx.status}',
        if (tx.description != null && tx.description!.trim().isNotEmpty)
          'Description: ${tx.description!.trim()}',
        if (details.isNotEmpty) 'User details: $details',
      ].join('\n');

      await _supportService.createTicket(
        category: 'billing',
        subject: subject,
        message: message,
        priority: 'high',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint submitted successfully')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit complaint: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tx = widget.transaction;
    final canSubmit = _selectedReason != null && !_isSubmitting;

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Payment Complaint'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton(
            onPressed: canSubmit ? _submitComplaint : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Raise Complaint'),
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Transaction',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ID: ${tx.transactionId.isEmpty ? tx.id : tx.transactionId}',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Amount: ${tx.amount} • ${tx.type.toUpperCase()}',
                    style: TextStyle(color: scheme.onSurface),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Select a reason',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _reasons.map((reason) {
                return ChoiceChip(
                  label: Text(reason),
                  selected: _selectedReason == reason,
                  onSelected: (_) => setState(() => _selectedReason = reason),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _detailsController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Additional details (optional)',
                hintText: 'Describe what happened',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your complaint will be visible in the admin support panel.',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
