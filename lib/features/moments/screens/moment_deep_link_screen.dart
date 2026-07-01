import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/moments_api_service.dart';
import 'creator_moment_viewer_screen.dart';

/// Loads a single moment by id (deep link / share entry) then opens the viewer.
class MomentDeepLinkScreen extends ConsumerStatefulWidget {
  const MomentDeepLinkScreen({super.key, required this.momentId});

  final String momentId;

  @override
  ConsumerState<MomentDeepLinkScreen> createState() =>
      _MomentDeepLinkScreenState();
}

class _MomentDeepLinkScreenState extends ConsumerState<MomentDeepLinkScreen> {
  final _api = MomentsApiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openMoment());
  }

  Future<void> _openMoment() async {
    try {
      final item = await _api.fetchMomentDetail(widget.momentId);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CreatorMomentViewerScreen(
            items: [item],
            initialIndex: 0,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this moment')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
