import 'package:flutter_riverpod/flutter_riverpod.dart';

class VipQueueEntry {
  final String creatorFirebaseUid;
  final int position;
  final String? callId;
  final String? entryId;

  const VipQueueEntry({
    required this.creatorFirebaseUid,
    required this.position,
    this.callId,
    this.entryId,
  });
}

class VipReadyToRingRequest {
  final String creatorId;
  final String creatorFirebaseUid;

  const VipReadyToRingRequest({
    required this.creatorId,
    required this.creatorFirebaseUid,
  });
}

class VipCallQueueState {
  final List<VipQueueEntry> entries;
  final VipReadyToRingRequest? pendingReadyToRing;

  const VipCallQueueState({
    this.entries = const [],
    this.pendingReadyToRing,
  });

  VipCallQueueState copyWith({
    List<VipQueueEntry>? entries,
    VipReadyToRingRequest? pendingReadyToRing,
    bool clearReadyToRing = false,
  }) {
    return VipCallQueueState(
      entries: entries ?? this.entries,
      pendingReadyToRing:
          clearReadyToRing ? null : (pendingReadyToRing ?? this.pendingReadyToRing),
    );
  }
}

class VipCallQueueNotifier extends Notifier<VipCallQueueState> {
  @override
  VipCallQueueState build() => const VipCallQueueState();

  void onQueued(Map<String, dynamic> data) {
    final creatorFirebaseUid = data['creatorFirebaseUid']?.toString();
    if (creatorFirebaseUid == null || creatorFirebaseUid.isEmpty) return;

    final position = (data['position'] as num?)?.toInt() ?? 1;
    final entry = VipQueueEntry(
      creatorFirebaseUid: creatorFirebaseUid,
      position: position,
      callId: data['callId']?.toString(),
      entryId: data['entryId']?.toString(),
    );

    final existing = state.entries
        .where((e) => e.creatorFirebaseUid != creatorFirebaseUid)
        .toList();
    state = state.copyWith(entries: [...existing, entry]);
  }

  void onDequeued(Map<String, dynamic> data) {
    final creatorFirebaseUid = data['creatorFirebaseUid']?.toString();
    if (creatorFirebaseUid == null) return;
    state = state.copyWith(
      entries: state.entries
          .where((e) => e.creatorFirebaseUid != creatorFirebaseUid)
          .toList(),
    );
  }

  void removeEntry(String creatorFirebaseUid) {
    state = state.copyWith(
      entries: state.entries
          .where((e) => e.creatorFirebaseUid != creatorFirebaseUid)
          .toList(),
    );
  }

  void requestReadyToRing({
    required String creatorId,
    required String creatorFirebaseUid,
  }) {
    state = state.copyWith(
      pendingReadyToRing: VipReadyToRingRequest(
        creatorId: creatorId,
        creatorFirebaseUid: creatorFirebaseUid,
      ),
    );
  }

  void clearReadyToRing() {
    state = state.copyWith(clearReadyToRing: true);
  }
}

final vipCallQueueProvider =
    NotifierProvider<VipCallQueueNotifier, VipCallQueueState>(
  VipCallQueueNotifier.new,
);
