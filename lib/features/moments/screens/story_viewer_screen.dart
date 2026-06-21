import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../creator/providers/creator_dashboard_provider.dart';
import '../../home/widgets/creator_profile_screen.dart';
import '../models/moments_models.dart';
import '../services/moments_api_service.dart';
import '../utils/moment_owner_actions.dart';
import 'story_viewers_screen.dart';
import '../widgets/stream_hls_player.dart';

List<StoryGroup> buildStoryViewerGroups({
  required List<StoryGroup> feedGroups,
  List<StoryPresentation>? myStories,
  String? myCreatorId,
}) {
  if (myCreatorId == null || myStories == null || myStories.isEmpty) {
    return feedGroups;
  }

  final otherGroups =
      feedGroups.where((g) => g.creatorId != myCreatorId).toList();
  StoryGroup? ownFeedGroup;
  for (final group in feedGroups) {
    if (group.creatorId == myCreatorId) {
      ownFeedGroup = group;
      break;
    }
  }
  final myGroup = StoryGroup(
    creatorId: myStories.first.creatorId,
    unseen: false,
    stories: myStories,
    creatorName: ownFeedGroup?.creatorName,
    creatorAvatarUrl: ownFeedGroup?.creatorAvatarUrl,
    creatorFirebaseUid: ownFeedGroup?.creatorFirebaseUid,
  );
  return [myGroup, ...otherGroups];
}

int storyViewerGroupIndex(List<StoryGroup> groups, StoryGroup target) {
  return groups.indexWhere((g) => g.creatorId == target.creatorId);
}

class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.groups,
    required this.initialGroupIndex,
    this.initialStoryIndex = 0,
  }) : assert(groups.length > 0);

  final List<StoryGroup> groups;
  final int initialGroupIndex;
  final int initialStoryIndex;

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen> {
  late PageController _pageController;
  late int _groupIndex;
  late int _index;
  int _currentPage = 0;
  Timer? _timer;
  bool _paused = false;
  final _storiesApi = StoriesApiService();
  late Map<String, int> _viewCounts;

  static const _storyDuration = Duration(seconds: 5);

  StoryGroup get _group => widget.groups[_groupIndex];

  List<StoryPresentation> get _stories => _group.stories;

  bool get _isOwnGroup {
    final ownCreatorId =
        ref.read(creatorDashboardProvider).valueOrNull?.creatorProfile.id;
    return ownCreatorId != null && ownCreatorId == _group.creatorId;
  }

  @override
  void initState() {
    super.initState();
    _groupIndex = widget.initialGroupIndex.clamp(0, widget.groups.length - 1);
    final stories = widget.groups[_groupIndex].stories;
    _index = widget.initialStoryIndex.clamp(
      0,
      stories.isEmpty ? 0 : stories.length - 1,
    );
    _currentPage = _index;
    _viewCounts = {
      for (final group in widget.groups)
        for (final story in group.stories)
          story.id: story.viewsCount ?? 0,
    };
    _pageController = PageController(initialPage: _index);
    _recordView(_index);
    _scheduleAdvance();
  }

  void _scheduleAdvance() {
    _timer?.cancel();
    if (_paused || _stories.isEmpty) return;
    _timer = Timer(_storyDuration, () {
      if (!mounted) return;
      _goForward();
    });
  }

  void _goForward() {
    if (_index < _stories.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }
    if (_groupIndex < widget.groups.length - 1) {
      final nextGroup = widget.groups[_groupIndex + 1];
      if (nextGroup.stories.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      _goToGroup(_groupIndex + 1, storyIndex: 0);
      return;
    }
    Navigator.of(context).pop();
  }

  void _goBackward() {
    if (_index > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      return;
    }
    if (_groupIndex > 0) {
      final prevGroup = widget.groups[_groupIndex - 1];
      if (prevGroup.stories.isEmpty) return;
      _goToGroup(
        _groupIndex - 1,
        storyIndex: prevGroup.stories.length - 1,
      );
    }
  }

  void _goToGroup(int groupIndex, {required int storyIndex}) {
    _timer?.cancel();
    final oldController = _pageController;
    setState(() {
      _groupIndex = groupIndex;
      _index = storyIndex;
      _currentPage = storyIndex;
      _pageController = PageController(initialPage: storyIndex);
    });
    oldController.dispose();
    _recordView(storyIndex);
    _scheduleAdvance();
  }

  Future<void> _recordView(int index) async {
    if (index >= _stories.length) return;
    final storyId = _stories[index].id;
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
    if (_index >= _stories.length) return;
    final storyId = _stories[_index].id;
    final deleted = await deleteStoryWithRefresh(ref, context, storyId);
    if (!deleted || !mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_stories.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      );
    }

    final currentStory = _stories[_index];
    final showOwnerViews = _isOwnGroup;
    final viewCount =
        _viewCounts[currentStory.id] ?? currentStory.viewsCount ?? 0;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
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
              key: ValueKey('$_groupIndex-${_group.creatorId}'),
              controller: _pageController,
              itemCount: _stories.length,
              onPageChanged: (i) {
                setState(() {
                  _index = i;
                  _currentPage = i;
                });
                _recordView(i);
                _scheduleAdvance();
              },
              itemBuilder: (context, index) {
                final story = _stories[index];
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
                        key: ValueKey('$_groupIndex-${story.id}'),
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
                              onTap: _goBackward,
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _goForward,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      children: List.generate(_stories.length, (i) {
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
                            _group.creatorId,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundImage: _group.creatorAvatarUrl != null
                                    ? NetworkImage(
                                        _group.creatorAvatarUrl!,
                                      )
                                    : null,
                                child: _group.creatorAvatarUrl == null
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
                                  _group.creatorName ?? 'Creator',
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
                        if (showOwnerViews)
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
