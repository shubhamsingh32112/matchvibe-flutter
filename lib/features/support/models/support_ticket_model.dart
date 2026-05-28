/// Model for a support ticket.
class SupportTicketAttachment {
  final String name;
  final String mimeType;
  final int sizeBytes;
  final bool isScreenshot;
  final String? dataBase64;
  final String? dataUrl;
  final String? imageId;
  final String? url;

  SupportTicketAttachment({
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.isScreenshot,
    this.dataBase64,
    this.dataUrl,
    this.imageId,
    this.url,
  });

  String? get displayUrl {
    if (url != null && url!.isNotEmpty) return url;
    if (dataUrl != null && dataUrl!.isNotEmpty) return dataUrl;
    return null;
  }

  factory SupportTicketAttachment.fromJson(Map<String, dynamic> json) {
    final mimeType = json['mimeType'] as String? ?? 'application/octet-stream';
    final base64 = json['dataBase64'] as String?;
    return SupportTicketAttachment(
      name: json['name'] as String? ?? 'attachment',
      mimeType: mimeType,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      isScreenshot: json['isScreenshot'] as bool? ?? false,
      dataBase64: base64,
      dataUrl:
          json['dataUrl'] as String? ??
          ((base64 != null && base64.isNotEmpty)
              ? 'data:$mimeType;base64,$base64'
              : null),
      imageId: json['imageId'] as String?,
      url: json['url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      'isScreenshot': isScreenshot,
      if (dataBase64 != null) 'dataBase64': dataBase64,
      if (imageId != null) 'imageId': imageId,
      if (url != null) 'url': url,
    };
  }
}

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
  final String? contactPhone;
  final String? adminNotes;
  final String? source;
  final List<SupportTicketAttachment> attachments;
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
    this.contactPhone,
    this.adminNotes,
    this.source,
    this.attachments = const [],
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
      contactPhone: json['contactPhone'] as String?,
      adminNotes: json['adminNotes'] as String?,
      source: json['source'] as String?,
      attachments: ((json['attachments'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => SupportTicketAttachment.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString())
          : DateTime.now(),
    );
  }

  SupportTicket copyWith({
    String? status,
    String? adminNotes,
    DateTime? updatedAt,
  }) {
    return SupportTicket(
      id: id,
      userId: userId,
      role: role,
      category: category,
      subject: subject,
      message: message,
      status: status ?? this.status,
      priority: priority,
      assignedAdminId: assignedAdminId,
      contactPhone: contactPhone,
      adminNotes: adminNotes ?? this.adminNotes,
      source: source,
      attachments: attachments,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
      case 'urgent':
        return 'Urgent';
      default:
        return priority;
    }
  }

  bool get isOpen => status == 'open';
  bool get isInProgress => status == 'in_progress';
  bool get isResolved => status == 'resolved';
  bool get isClosed => status == 'closed';

  bool get hasAdminReply =>
      adminNotes != null && adminNotes!.trim().isNotEmpty;
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
