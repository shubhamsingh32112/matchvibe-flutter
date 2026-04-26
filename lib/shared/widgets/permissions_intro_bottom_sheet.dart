import 'package:flutter/material.dart';
import 'brand_app_chrome.dart';
import 'ui_primitives.dart';

/// Blocking onboarding sheet that introduces required app permissions.
class PermissionsIntroBottomSheet extends StatelessWidget {
  final VoidCallback onAgree;
  final VoidCallback? onNotNow;
  final VoidCallback? onPresented;

  const PermissionsIntroBottomSheet({
    super.key,
    required this.onAgree,
    this.onNotNow,
    this.onPresented,
  });

  @override
  Widget build(BuildContext context) {
    return _OnPresentedOnce(
      onPresented: onPresented,
      child: PopScope(
        canPop: true,
        child: DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (context, scrollController) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                children: [
                  const BrandSheetHeader(title: 'Permissions Required'),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'To give you a fast and smooth calling experience, '
                            'please allow the following permissions now.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                          ),
                          const SizedBox(height: 14),
                          const _PermissionTile(
                            icon: Icons.videocam_rounded,
                            title: 'Camera',
                            subtitle:
                                'Required to start and receive video calls.',
                          ),
                          const SizedBox(height: 10),
                          const _PermissionTile(
                            icon: Icons.mic_rounded,
                            title: 'Microphone',
                            subtitle:
                                'Required so both users can hear each other.',
                          ),
                          const SizedBox(height: 10),
                          const _PermissionTile(
                            icon: Icons.notifications_active_rounded,
                            title: 'Notifications',
                            subtitle:
                                'Required for important call and chat alerts.',
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'You can update these permissions anytime from your '
                            'device settings.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 18),
                          PrimaryButton(label: 'Agree', onPressed: onAgree),
                          if (onNotNow != null) ...[
                            const SizedBox(height: 8),
                            Center(
                              child: TextButton(
                                onPressed: onNotNow,
                                child: const Text('Not now'),
                              ),
                            ),
                          ],
                          SizedBox(
                            height: MediaQuery.of(context).padding.bottom,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnPresentedOnce extends StatefulWidget {
  final VoidCallback? onPresented;
  final Widget child;

  const _OnPresentedOnce({required this.onPresented, required this.child});

  @override
  State<_OnPresentedOnce> createState() => _OnPresentedOnceState();
}

class _OnPresentedOnceState extends State<_OnPresentedOnce> {
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    if (widget.onPresented == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _fired) return;
      _fired = true;
      widget.onPresented?.call();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: scheme.onPrimaryContainer, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
