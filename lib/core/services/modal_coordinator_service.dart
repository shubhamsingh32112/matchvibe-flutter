import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppModalPriority { critical, high, normal, low }

int _priorityRank(AppModalPriority priority) {
  switch (priority) {
    case AppModalPriority.critical:
      return 0;
    case AppModalPriority.high:
      return 1;
    case AppModalPriority.normal:
      return 2;
    case AppModalPriority.low:
      return 3;
  }
}

typedef ModalPresenter<T> =
    Future<T?> Function(BuildContext context, WidgetRef ref);

class AppModalRequest<T> {
  final String id;
  final AppModalPriority priority;
  final String? dedupeKey;
  final ModalPresenter<T> present;
  final void Function(T? result)? onCompleted;

  const AppModalRequest({
    required this.id,
    required this.priority,
    required this.present,
    this.dedupeKey,
    this.onCompleted,
  });
}

class ModalCoordinatorState {
  final List<AppModalRequest<dynamic>> queue;
  final bool isPresenting;
  final Set<String> activeDedupeKeys;
  final bool onboardingInProgress;
  final int queueTransitions;
  final int presentedCount;

  const ModalCoordinatorState({
    this.queue = const [],
    this.isPresenting = false,
    this.activeDedupeKeys = const {},
    this.onboardingInProgress = false,
    this.queueTransitions = 0,
    this.presentedCount = 0,
  });

  ModalCoordinatorState copyWith({
    List<AppModalRequest<dynamic>>? queue,
    bool? isPresenting,
    Set<String>? activeDedupeKeys,
    bool? onboardingInProgress,
    int? queueTransitions,
    int? presentedCount,
  }) {
    return ModalCoordinatorState(
      queue: queue ?? this.queue,
      isPresenting: isPresenting ?? this.isPresenting,
      activeDedupeKeys: activeDedupeKeys ?? this.activeDedupeKeys,
      onboardingInProgress: onboardingInProgress ?? this.onboardingInProgress,
      queueTransitions: queueTransitions ?? this.queueTransitions,
      presentedCount: presentedCount ?? this.presentedCount,
    );
  }
}

class ModalCoordinatorNotifier extends StateNotifier<ModalCoordinatorState> {
  ModalCoordinatorNotifier() : super(const ModalCoordinatorState());

  int _counter = 0;

  String nextRequestId(String prefix) {
    _counter++;
    return '$prefix-$_counter';
  }

  void setOnboardingInProgress(bool value) {
    if (state.onboardingInProgress == value) return;
    state = state.copyWith(onboardingInProgress: value);
  }

  void enqueue<T>(AppModalRequest<T> request) {
    final key = request.dedupeKey;
    if (key != null) {
      final existsInQueue = state.queue.any((r) => r.dedupeKey == key);
      final isActive = state.activeDedupeKeys.contains(key);
      if (existsInQueue || isActive) {
        debugPrint(
          '[MODAL_QUEUE] dedupe-skip id=${request.id} key=$key inQueue=$existsInQueue active=$isActive',
        );
        return;
      }
    }

    // IMPORTANT: state.queue stores requests as `dynamic`.
    // If we store a typed `onCompleted` (e.g. `(bool?) => void`) directly, it is
    // NOT assignable to `void Function(dynamic?)?` and will crash at runtime
    // when invoked from the drain loop.
    //
    // Wrap onCompleted so it always accepts `dynamic` and re-casts internally.
    final wrapped = AppModalRequest<dynamic>(
      id: request.id,
      priority: request.priority,
      dedupeKey: request.dedupeKey,
      present: (context, ref) => request.present(context, ref),
      onCompleted: request.onCompleted == null
          ? null
          : (dynamic result) => request.onCompleted!(result as T?),
    );

    final nextQueue = [...state.queue, wrapped];
    nextQueue.sort(
      (a, b) => _priorityRank(a.priority).compareTo(_priorityRank(b.priority)),
    );
    state = state.copyWith(queue: nextQueue);
    debugPrint(
      '[MODAL_QUEUE] enqueue id=${request.id} priority=${request.priority.name} key=${request.dedupeKey ?? "none"} queueSize=${nextQueue.length}',
    );
  }

  void clearQueue({String? reason}) {
    final dropped = state.queue
        .map((r) => '${r.id}:${r.dedupeKey ?? "no-key"}')
        .join(', ');
    final n = state.queue.length;
    final wasPresenting = state.isPresenting;
    state = state.copyWith(
      queue: const [],
      isPresenting: false,
      activeDedupeKeys: const {},
      onboardingInProgress: false,
      queueTransitions: state.queueTransitions + 1,
    );
    debugPrint(
      '[MODAL_QUEUE] clearQueue reason=${reason ?? "unspecified"} '
      'droppedCount=$n wasPresenting=$wasPresenting dropped=[$dropped]',
    );
  }

  AppModalRequest<dynamic>? takeNext() {
    if (state.isPresenting || state.queue.isEmpty) return null;
    assert(
      !state.isPresenting,
      'Modal coordinator invariant violated: tried to present while already presenting',
    );
    final request = state.queue.first;
    final remaining = state.queue.sublist(1);
    final nextKeys = {...state.activeDedupeKeys};
    if (request.dedupeKey != null) {
      nextKeys.add(request.dedupeKey!);
    }
    state = state.copyWith(
      queue: remaining,
      isPresenting: true,
      activeDedupeKeys: nextKeys,
      queueTransitions: state.queueTransitions + 1,
    );
    debugPrint(
      '[MODAL_QUEUE] dequeue id=${request.id} key=${request.dedupeKey ?? "none"} queueSize=${remaining.length}',
    );
    return request;
  }

  void complete(String requestId, dynamic result, {String? dedupeKey}) {
    final nextKeys = {...state.activeDedupeKeys};
    if (dedupeKey != null) {
      nextKeys.remove(dedupeKey);
    }
    state = state.copyWith(
      isPresenting: false,
      activeDedupeKeys: nextKeys,
      queueTransitions: state.queueTransitions + 1,
      presentedCount: state.presentedCount + 1,
    );
    debugPrint(
      '[MODAL_QUEUE] complete id=$requestId key=${dedupeKey ?? "none"} queueSize=${state.queue.length}',
    );
  }
}

final modalCoordinatorProvider =
    StateNotifierProvider<ModalCoordinatorNotifier, ModalCoordinatorState>(
      (ref) => ModalCoordinatorNotifier(),
    );
