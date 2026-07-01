import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/styles/app_brand_styles.dart';
import '../services/moments_api_service.dart';
import '../utils/moments_follow_sync.dart';

enum CreatorFollowButtonStyle { outlined, compact, profileCard, viewerGradient, reelsAvatar }

class FollowCreatorButton extends ConsumerStatefulWidget {
  const FollowCreatorButton({
    super.key,
    required this.creatorId,
    this.initiallyFollowing,
    this.compact = false,
    this.style,
    this.onFollowChanged,
    this.enabled = true,
    this.creatorAvatarUrl,
    this.creatorName,
  });

  final String creatorId;
  final bool? initiallyFollowing;
  final bool compact;
  final CreatorFollowButtonStyle? style;
  final void Function(bool isFollowing, int followerCount)? onFollowChanged;
  final bool enabled;
  final String? creatorAvatarUrl;
  final String? creatorName;

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
    if (!widget.enabled) return;
    setState(() => _busy = true);
    try {
      if (_following == true) {
        final result = await _api.unfollowCreator(widget.creatorId);
        setState(() => _following = result.isFollowing);
        syncFollowState(
          ref,
          creatorId: widget.creatorId,
          isFollowing: result.isFollowing,
        );
        widget.onFollowChanged?.call(result.isFollowing, result.followerCount);
      } else {
        final result = await _api.followCreator(widget.creatorId);
        setState(() => _following = result.isFollowing);
        syncFollowState(
          ref,
          creatorId: widget.creatorId,
          isFollowing: result.isFollowing,
        );
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
    final canTap = widget.enabled && !_busy;

    switch (widget._resolvedStyle) {
      case CreatorFollowButtonStyle.compact:
        return TextButton(
          onPressed: canTap ? _toggle : null,
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
            onTap: canTap ? _toggle : null,
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
          onPressed: canTap ? _toggle : null,
          child: Text(label),
        );
      case CreatorFollowButtonStyle.viewerGradient:
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: canTap ? _toggle : null,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                gradient: AppBrandGradients.momentsViewerActionGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: _busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
        );
      case CreatorFollowButtonStyle.reelsAvatar:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: canTap && !following ? _toggle : null,
              child: SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white24,
                      backgroundImage: widget.creatorAvatarUrl != null &&
                              widget.creatorAvatarUrl!.isNotEmpty
                          ? NetworkImage(widget.creatorAvatarUrl!)
                          : null,
                      child: widget.creatorAvatarUrl == null ||
                              widget.creatorAvatarUrl!.isEmpty
                          ? const Icon(Icons.person, color: Colors.white, size: 24)
                          : null,
                    ),
                    if (_busy)
                      const Positioned.fill(
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    else if (!following)
                      Positioned(
                        bottom: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            gradient: AppBrandGradients.momentsViewerActionGradient,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              following ? 'Following' : 'Follow',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
    }
  }
}
