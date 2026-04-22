import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/loader_bg_wordmark_cover.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  final DateTime _splashStart = DateTime.now();
  double _progress = 0;
  static const double _progressCap = 0.92;
  Timer? _progressTimer;
  late final AnimationController _barRevealController;

  @override
  void initState() {
    super.initState();
    _barRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _startProgressTicker();
    _checkAuthState();
  }

  void _startProgressTicker() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!mounted) return;
      if (_progress >= _progressCap) return;
      setState(() {
        _progress = (_progress + 0.032).clamp(0.0, _progressCap);
      });
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _barRevealController.dispose();
    super.dispose();
  }

  void _goAfterAuth(AuthState authState) {
    if (!mounted) return;
    if (authState.user?.gender == null || authState.user!.gender!.isEmpty) {
      context.go('/gender');
    } else {
      context.go('/home');
    }
  }

  Future<void> _finishAndNavigate(Future<void> Function() navigate) async {
    _progressTimer?.cancel();
    if (!mounted) return;
    setState(() => _progress = 1.0);
    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    await navigate();
    debugPrint(
      '⏱️ [SPLASH] Interactive in ${DateTime.now().difference(_splashStart).inMilliseconds}ms',
    );
  }

  /// Waits for Firebase restore + backend sync so we do not send users to /login
  /// while [AuthState.isAuthenticated] is still false only because sync is in flight.
  Future<void> _checkAuthState() async {
    const poll = Duration(milliseconds: 500);
    final deadline = DateTime.now().add(const Duration(seconds: 20));

    try {
      while (mounted && DateTime.now().isBefore(deadline)) {
        final s = ref.read(authProvider);
        final firebaseUser = FirebaseAuth.instance.currentUser;

        if (s.error != null &&
            s.error!.contains('Firebase') &&
            firebaseUser == null &&
            !s.isLoading) {
          if (mounted) {
            AppToast.showInfo(
              context,
              kDebugMode
                  ? 'Firebase not configured. Run flutterfire configure.'
                  : 'The app couldn\'t start. Please reinstall or contact support.',
              duration: const Duration(seconds: 5),
            );
            await Future.delayed(const Duration(seconds: 1));
            if (mounted) {
              await _finishAndNavigate(() async => context.go('/login'));
            }
          }
          return;
        }

        if (s.isAuthenticated) {
          await _finishAndNavigate(() async => _goAfterAuth(s));
          return;
        }

        if (firebaseUser != null) {
          await ref.read(authProvider.notifier).refreshAuthToken();
        }

        if (firebaseUser != null &&
            s.user == null &&
            !s.isLoading &&
            s.error != null) {
          if (mounted) {
            await _finishAndNavigate(() async => context.go('/login'));
          }
          return;
        }

        if (firebaseUser == null && !s.isLoading) {
          if (mounted) {
            await _finishAndNavigate(() async => context.go('/login'));
          }
          return;
        }

        await Future.delayed(poll);
      }

      if (!mounted) return;

      final s = ref.read(authProvider);
      if (s.isAuthenticated) {
        await _finishAndNavigate(() async => _goAfterAuth(s));
      } else if (mounted) {
        await _finishAndNavigate(() async => context.go('/login'));
      }
    } catch (e) {
      debugPrint('Auth check error: $e');
      if (mounted) {
        await _finishAndNavigate(() async => context.go('/login'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(AppConstants.loaderBackgroundAsset),
                fit: BoxFit.cover,
              ),
            ),
            child: const SizedBox.expand(),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.35),
                ],
              ),
            ),
            child: const SizedBox.expand(),
          ),
          const Positioned.fill(child: LoaderBgWordmarkCover()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24 + bottomInset,
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _barRevealController,
                curve: Curves.easeOut,
              ),
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: 0.78,
                  child: _SplashProgressBar(
                    progress: _progress,
                    trackColor: Colors.white.withValues(alpha: 0.35),
                    fillColor: scheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashProgressBar extends StatelessWidget {
  const _SplashProgressBar({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
  });

  final double progress;
  final Color trackColor;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    const height = 5.0;
    const radius = Radius.circular(height / 2);

    return Semantics(
      label: 'Loading',
      value: '${(progress * 100).round()}%',
      child: ClipRRect(
        borderRadius: const BorderRadius.all(radius),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: trackColor),
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth * progress.clamp(0.0, 1.0);
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: w,
                      height: height,
                      decoration: BoxDecoration(
                        color: fillColor,
                        borderRadius: const BorderRadius.all(radius),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
