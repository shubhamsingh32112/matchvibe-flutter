import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../models/withdrawal_model.dart';
import '../services/withdrawal_service.dart';

/// Provides a singleton [WithdrawalService] instance.
final withdrawalServiceProvider = Provider<WithdrawalService>((ref) {
  return WithdrawalService();
});

/// State for the withdrawal screen.
class WithdrawalState {
  final List<WithdrawalRequest> withdrawals;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;
  final String? successMessage;

  const WithdrawalState({
    this.withdrawals = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
    this.successMessage,
  });

  WithdrawalState copyWith({
    List<WithdrawalRequest>? withdrawals,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    String? successMessage,
  }) {
    return WithdrawalState(
      withdrawals: withdrawals ?? this.withdrawals,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      successMessage: successMessage,
    );
  }
}

/// Notifier that manages withdrawal requests for creators.
class WithdrawalNotifier extends StateNotifier<WithdrawalState> {
  final WithdrawalService _service;

  WithdrawalNotifier(this._service) : super(const WithdrawalState());

  /// Submit a new withdrawal request.
  Future<bool> requestWithdrawal({
    required int amount,
    required String name,
    required String number,
    String? upi,
    String? accountNumber,
    String? ifsc,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null, successMessage: null);
    try {
      final withdrawal = await _service.requestWithdrawal(
        amount: amount,
        name: name,
        number: number,
        upi: upi,
        accountNumber: accountNumber,
        ifsc: ifsc,
      );
      state = state.copyWith(
        isSubmitting: false,
        successMessage: 'Withdrawal of ${withdrawal.amount.toInt()} coins submitted!',
        withdrawals: [withdrawal, ...state.withdrawals],
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: UserMessageMapper.userMessageFor(
          e,
          fallback: 'Couldn\'t submit withdrawal. Please try again.',
        ),
      );
      return false;
    }
  }

  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

final withdrawalProvider =
    StateNotifierProvider<WithdrawalNotifier, WithdrawalState>((ref) {
  final service = ref.watch(withdrawalServiceProvider);
  return WithdrawalNotifier(service);
});
