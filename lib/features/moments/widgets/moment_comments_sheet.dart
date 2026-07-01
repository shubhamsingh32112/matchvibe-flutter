import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/compact_count_formatter.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../account/theme/moments_premium_page_tokens.dart';
import '../../auth/providers/auth_provider.dart';
import '../../creator/utils/creator_home_formatters.dart';
import '../models/moments_models.dart';
import '../services/moments_api_service.dart';
import 'vip_highlight_badge.dart';

Future<void> showMomentCommentsSheet({
  required BuildContext context,
  required String momentId,
  required int initialCommentsCount,
  void Function(int commentsCount)? onCommentsCountChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF121212),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => MomentCommentsSheet(
      momentId: momentId,
      initialCommentsCount: initialCommentsCount,
      onCommentsCountChanged: onCommentsCountChanged,
    ),
  );
}

class MomentCommentsSheet extends ConsumerStatefulWidget {
  const MomentCommentsSheet({
    super.key,
    required this.momentId,
    required this.initialCommentsCount,
    this.onCommentsCountChanged,
  });

  final String momentId;
  final int initialCommentsCount;
  final void Function(int commentsCount)? onCommentsCountChanged;

  @override
  ConsumerState<MomentCommentsSheet> createState() => _MomentCommentsSheetState();
}

class _MomentCommentsSheetState extends ConsumerState<MomentCommentsSheet> {
  final _api = MomentsApiService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<MomentComment> _pinnedComments = [];
  final List<MomentComment> _comments = [];
  String? _nextCursor;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _posting = false;
  bool _postAsVipHighlighted = false;
  String? _replyToCommentId;
  String? _replyToAuthorName;
  int _commentsCount = 0;

  static const _accentPurple = MomentsPremiumPageTokens.accentPurple;

  @override
  void initState() {
    super.initState();
    _commentsCount = widget.initialCommentsCount;
    _loadComments();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 120) {
      _loadMore();
    }
  }

  int get _totalVisibleComments => _pinnedComments.length + _comments.length;

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      final page = await _api.fetchComments(widget.momentId);
      if (!mounted) return;
      setState(() {
        _pinnedComments
          ..clear()
          ..addAll(page.pinnedHighlightedComments);
        _comments
          ..clear()
          ..addAll(page.items);
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_nextCursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _api.fetchComments(
        widget.momentId,
        cursor: _nextCursor,
      );
      if (!mounted) return;
      setState(() {
        _comments.addAll(page.items);
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _setReplyTarget(MomentComment comment) {
    setState(() {
      _replyToCommentId = comment.id;
      _replyToAuthorName = comment.authorName;
      _postAsVipHighlighted = false;
    });
  }

  void _clearReplyTarget() {
    setState(() {
      _replyToCommentId = null;
      _replyToAuthorName = null;
    });
  }

  Future<void> _submitComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _posting) return;
    final postHighlighted =
        _postAsVipHighlighted && _replyToCommentId == null;
    setState(() => _posting = true);
    try {
      final comment = await _api.postComment(
        widget.momentId,
        text: text,
        parentCommentId: _replyToCommentId,
        isVipHighlighted: postHighlighted,
      );
      if (!mounted) return;
      setState(() {
        if (_replyToCommentId == null) {
          if (postHighlighted) {
            _pinnedComments.insert(0, comment);
          } else {
            _comments.insert(0, comment);
          }
          _commentsCount += 1;
          widget.onCommentsCountChanged?.call(_commentsCount);
        } else {
          _insertReply(_replyToCommentId!, comment);
        }
        _controller.clear();
        _clearReplyTarget();
        _postAsVipHighlighted = false;
        _posting = false;
      });
    } catch (_) {
      if (mounted) setState(() => _posting = false);
    }
  }

  void _insertReply(String parentId, MomentComment reply) {
    final pinnedIndex = _pinnedComments.indexWhere((c) => c.id == parentId);
    if (pinnedIndex >= 0) {
      final parent = _pinnedComments[pinnedIndex];
      _pinnedComments[pinnedIndex] = parent.copyWith(
        replies: [...parent.replies, reply],
      );
      return;
    }
    final index = _comments.indexWhere((c) => c.id == parentId);
    if (index >= 0) {
      final parent = _comments[index];
      _comments[index] = parent.copyWith(
        replies: [...parent.replies, reply],
      );
    }
  }

  Future<void> _toggleCommentLike(MomentComment comment, {String? parentId}) async {
    try {
      final result = comment.isLiked
          ? await _api.unlikeComment(widget.momentId, comment.id)
          : await _api.likeComment(widget.momentId, comment.id);
      if (!mounted) return;
      setState(() {
        _updateCommentInList(
          comment.id,
          parentId: parentId,
          likesCount: result.likesCount,
          isLiked: result.isLiked,
        );
      });
    } catch (_) {}
  }

  void _updateCommentInList(
    String commentId, {
    String? parentId,
    required int likesCount,
    required bool isLiked,
  }) {
    if (parentId == null) {
      final pinnedIndex = _pinnedComments.indexWhere((c) => c.id == commentId);
      if (pinnedIndex >= 0) {
        _pinnedComments[pinnedIndex] = _pinnedComments[pinnedIndex].copyWith(
          likesCount: likesCount,
          isLiked: isLiked,
        );
        return;
      }
      final index = _comments.indexWhere((c) => c.id == commentId);
      if (index >= 0) {
        _comments[index] = _comments[index].copyWith(
          likesCount: likesCount,
          isLiked: isLiked,
        );
      }
      return;
    }

    void updateParent(List<MomentComment> list, int parentIndex) {
      final parent = list[parentIndex];
      final replies = parent.replies.map((r) {
        if (r.id != commentId) return r;
        return r.copyWith(likesCount: likesCount, isLiked: isLiked);
      }).toList();
      list[parentIndex] = parent.copyWith(replies: replies);
    }

    final pinnedParentIndex = _pinnedComments.indexWhere((c) => c.id == parentId);
    if (pinnedParentIndex >= 0) {
      updateParent(_pinnedComments, pinnedParentIndex);
      return;
    }
    final parentIndex = _comments.indexWhere((c) => c.id == parentId);
    if (parentIndex >= 0) {
      updateParent(_comments, parentIndex);
    }
  }

  MomentComment _commentAt(int index) {
    if (index < _pinnedComments.length) {
      return _pinnedComments[index];
    }
    return _comments[index - _pinnedComments.length];
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.82;
    final user = ref.watch(authProvider.select((s) => s.user));
    final isVipActive = user?.isVipActive ?? false;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Comments ($_commentsCount)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppPalette.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            if (isVipActive && _replyToCommentId == null)
              _VipCommentPromoBanner(
                active: _postAsVipHighlighted,
                onTap: () => setState(
                  () => _postAsVipHighlighted = !_postAsVipHighlighted,
                ),
              )
            else if (!isVipActive && _replyToCommentId == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: GestureDetector(
                  onTap: () => context.push('/vip'),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _accentPurple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _accentPurple.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      'Get VIP to post highlighted comments',
                      style: TextStyle(
                        color: MomentsPremiumPageTokens.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _totalVisibleComments == 0
                      ? Center(
                          child: Text(
                            'No comments yet. Be the first!',
                            style: TextStyle(color: AppPalette.subtitle),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount:
                              _totalVisibleComments + (_loadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _totalVisibleComments) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            }
                            final comment = _commentAt(index);
                            return _CommentTile(
                              comment: comment,
                              onReply: () => _setReplyTarget(comment),
                              onLike: () => _toggleCommentLike(comment),
                              onReplyLike: (reply) => _toggleCommentLike(
                                reply,
                                parentId: comment.id,
                              ),
                            );
                          },
                        ),
            ),
            if (_replyToAuthorName != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.white.withValues(alpha: 0.06),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to $_replyToAuthorName',
                        style: TextStyle(color: AppPalette.subtitle, fontSize: 13),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                      onPressed: _clearReplyTarget,
                    ),
                  ],
                ),
              ),
            if (_postAsVipHighlighted && _replyToCommentId == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  children: [
                    const VipHighlightBadge(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Next comment will be highlighted',
                        style: TextStyle(
                          color: MomentsPremiumPageTokens.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                      onPressed: () => setState(() => _postAsVipHighlighted = false),
                    ),
                  ],
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    AppAvatar(
                      avatarAsset: user?.avatarAsset,
                      size: 36,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        maxLength: 500,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: TextStyle(color: AppPalette.subtitle),
                          counterText: '',
                          filled: true,
                          fillColor: const Color(0xFF1E1E1E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _posting ? null : _submitComment,
                      icon: _posting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.send_rounded,
                              color: _accentPurple,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VipCommentPromoBanner extends StatelessWidget {
  const _VipCommentPromoBanner({
    required this.active,
    required this.onTap,
  });

  final bool active;
  final VoidCallback onTap;

  static const _accentPurple = MomentsPremiumPageTokens.accentPurple;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _accentPurple.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _accentPurple.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.diamond_rounded,
              color: _accentPurple.withValues(alpha: 0.9),
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'VIP Comment',
                        style: TextStyle(
                          color: _accentPurple.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: MomentsPremiumPageTokens.textMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Stand out! Your comment will be highlighted.',
                    style: TextStyle(
                      color: MomentsPremiumPageTokens.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: active
                          ? [
                              _accentPurple,
                              MomentsPremiumPageTokens.accentPink,
                            ]
                          : [
                              const Color(0xFFE53935),
                              const Color(0xFFFF9800),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        size: 14,
                        color: MomentsPremiumPageTokens.accentGold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        active ? 'VIP on' : 'Comment as VIP',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.onReply,
    required this.onLike,
    required this.onReplyLike,
  });

  final MomentComment comment;
  final VoidCallback onReply;
  final VoidCallback onLike;
  final void Function(MomentComment reply) onReplyLike;

  static const _accentPurple = MomentsPremiumPageTokens.accentPurple;

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse(comment.createdAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                backgroundImage: comment.authorAvatarUrl != null &&
                        comment.authorAvatarUrl!.isNotEmpty
                    ? NetworkImage(comment.authorAvatarUrl!)
                    : null,
                child: comment.authorAvatarUrl == null ||
                        comment.authorAvatarUrl!.isEmpty
                    ? const Icon(Icons.person, size: 18, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            comment.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (comment.isVipHighlighted) ...[
                          const SizedBox(width: 6),
                          const VipHighlightBadge(compact: true),
                        ],
                        if (comment.isCreator) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _accentPurple.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Creator',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        if (createdAt != null) ...[
                          Text(
                            ' · ${formatRelativeStoryTime(createdAt)}',
                            style: TextStyle(
                              color: AppPalette.subtitle,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comment.text,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: onReply,
                      child: const Text(
                        'Reply',
                        style: TextStyle(
                          color: _accentPurple,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onLike,
                child: Column(
                  children: [
                    Icon(
                      comment.isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: comment.isLiked
                          ? AppBrandGradients.creatorProfileAccentPink
                          : Colors.white,
                    ),
                    if (comment.likesCount > 0)
                      Text(
                        formatCompactCount(comment.likesCount),
                        style: TextStyle(
                          color: AppPalette.subtitle,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (comment.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 46, top: 8),
              child: Column(
                children: comment.replies
                    .map(
                      (reply) => _ReplyTile(
                        reply: reply,
                        onLike: () => onReplyLike(reply),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({required this.reply, required this.onLike});

  final MomentComment reply;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse(reply.createdAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.white24,
            backgroundImage: reply.authorAvatarUrl != null &&
                    reply.authorAvatarUrl!.isNotEmpty
                ? NetworkImage(reply.authorAvatarUrl!)
                : null,
            child: reply.authorAvatarUrl == null || reply.authorAvatarUrl!.isEmpty
                ? const Icon(Icons.person, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reply.authorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    if (reply.isCreator) ...[
                      const SizedBox(width: 4),
                      Text(
                        '· Creator',
                        style: TextStyle(
                          color: MomentsPremiumPageTokens.accentPurple,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (createdAt != null) ...[
                      Text(
                        ' · ${formatRelativeStoryTime(createdAt)}',
                        style: TextStyle(
                          color: AppPalette.subtitle,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  reply.text,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onLike,
            child: Column(
              children: [
                Icon(
                  reply.isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                  color: reply.isLiked
                      ? AppBrandGradients.creatorProfileAccentPink
                      : Colors.white70,
                ),
                if (reply.likesCount > 0)
                  Text(
                    formatCompactCount(reply.likesCount),
                    style: TextStyle(color: AppPalette.subtitle, fontSize: 10),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
