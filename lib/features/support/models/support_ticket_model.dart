/// Model for a support ticket.
class SupportTicket {
  final String id;
  final String userId;
  final String role; // 'user' | 'creator'
  final String category;
  final String subject;
  final String message;
  final String status; // 'open' | 'in_progress' | 'resolved' | 'closed'
  final String priority; // 'low' | 'medium' | 'high'
  final String? assignedAdminId;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupportTicket({
    required this.id,
    required this.userId,
    required this.role,
    required this.category,
    required this.subject,
    required this.message,
    required this.status,
    required this.priority,
    this.assignedAdminId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      category: json['category'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      priority: json['priority'] as String? ?? 'medium',
      assignedAdminId: json['assignedAdminId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'open':
        return 'Open';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }

  String get priorityLabel {
    switch (priority) {
      case 'low':
        return 'Low';
      case 'medium':
        return 'Medium';
      case 'high':
        return 'High';
      default:
        return priority;
    }
  }

  bool get isOpen => status == 'open';
  bool get isInProgress => status == 'in_progress';
  bool get isResolved => status == 'resolved';
  bool get isClosed => status == 'closed';
}

/// Available support categories for the dropdown.
const List<String> supportCategories = [
  'billing',
  'technical',
  'account',
  'abuse',
  'general',
];

/// Human-readable labels for support categories.
String categoryLabel(String category) {
  switch (category) {
    case 'billing':
      return 'Billing & Payments';
    case 'technical':
      return 'Technical Issue';
    case 'account':
      return 'Account & Profile';
    case 'abuse':
      return 'Report Abuse';
    case 'general':
      return 'General Inquiry';
    default:
      return category;
  }
}
