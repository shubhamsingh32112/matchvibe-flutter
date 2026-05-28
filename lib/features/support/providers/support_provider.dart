import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../models/support_ticket_model.dart';
import '../services/support_service.dart';

final supportServiceProvider = Provider<SupportService>((ref) {
  return SupportService();
});

/// State for the support screen.
class SupportState {
  final List<SupportTicket> tickets;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;
  final String? successMessage;

  const SupportState({
    this.tickets = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
    this.successMessage,
  });

  SupportState copyWith({
    List<SupportTicket>? tickets,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return SupportState(
      tickets: tickets ?? this.tickets,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class SupportNotifier extends StateNotifier<SupportState> {
  final SupportService _service;

  SupportNotifier(this._service) : super(const SupportState());

  /// Load the user's tickets from backend.
  Future<void> loadTickets() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final tickets = await _service.getMyTickets();
      state = state.copyWith(isLoading: false, tickets: tickets);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: UserMessageMapper.userMessageFor(
          e,
          fallback: 'Couldn\'t load support tickets. Please try again.',
        ),
      );
    }
  }

  /// Merge a socket-pushed ticket update into local state.
  void applyTicketUpdate(Map<String, dynamic> payload) {
    final ticketId = payload['ticketId']?.toString();
    if (ticketId == null || ticketId.isEmpty) return;

    final updatedAtRaw = payload['updatedAt']?.toString();
    final updatedAt = updatedAtRaw != null
        ? DateTime.tryParse(updatedAtRaw) ?? DateTime.now()
        : DateTime.now();

    final idx = state.tickets.indexWhere((t) => t.id == ticketId);
    if (idx >= 0) {
      final existing = state.tickets[idx];
      final updated = existing.copyWith(
        status: payload['status']?.toString() ?? existing.status,
        adminNotes: payload['adminNotes']?.toString() ?? existing.adminNotes,
        updatedAt: updatedAt,
      );
      final next = [...state.tickets];
      next[idx] = updated;
      state = state.copyWith(tickets: next);
    }
  }

  /// Submit a new support ticket.
  Future<bool> createTicket({
    required String category,
    required String subject,
    required String message,
    required String contactPhone,
    String priority = 'medium',
    String source = 'other',
    String? relatedCallId,
    String? creatorLookupId,
    String? creatorFirebaseUid,
    List<CommittedSupportAttachment> attachmentSessions = const [],
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      final ticket = await _service.createTicket(
        category: category,
        subject: subject,
        message: message,
        contactPhone: contactPhone,
        priority: priority,
        source: source,
        relatedCallId: relatedCallId,
        creatorLookupId: creatorLookupId,
        creatorFirebaseUid: creatorFirebaseUid,
        attachmentSessions: attachmentSessions,
      );
      state = state.copyWith(
        isSubmitting: false,
        successMessage: 'Support ticket submitted!',
        tickets: [ticket, ...state.tickets],
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: UserMessageMapper.userMessageFor(
          e,
          fallback: 'Couldn\'t submit your ticket. Please try again.',
        ),
      );
      return false;
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final supportProvider = StateNotifierProvider<SupportNotifier, SupportState>((
  ref,
) {
  final service = ref.watch(supportServiceProvider);
  return SupportNotifier(service);
});
