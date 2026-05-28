import 'package:flutter/foundation.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/meta_app_events_service.dart';
import '../models/support_ticket_model.dart';

class CommittedSupportAttachment {
  const CommittedSupportAttachment({
    required this.sessionId,
    required this.name,
    this.isScreenshot = false,
  });

  final String sessionId;
  final String name;
  final bool isScreenshot;
}

class SupportService {
  final ApiClient _apiClient = ApiClient();

  /// Commit Cloudflare upload sessions into support attachment refs.
  Future<List<SupportTicketAttachment>> commitSupportAttachments({
    required List<CommittedSupportAttachment> sessions,
  }) async {
    if (sessions.isEmpty) return [];
    final response = await _apiClient.post(
      '/support/attachments/commit',
      data: {
        'sessionIds': sessions.map((s) => s.sessionId).toList(),
        'sessionMeta': sessions
            .map(
              (s) => {
                'sessionId': s.sessionId,
                'name': s.name,
                'isScreenshot': s.isScreenshot,
              },
            )
            .toList(),
      },
    );
    if (response.statusCode != 200 || response.data['success'] != true) {
      throw Exception(response.data['error'] ?? 'Failed to upload attachments');
    }
    final list = response.data['data']['attachments'] as List<dynamic>? ?? [];
    return list
        .whereType<Map>()
        .map(
          (item) => SupportTicketAttachment.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  /// Create a new support ticket.
  Future<SupportTicket> createTicket({
    required String category,
    required String subject,
    required String message,
    required String contactPhone,
    String priority = 'medium',
    String source = 'other',
    String? relatedCallId,
    String? creatorLookupId,
    String? creatorFirebaseUid,
    List<String> attachmentSessionIds = const [],
    List<CommittedSupportAttachment> attachmentSessions = const [],
  }) async {
    try {
      debugPrint('📝 [SUPPORT] Creating ticket: $subject');
      final sessionIds = attachmentSessionIds.isNotEmpty
          ? attachmentSessionIds
          : attachmentSessions.map((s) => s.sessionId).toList();
      final sessionMeta = attachmentSessions
          .map(
            (s) => {
              'sessionId': s.sessionId,
              'name': s.name,
              'isScreenshot': s.isScreenshot,
            },
          )
          .toList();

      final payload = <String, dynamic>{
        'category': category,
        'subject': subject,
        'message': message,
        'contactPhone': contactPhone.trim(),
        'priority': priority,
        'source': source,
        if (relatedCallId != null && relatedCallId.trim().isNotEmpty)
          'relatedCallId': relatedCallId.trim(),
        if (creatorLookupId != null && creatorLookupId.trim().isNotEmpty)
          'creatorLookupId': creatorLookupId.trim(),
        if (creatorFirebaseUid != null && creatorFirebaseUid.trim().isNotEmpty)
          'creatorFirebaseUid': creatorFirebaseUid.trim(),
        if (sessionIds.isNotEmpty) 'attachmentSessionIds': sessionIds,
        if (sessionMeta.isNotEmpty) 'attachmentSessionMeta': sessionMeta,
      };

      final response = await _apiClient.post('/support/ticket', data: payload);

      if (response.statusCode == 201 && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        final ticketJson = data['ticket'] as Map<String, dynamic>?;
        if (ticketJson != null) {
          debugPrint('✅ [SUPPORT] Ticket created: ${ticketJson['id']}');
          await MetaAppEventsService.logContact();
          return SupportTicket.fromJson(ticketJson);
        }

        final normalized = <String, dynamic>{
          'id': data['ticketId'] ?? data['id'] ?? '',
          'userId': data['userId'] ?? '',
          'role': data['role'] ?? 'user',
          'category': data['category'] ?? category,
          'subject': data['subject'] ?? subject,
          'message': data['message'] ?? message,
          'contactPhone': data['contactPhone'] ?? contactPhone,
          'attachments': data['attachments'] ?? const [],
          'status': data['status'] ?? 'open',
          'priority': data['priority'] ?? priority,
          'adminNotes': data['adminNotes'],
          'createdAt': data['createdAt'] ?? DateTime.now().toIso8601String(),
          'updatedAt': data['updatedAt'] ??
              data['createdAt'] ??
              DateTime.now().toIso8601String(),
        };
        debugPrint('✅ [SUPPORT] Ticket created: ${normalized['id']}');
        await MetaAppEventsService.logContact();
        return SupportTicket.fromJson(normalized);
      } else {
        final error = response.data['error'] ?? 'Unknown error';
        throw Exception(error);
      }
    } catch (e) {
      debugPrint('❌ [SUPPORT] Error creating ticket: $e');
      rethrow;
    }
  }

  /// Get my support tickets.
  Future<List<SupportTicket>> getMyTickets() async {
    try {
      debugPrint('📋 [SUPPORT] Fetching my tickets...');
      final response = await _apiClient.get('/support/my-tickets');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final ticketsJson = response.data['data']['tickets'] as List<dynamic>;
        final tickets = ticketsJson
            .map((t) => SupportTicket.fromJson(t as Map<String, dynamic>))
            .toList();
        debugPrint('✅ [SUPPORT] Fetched ${tickets.length} tickets');
        return tickets;
      } else {
        throw Exception(response.data['error'] ?? 'Failed to fetch tickets');
      }
    } catch (e) {
      debugPrint('❌ [SUPPORT] Error fetching tickets: $e');
      rethrow;
    }
  }

  /// Submit post-call 1-5 star feedback for a creator call.
  Future<void> submitCallFeedback({
    required String callId,
    required int rating,
    String? comment,
  }) async {
    try {
      debugPrint('⭐ [SUPPORT] Submitting call feedback for call: $callId');
      await _apiClient.post(
        '/support/call-feedback',
        data: {
          'callId': callId,
          'rating': rating,
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
        },
      );
      debugPrint('✅ [SUPPORT] Call feedback submitted');
      await MetaAppEventsService.logRated(rating: rating);
    } catch (e) {
      debugPrint('❌ [SUPPORT] Error submitting call feedback: $e');
      rethrow;
    }
  }

  /// Convenience API for reporting a creator from chat/post-call flows.
  Future<SupportTicket> reportCreator({
    required String reasonMessage,
    required String source,
    required String contactPhone,
    String? creatorLookupId,
    String? creatorFirebaseUid,
    String? creatorName,
    String? relatedCallId,
  }) {
    final trimmedReason = reasonMessage.trim();
    final displayName = (creatorName ?? '').trim();

    final messageLines = <String>[
      if (displayName.isNotEmpty) 'Reported creator: $displayName',
      'Reason: $trimmedReason',
    ];

    return createTicket(
      category: 'abuse',
      subject: displayName.isNotEmpty
          ? 'Creator report: $displayName'
          : 'Creator report',
      message: messageLines.join('\n'),
      contactPhone: contactPhone,
      priority: 'high',
      source: source,
      relatedCallId: relatedCallId,
      creatorLookupId: creatorLookupId,
      creatorFirebaseUid: creatorFirebaseUid,
    );
  }
}
