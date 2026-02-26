import 'package:flutter_riverpod/flutter_riverpod.dart';

class CallFeedbackPrompt {
  final String callId;
  final String? creatorLookupId;
  final String? creatorFirebaseUid;
  final String? creatorName;

  const CallFeedbackPrompt({
    required this.callId,
    this.creatorLookupId,
    this.creatorFirebaseUid,
    this.creatorName,
  });
}

class CallFeedbackPromptNotifier extends StateNotifier<CallFeedbackPrompt?> {
  CallFeedbackPromptNotifier() : super(null);

  void enqueue(CallFeedbackPrompt prompt) {
    state = prompt;
  }

  void clear() {
    state = null;
  }
}

final callFeedbackPromptProvider =
    StateNotifierProvider<CallFeedbackPromptNotifier, CallFeedbackPrompt?>(
  (ref) => CallFeedbackPromptNotifier(),
);
