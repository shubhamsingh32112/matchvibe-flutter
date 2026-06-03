import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/moments_providers.dart';
import '../services/moments_api_service.dart';

class FollowCreatorButton extends ConsumerStatefulWidget {
  const FollowCreatorButton({
    super.key,
    required this.creatorId,
    this.initiallyFollowing,
    this.compact = false,
    this.onFollowChanged,
  });

  final String creatorId;
  final bool? initiallyFollowing;
  final bool compact;
  final void Function(bool isFollowing, int followerCount)? onFollowChanged;

  @override
  ConsumerState<FollowCreatorButton> createState() =>
      _FollowCreatorButtonState();
}

class _FollowCreatorButtonState extends ConsumerState<FollowCreatorButton> {
  bool? _following;
  bool _busy = false;
  final _api = MomentsApiService();

  @override
  void initState() {
    super.initState();
    _following = widget.initiallyFollowing;
  }

  @override
  void didUpdateWidget(covariant FollowCreatorButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyFollowing != null &&
        widget.initiallyFollowing != oldWidget.initiallyFollowing) {
      _following = widget.initiallyFollowing;
    }
  }

  Future<void> _toggle() async {
    setState(() => _busy = true);
    try {
      if (_following == true) {
        final result = await _api.unfollowCreator(widget.creatorId);
        setState(() => _following = result.isFollowing);
        ref.invalidate(followingCreatorsProvider);
        ref.invalidate(followingFeedProvider);
        ref.invalidate(creatorSummaryProvider(widget.creatorId));
        widget.onFollowChanged?.call(result.isFollowing, result.followerCount);
      } else {
        final result = await _api.followCreator(widget.creatorId);
        setState(() => _following = result.isFollowing);
        ref.invalidate(followingCreatorsProvider);
        ref.invalidate(followingFeedProvider);
        ref.invalidate(creatorSummaryProvider(widget.creatorId));
        widget.onFollowChanged?.call(result.isFollowing, result.followerCount);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final following = _following ?? false;
    if (widget.compact) {
      return TextButton(
        onPressed: _busy ? null : _toggle,
        child: Text(following ? 'Following' : 'Follow'),
      );
    }
    return OutlinedButton(
      onPressed: _busy ? null : _toggle,
      child: Text(following ? 'Following' : 'Follow'),
    );
  }
}
