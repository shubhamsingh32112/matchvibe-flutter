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
  }) {
    return SupportState(
      tickets: tickets ?? this.tickets,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      successMessage: successMessage,
    );
  }
}

class SupportNotifier extends StateNotifier<SupportState> {
  final SupportService _service;

  SupportNotifier(this._service) : super(const SupportState());

  /// Load the user's tickets from backend.
  Future<void> loadTickets() async {
    state = state.copyWith(isLoading: true, error: null);
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

  /// Submit a new support ticket.
  Future<bool> createTicket({
    required String category,
    required String subject,
    required String message,
    String priority = 'medium',
  }) async {
    state = state.copyWith(isSubmitting: true, error: null, successMessage: null);
    try {
      final ticket = await _service.createTicket(
        category: category,
        subject: subject,
        message: message,
        priority: priority,
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
    state = state.copyWith(error: null, successMessage: null);
  }
}

final supportProvider =
    StateNotifierProvider<SupportNotifier, SupportState>((ref) {
  final service = ref.watch(supportServiceProvider);
  return SupportNotifier(service);
});
