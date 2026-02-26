/// Model for a creator withdrawal request.
class WithdrawalRequest {
  final String id;
  final String creatorUserId;
  final double amount;
  final String status; // 'pending' | 'approved' | 'rejected' | 'paid'
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? adminUserId;
  final String? notes;

  WithdrawalRequest({
    required this.id,
    required this.creatorUserId,
    required this.amount,
    required this.status,
    required this.requestedAt,
    this.processedAt,
    this.adminUserId,
    this.notes,
  });

  factory WithdrawalRequest.fromJson(Map<String, dynamic> json) {
    return WithdrawalRequest(
      id: json['withdrawalId'] as String? ?? json['id'] as String? ?? '',
      creatorUserId: json['creatorUserId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'pending',
      requestedAt: json['requestedAt'] != null
          ? DateTime.parse(json['requestedAt'] as String)
          : DateTime.now(),
      processedAt: json['processedAt'] != null
          ? DateTime.parse(json['processedAt'] as String)
          : null,
      adminUserId: json['adminUserId'] as String?,
      notes: json['notes'] as String?,
    );
  }

  /// Human-readable status label
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'paid':
        return 'Paid';
      default:
        return status;
    }
  }

  /// Whether the withdrawal is still being processed
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isPaid => status == 'paid';
}
