import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/brand_app_chrome.dart';

/// Bottom sheet wrapper for blocked buddies screen
class BlockedBuddiesBottomSheet extends StatelessWidget {
  const BlockedBuddiesBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => const BlockedBuddiesScreen(),
    );
  }
}

class BlockedBuddiesScreen extends StatefulWidget {
  const BlockedBuddiesScreen({super.key});

  @override
  State<BlockedBuddiesScreen> createState() => _BlockedBuddiesScreenState();
}

class _BlockedBuddiesScreenState extends State<BlockedBuddiesScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  int _blockedCreatorCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBlockedCount();
  }

  Future<void> _loadBlockedCount() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _apiClient.get('/user/blocked-creators/count');
      final count = (response.data['data']?['blockedCreatorCount'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      setState(() {
        _blockedCreatorCount = count;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load blocked creators count';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: ColoredBox(
        color: AppBrandGradients.accountMenuPageBackground,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const BrandSheetHeader(title: 'Blocked Buddies'),
              Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _isLoading
                    ? const Center(child: LoadingIndicator())
                    : _error != null
                        ? ErrorState(
                            message: _error!,
                            actionLabel: 'Retry',
                            onAction: _loadBlockedCount,
                          )
                        : AppCard(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Blocked creators',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _blockedCreatorCount.toString(),
                                  style: TextStyle(
                                    color: scheme.onSurface,
                                    fontSize: 38,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _blockedCreatorCount == 1
                                      ? 'You have blocked 1 creator.'
                                      : 'You have blocked $_blockedCreatorCount creators.',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 14,
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
      ),
    );
  }
}
