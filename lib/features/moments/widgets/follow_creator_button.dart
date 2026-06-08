import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/styles/app_brand_styles.dart';
import '../providers/moments_providers.dart';
import '../services/moments_api_service.dart';

enum CreatorFollowButtonStyle { outlined, compact, profileCard }

class FollowCreatorButton extends ConsumerStatefulWidget {
  const FollowCreatorButton({
    super.key,
    required this.creatorId,
    this.initiallyFollowing,
    this.compact = false,
    this.style,
    this.onFollowChanged,
  });

  final String creatorId;
  final bool? initiallyFollowing;
  final bool compact;
  final CreatorFollowButtonStyle? style;
  final void Function(bool isFollowing, int followerCount)? onFollowChanged;

  CreatorFollowButtonStyle get _resolvedStyle {
    if (style != null) return style!;
    return compact ? CreatorFollowButtonStyle.compact : CreatorFollowButtonStyle.outlined;
  }

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
    final label = following ? 'Following' : 'Follow';

    switch (widget._resolvedStyle) {
      case CreatorFollowButtonStyle.compact:
        return TextButton(
          onPressed: _busy ? null : _toggle,
          child: Text(label),
        );
      case CreatorFollowButtonStyle.profileCard:
        final scheme = Theme.of(context).colorScheme;
        return Material(
          color: scheme.surfaceContainerHigh,
          elevation: 0,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: _busy ? null : _toggle,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppBrandGradients.accountMenuCardShadow,
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_busy)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      following ? Icons.person : Icons.person_add_outlined,
                      color: AppBrandGradients.creatorProfileAccentPink,
                      size: 22,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      case CreatorFollowButtonStyle.outlined:
        return OutlinedButton(
          onPressed: _busy ? null : _toggle,
          child: Text(label),
        );
    }
  }
}
