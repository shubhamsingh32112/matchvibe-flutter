import 'package:flutter/material.dart';
import '../../wallet/models/transaction_model.dart';
import '../services/support_service.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../../shared/styles/app_brand_styles.dart';

/// Bottom sheet wrapper for payment complaint
class PaymentComplaintBottomSheet extends StatelessWidget {
  final TransactionModel transaction;

  const PaymentComplaintBottomSheet({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => PaymentComplaintScreen(
        transaction: transaction,
        scrollController: scrollController,
      ),
    );
  }
}

class PaymentComplaintScreen extends StatefulWidget {
  final TransactionModel transaction;
  final ScrollController? scrollController;

  const PaymentComplaintScreen({
    super.key,
    required this.transaction,
    this.scrollController,
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
      Navigator.of(context).pop();
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

    return Container(
      decoration: BoxDecoration(
        gradient: AppBrandGradients.appBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Payment Complaint',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                controller: widget.scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
                    const SizedBox(height: 100), // Space for bottom button
                  ],
                ),
              ),
            ),
            // Bottom button
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: PrimaryButton(
                  label: 'Raise Complaint',
                  onPressed: canSubmit ? _submitComplaint : null,
                  isLoading: _isSubmitting,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
