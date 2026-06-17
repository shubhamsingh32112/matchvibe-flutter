import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/brand_app_chrome.dart';
import '../models/moments_models.dart';
import '../services/moments_api_service.dart';

class StoryViewersScreen extends ConsumerStatefulWidget {
  const StoryViewersScreen({super.key, required this.storyId});

  final String storyId;

  @override
  ConsumerState<StoryViewersScreen> createState() => _StoryViewersScreenState();
}

class _StoryViewersScreenState extends ConsumerState<StoryViewersScreen> {
  final _api = StoriesApiService();
  bool _loading = true;
  int _viewsCount = 0;
  List<StoryViewer> _viewers = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.fetchStoryViewers(widget.storyId);
      setState(() {
        _viewsCount = result.viewsCount;
        _viewers = result.viewers;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppBrandGradients.accountMenuPageBackground,
      appBar: buildAccountFlowAppBar(context, title: 'Story viewers'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Failed to load: $_error'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppBrandGradients.accountMenuCardShadow,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Unique views: $_viewsCount',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_viewers.isEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppBrandGradients.accountMenuCardShadow,
                        ),
                        padding: const EdgeInsets.all(16),
                        child: const Text('No viewers yet'),
                      )
                    else
                      ..._viewers.map(
                        (v) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: AppBrandGradients.accountMenuCardShadow,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: v.avatarUrl != null
                                  ? NetworkImage(v.avatarUrl!)
                                  : null,
                              child: v.avatarUrl == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(v.displayName),
                            subtitle: Text(v.viewedAt.toLocal().toString()),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
