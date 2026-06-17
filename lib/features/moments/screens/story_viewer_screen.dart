import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/widgets/creator_profile_screen.dart';
import '../models/moments_models.dart';
import '../services/moments_api_service.dart';
import '../utils/moment_owner_actions.dart';
import 'story_viewers_screen.dart';
import '../widgets/stream_hls_player.dart';

class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.group,
    this.allowOwnerDelete = false,
  });

  final StoryGroup group;
  final bool allowOwnerDelete;

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen> {
  late final PageController _pageController;
  int _index = 0;
  int _currentPage = 0;
  Timer? _timer;
  bool _paused = false;
  final _storiesApi = StoriesApiService();
  late Map<String, int> _viewCounts;

  static const _storyDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _viewCounts = {
      for (final s in widget.group.stories)
        s.id: s.viewsCount ?? 0,
    };
    _pageController = PageController();
    _recordView(0);
    _scheduleAdvance();
  }

  void _scheduleAdvance() {
    _timer?.cancel();
    if (_paused) return;
    _timer = Timer(_storyDuration, () {
      if (!mounted) return;
      if (_index < widget.group.stories.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _recordView(int index) async {
    if (index >= widget.group.stories.length) return;
    final storyId = widget.group.stories[index].id;
    final count = await _storiesApi.recordStoryView(storyId);
    if (!mounted) return;
    setState(() => _viewCounts[storyId] = count);
  }

  void _openViewers(String storyId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoryViewersScreen(storyId: storyId),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _deleteCurrentStory() async {
    if (_index >= widget.group.stories.length) return;
    final storyId = widget.group.stories[_index].id;
    final deleted = await deleteStoryWithRefresh(ref, context, storyId);
    if (!deleted || !mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final stories = widget.group.stories;
    final currentStory = stories[_index];
    final showOwnerViews = widget.allowOwnerDelete;
    final viewCount = _viewCounts[currentStory.id] ?? currentStory.viewsCount ?? 0;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
            Navigator.of(context).pop();
          }
        },
        onLongPressStart: (_) {
          setState(() => _paused = true);
          _timer?.cancel();
        },
        onLongPressEnd: (_) {
          setState(() => _paused = false);
          _scheduleAdvance();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: stories.length,
              onPageChanged: (i) {
                setState(() {
                  _index = i;
                  _currentPage = i;
                });
                _recordView(i);
                _scheduleAdvance();
              },
              itemBuilder: (context, index) {
                final story = stories[index];
                final media = story.media;
                final distance = (index - _currentPage).abs();
                if (distance > 1) {
                  return ColoredBox(
                    color: Colors.black,
                    child: Image.network(media.thumbnailUrl, fit: BoxFit.cover),
                  );
                }
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (media.isVideo && media.playbackUrl != null)
                      StreamHlsPlayer(
                        key: ValueKey(story.id),
                        storyId: story.id,
                        playbackUrl: media.playbackUrl!,
                        expiresAtMs: media.expiresAtMs,
                        playbackContext: 'story',
                        enableTokenRefresh: true,
                        loop: false,
                        initDelay: distance == 0
                            ? Duration.zero
                            : Duration(milliseconds: 50 * distance),
                      )
                    else if (media.playbackUrl != null)
                      Image.network(media.playbackUrl!, fit: BoxFit.contain)
                    else
                      Image.network(media.thumbnailUrl, fit: BoxFit.contain),
                    SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (_index > 0) {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                  );
                                }
                              },
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (_index < stories.length - 1) {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                  );
                                } else {
                                  Navigator.of(context).pop();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: List.generate(stories.length, (i) {
                        final active = i == _index;
                        return Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: active
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => openCreatorProfile(
                            context,
                            ref,
                            widget.group.creatorId,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundImage:
                                    widget.group.creatorAvatarUrl != null
                                    ? NetworkImage(
                                        widget.group.creatorAvatarUrl!,
                                      )
                                    : null,
                                child: widget.group.creatorAvatarUrl == null
                                    ? const Icon(Icons.person, size: 18)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.sizeOf(context).width * 0.45,
                                ),
                                child: Text(
                                  widget.group.creatorName ?? 'Creator',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (showOwnerViews)
                          GestureDetector(
                            onTap: () => _openViewers(currentStory.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.visibility_outlined,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$viewCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (showOwnerViews) const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        if (widget.allowOwnerDelete)
                          IconButton(
                            tooltip: 'Delete story',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                            ),
                            onPressed: _deleteCurrentStory,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
