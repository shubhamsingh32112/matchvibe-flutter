import 'package:flutter/material.dart';

/// Status chip for creator-owned stories/posts in My Moments.
class MomentStatusBadge extends StatelessWidget {
  const MomentStatusBadge({
    super.key,
    this.processingStatus,
    this.moderationStatus,
    this.uploadRewardStatus,
    this.mediaProcessingStatus,
  });

  final String? processingStatus;
  final String? moderationStatus;
  final String? uploadRewardStatus;
  final String? mediaProcessingStatus;

  String? get _effectiveProcessing =>
      processingStatus ?? mediaProcessingStatus;

  ({String label, Color color})? get _status {
    final processing = _effectiveProcessing;
    if (processing == 'uploading' || processing == 'processing') {
      return (label: 'Processing', color: Colors.amber.shade800);
    }
    if (processing == 'failed') {
      return (label: 'Failed', color: Colors.red.shade700);
    }
    if (moderationStatus == 'pending') {
      return (label: 'Under review', color: Colors.orange.shade800);
    }
    if (moderationStatus == 'rejected') {
      return (label: 'Rejected', color: Colors.red.shade700);
    }
    if (uploadRewardStatus == 'pending') {
      return (label: 'Waiting for approval', color: Colors.orange.shade800);
    }
    if (uploadRewardStatus == 'rejected') {
      return (label: 'Reward rejected', color: Colors.red.shade700);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: status.color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
