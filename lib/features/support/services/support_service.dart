import 'package:flutter/foundation.dart';
import '../../../core/api/api_client.dart';
import '../models/support_ticket_model.dart';

class SupportService {
  final ApiClient _apiClient = ApiClient();

  /// Create a new support ticket.
  Future<SupportTicket> createTicket({
    required String category,
    required String subject,
    required String message,
    String priority = 'medium',
    String source = 'other',
    String? relatedCallId,
    String? creatorLookupId,
    String? creatorFirebaseUid,
  }) async {
    try {
      debugPrint('📝 [SUPPORT] Creating ticket: $subject');
      final payload = <String, dynamic>{
        'category': category,
        'subject': subject,
        'message': message,
        'priority': priority,
        'source': source,
        if (relatedCallId != null && relatedCallId.trim().isNotEmpty)
          'relatedCallId': relatedCallId.trim(),
        if (creatorLookupId != null && creatorLookupId.trim().isNotEmpty)
          'creatorLookupId': creatorLookupId.trim(),
        if (creatorFirebaseUid != null && creatorFirebaseUid.trim().isNotEmpty)
          'creatorFirebaseUid': creatorFirebaseUid.trim(),
      };

      final response = await _apiClient.post('/support/ticket', data: payload);

      if (response.statusCode == 201 && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        final ticketJson = data['ticket'] as Map<String, dynamic>?;
        if (ticketJson != null) {
          debugPrint('✅ [SUPPORT] Ticket created: ${ticketJson['id']}');
          return SupportTicket.fromJson(ticketJson);
        }

        // Backward compatibility: backend may return flattened ticket fields.
        final normalized = <String, dynamic>{
          'id': data['ticketId'] ?? '',
          'userId': '',
          'role': data['role'] ?? 'user',
          'category': data['category'] ?? category,
          'subject': data['subject'] ?? subject,
          'message': message,
          'status': data['status'] ?? 'open',
          'priority': data['priority'] ?? priority,
          'createdAt': data['createdAt'] ?? DateTime.now().toIso8601String(),
          'updatedAt': data['createdAt'] ?? DateTime.now().toIso8601String(),
        };
        debugPrint('✅ [SUPPORT] Ticket created: ${normalized['id']}');
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
    } catch (e) {
      debugPrint('❌ [SUPPORT] Error submitting call feedback: $e');
      rethrow;
    }
  }

  /// Convenience API for reporting a creator from chat/post-call flows.
  Future<SupportTicket> reportCreator({
    required String reasonMessage,
    required String source,
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
      priority: 'high',
      source: source,
      relatedCallId: relatedCallId,
      creatorLookupId: creatorLookupId,
      creatorFirebaseUid: creatorFirebaseUid,
    );
  }
}
