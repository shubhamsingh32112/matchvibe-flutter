import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/compact_count_formatter.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../creator/utils/creator_home_formatters.dart';
import '../models/moments_models.dart';
import '../services/moments_api_service.dart';

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

class MomentCommentsSheet extends StatefulWidget {
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
  State<MomentCommentsSheet> createState() => _MomentCommentsSheetState();
}

class _MomentCommentsSheetState extends State<MomentCommentsSheet> {
  final _api = MomentsApiService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<MomentComment> _comments = [];
  String? _nextCursor;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _posting = false;
  String? _replyToCommentId;
  String? _replyToAuthorName;
  int _commentsCount = 0;

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

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      final page = await _api.fetchComments(widget.momentId);
      if (!mounted) return;
      setState(() {
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
    setState(() => _posting = true);
    try {
      final comment = await _api.postComment(
        widget.momentId,
        text: text,
        parentCommentId: _replyToCommentId,
      );
      if (!mounted) return;
      setState(() {
        if (_replyToCommentId == null) {
          _comments.insert(0, comment);
          _commentsCount += 1;
          widget.onCommentsCountChanged?.call(_commentsCount);
        } else {
          final parentIndex = _comments.indexWhere((c) => c.id == _replyToCommentId);
          if (parentIndex >= 0) {
            final parent = _comments[parentIndex];
            _comments[parentIndex] = MomentComment(
              id: parent.id,
              authorUserId: parent.authorUserId,
              authorName: parent.authorName,
              authorAvatarUrl: parent.authorAvatarUrl,
              isCreator: parent.isCreator,
              text: parent.text,
              likesCount: parent.likesCount,
              isLiked: parent.isLiked,
              parentCommentId: parent.parentCommentId,
              replies: [...parent.replies, comment],
              createdAt: parent.createdAt,
            );
          }
        }
        _controller.clear();
        _clearReplyTarget();
        _posting = false;
      });
    } catch (_) {
      if (mounted) setState(() => _posting = false);
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
      final index = _comments.indexWhere((c) => c.id == commentId);
      if (index < 0) return;
      final c = _comments[index];
      _comments[index] = MomentComment(
        id: c.id,
        authorUserId: c.authorUserId,
        authorName: c.authorName,
        authorAvatarUrl: c.authorAvatarUrl,
        isCreator: c.isCreator,
        text: c.text,
        likesCount: likesCount,
        isLiked: isLiked,
        parentCommentId: c.parentCommentId,
        replies: c.replies,
        createdAt: c.createdAt,
      );
      return;
    }
    final parentIndex = _comments.indexWhere((c) => c.id == parentId);
    if (parentIndex < 0) return;
    final parent = _comments[parentIndex];
    final replies = parent.replies.map((r) {
      if (r.id != commentId) return r;
      return MomentComment(
        id: r.id,
        authorUserId: r.authorUserId,
        authorName: r.authorName,
        authorAvatarUrl: r.authorAvatarUrl,
        isCreator: r.isCreator,
        text: r.text,
        likesCount: likesCount,
        isLiked: isLiked,
        parentCommentId: r.parentCommentId,
        replies: r.replies,
        createdAt: r.createdAt,
      );
    }).toList();
    _comments[parentIndex] = MomentComment(
      id: parent.id,
      authorUserId: parent.authorUserId,
      authorName: parent.authorName,
      authorAvatarUrl: parent.authorAvatarUrl,
      isCreator: parent.isCreator,
      text: parent.text,
      likesCount: parent.likesCount,
      isLiked: parent.isLiked,
      parentCommentId: parent.parentCommentId,
      replies: replies,
      createdAt: parent.createdAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.75;

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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Comments',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppPalette.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatCompactCount(_commentsCount),
                    style: TextStyle(color: AppPalette.subtitle),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _comments.isEmpty
                      ? Center(
                          child: Text(
                            'No comments yet. Be the first!',
                            style: TextStyle(color: AppPalette.subtitle),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _comments.length + (_loadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _comments.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            }
                            final comment = _comments[index];
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
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        maxLength: 500,
                        decoration: InputDecoration(
                          hintText: 'Add a comment…',
                          hintStyle: TextStyle(color: AppPalette.subtitle),
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
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
                              color: AppBrandGradients.momentsTabActiveColor,
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
                radius: 16,
                backgroundColor: Colors.white24,
                backgroundImage: comment.authorAvatarUrl != null &&
                        comment.authorAvatarUrl!.isNotEmpty
                    ? NetworkImage(comment.authorAvatarUrl!)
                    : null,
                child: comment.authorAvatarUrl == null ||
                        comment.authorAvatarUrl!.isEmpty
                    ? const Icon(Icons.person, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.authorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        if (comment.isCreator) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppBrandGradients.momentsTabActiveColor
                                  .withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Creator',
                              style: TextStyle(
                                color: AppBrandGradients.momentsTabActiveColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      comment.text,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (createdAt != null)
                          Text(
                            formatRelativeStoryTime(createdAt),
                            style: TextStyle(
                              color: AppPalette.subtitle,
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: onReply,
                          child: Text(
                            'Reply',
                            style: TextStyle(
                              color: AppPalette.subtitle,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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
                      size: 18,
                      color: comment.isLiked
                          ? AppBrandGradients.creatorProfileAccentPink
                          : Colors.white70,
                    ),
                    if (comment.likesCount > 0)
                      Text(
                        formatCompactCount(comment.likesCount),
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (comment.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 42, top: 8),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.white24,
            backgroundImage: reply.authorAvatarUrl != null &&
                    reply.authorAvatarUrl!.isNotEmpty
                ? NetworkImage(reply.authorAvatarUrl!)
                : null,
            child: reply.authorAvatarUrl == null || reply.authorAvatarUrl!.isEmpty
                ? const Icon(Icons.person, size: 12, color: Colors.white)
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
                        fontSize: 12,
                      ),
                    ),
                    if (reply.isCreator) ...[
                      const SizedBox(width: 4),
                      Text(
                        '· Creator',
                        style: TextStyle(
                          color: AppBrandGradients.momentsTabActiveColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(reply.text, style: const TextStyle(color: Colors.white, fontSize: 13)),
                if (createdAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      formatRelativeStoryTime(createdAt),
                      style: TextStyle(color: AppPalette.subtitle, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onLike,
            child: Icon(
              reply.isLiked ? Icons.favorite : Icons.favorite_border,
              size: 16,
              color: reply.isLiked
                  ? AppBrandGradients.creatorProfileAccentPink
                  : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
