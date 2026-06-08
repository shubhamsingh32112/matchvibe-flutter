import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/styles/app_brand_styles.dart';
import '../providers/moments_providers.dart';

class MomentsFeedTabBar extends ConsumerWidget {
  const MomentsFeedTabBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(momentsFeedTabProvider);
    final filter = ref.watch(momentsMediaFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _UnderlineTab(
            label: 'Popular',
            selected: tab == MomentsFeedTab.popular,
            onTap: () => ref.read(momentsFeedTabProvider.notifier).state =
                MomentsFeedTab.popular,
          ),
          const SizedBox(width: 20),
          _UnderlineTab(
            label: 'Following',
            selected: tab == MomentsFeedTab.following,
            onTap: () => ref.read(momentsFeedTabProvider.notifier).state =
                MomentsFeedTab.following,
          ),
          const Spacer(),
          _MediaFilterDropdown(
            filter: filter,
            onChanged: (value) =>
                ref.read(momentsMediaFilterProvider.notifier).state = value,
          ),
        ],
      ),
    );
  }
}

class _UnderlineTab extends StatelessWidget {
  const _UnderlineTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected
                  ? AppBrandGradients.momentsTabActiveColor
                  : AppBrandGradients.momentsTabInactiveColor,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: selected ? 28 : 0,
            height: 3,
            decoration: BoxDecoration(
              color: AppBrandGradients.momentsTabActiveColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaFilterDropdown extends StatelessWidget {
  const _MediaFilterDropdown({
    required this.filter,
    required this.onChanged,
  });

  final MomentsMediaFilter filter;
  final ValueChanged<MomentsMediaFilter> onChanged;

  String get _label {
    switch (filter) {
      case MomentsMediaFilter.all:
        return 'All';
      case MomentsMediaFilter.photos:
        return 'Photos';
      case MomentsMediaFilter.videos:
        return 'Videos';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopupMenuButton<MomentsMediaFilter>(
      onSelected: onChanged,
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: MomentsMediaFilter.all,
          child: Text('All'),
        ),
        const PopupMenuItem(
          value: MomentsMediaFilter.photos,
          child: Text('Photos'),
        ),
        const PopupMenuItem(
          value: MomentsMediaFilter.videos,
          child: Text('Videos'),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
