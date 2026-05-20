import 'dart:async' show unawaited;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../core/utils/referral_code_format.dart';
import '../../referral/services/referral_service.dart';
import '../../referral/utils/host_onboarding_routes.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.initialRefParam});

  /// From `?ref=` query or deep link (optional).
  final String? initialRefParam;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with WidgetsBindingObserver {
  static const double _loginSectionHorizontalPadding = 28;
  static const double _loginSectionTopPadding = 12;
  static const double _loginSectionBottomPadding = 8;
  static const double _referralToGoogleGap = 11;

  final _referralController = TextEditingController();
  final _referralFocusNode = FocusNode();
  final _referralService = ReferralService();

  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _videoFailed = false;

  /// Tracks that the user started Google sign-in (for in-pill spinner).
  bool _googlePressed = false;

  /// After successful [GET /referral/preview] — normalized code shown in banner.
  String? _stagedReferralDisplay;

  String? _referralInlineError;
  bool _previewLoading = false;
  int _previewRequestId = 0;
  int _activePreviewId = 0;

  /// Referral code came from install referrer or `?ref=` deep link (auto-stage for login).
  bool _autoReferralFromLink = false;

  /// User opened the optional referral input (collapsed by default).
  bool _referralExpanded = false;

  bool get _showStagedChip =>
      _stagedReferralDisplay != null && !_referralExpanded;

  bool get _showReferralVerifying =>
      _autoReferralFromLink &&
      _previewLoading &&
      _stagedReferralDisplay == null &&
      !_referralExpanded;

  void _openReferralSection() {
    setState(() {
      _referralExpanded = true;
      _referralInlineError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _referralFocusNode.requestFocus();
    });
  }

  void _closeReferralSection() {
    if (_stagedReferralDisplay != null) {
      setState(() => _referralExpanded = false);
      return;
    }
    setState(() {
      _referralExpanded = false;
      _referralInlineError = null;
      _referralController.clear();
    });
  }

  Future<void> _editStagedReferral() async {
    await _clearStagedReferral();
    if (!mounted) return;
    _openReferralSection();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initVideo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapReferralUi());
    });
  }

  Future<void> _bootstrapReferralUi() async {
    await ref.read(authProvider.notifier).waitForReferralHydration();
    if (!mounted) return;

    final fromQuery = widget.initialRefParam?.trim();
    if (fromQuery != null && fromQuery.isNotEmpty) {
      await _stageAutoReferralFromLink(fromQuery);
      return;
    }
    final pending = ref.read(authProvider.notifier).peekPendingReferralCode();
    if (pending != null && pending.isNotEmpty) {
      await _stageAutoReferralFromLink(pending);
    }
  }

  Future<void> _stageAutoReferralFromLink(String raw) async {
    final upper = raw.trim().toUpperCase();
    if (upper.isEmpty || !ReferralCodeFormat.isValid(upper)) return;
    _autoReferralFromLink = true;
    _referralController.text = upper;
    await ref.read(authProvider.notifier).setPendingReferralCode(upper);
    if (!mounted) return;
    unawaited(_runReferralPreview(rawOverride: upper));
  }

  Future<void> _runReferralPreview({String? rawOverride}) async {
    final requestId = ++_previewRequestId;
    _activePreviewId = requestId;
    final raw = (rawOverride ?? _referralController.text).trim();
    if (raw.isEmpty) {
      setState(() {
        _referralInlineError = 'Enter a referral code';
        _stagedReferralDisplay = null;
        _referralExpanded = true;
      });
      return;
    }
    if (!ReferralCodeFormat.isValid(raw)) {
      if (mounted) {
        AppToast.showInfo(
          context,
          'Referral code must be 6 or 8 characters (e.g. JO4832 or JOE48392)',
        );
      }
      return;
    }

    setState(() {
      _previewLoading = true;
      _referralInlineError = null;
    });

    try {
      final previewMode = ref.read(authProvider).isAuthenticated
          ? ReferralPreviewMode.lateAttach
          : ReferralPreviewMode.signup;
      final normalized = await _referralService.previewReferralCode(
        raw,
        mode: previewMode,
      );
      if (requestId != _activePreviewId) return;
      await ref.read(authProvider.notifier).setPendingReferralCode(normalized);
      if (!mounted) return;
      setState(() {
        _previewLoading = false;
        _stagedReferralDisplay = normalized;
        _referralController.text = normalized;
        _referralInlineError = null;
        _referralExpanded = false;
      });
    } on ApplyReferralException catch (e) {
      if (requestId != _activePreviewId) return;
      await ref.read(authProvider.notifier).setPendingReferralCode(null);
      if (!mounted) return;
      setState(() {
        _previewLoading = false;
        _stagedReferralDisplay = null;
        _referralInlineError = e.message;
        _referralExpanded = true;
      });
    } on DioException catch (e) {
      if (requestId != _activePreviewId) return;
      await ref.read(authProvider.notifier).setPendingReferralCode(null);
      if (!mounted) return;
      setState(() {
        _previewLoading = false;
        _stagedReferralDisplay = null;
        _referralInlineError = ErrorHandler.getHumanReadableError(
          e.message ?? 'Network error',
        );
        _referralExpanded = true;
      });
    } catch (e) {
      if (requestId != _activePreviewId) return;
      await ref.read(authProvider.notifier).setPendingReferralCode(null);
      if (!mounted) return;
      setState(() {
        _previewLoading = false;
        _stagedReferralDisplay = null;
        _referralInlineError = 'Could not verify referral code. Try again.';
        _referralExpanded = true;
      });
    }
  }

  Future<void> _clearStagedReferral() async {
    await ref.read(authProvider.notifier).setPendingReferralCode(null);
    if (!mounted) return;
    setState(() {
      _stagedReferralDisplay = null;
      _referralInlineError = null;
      _referralController.clear();
    });
  }

  Future<void> _initVideo() async {
    VideoPlayerController? c;
    try {
      c = VideoPlayerController.asset(AppConstants.loginBackgroundVideoAsset);
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0);
      await c.play();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _videoController = c;
        _videoReady = true;
        _videoFailed = false;
      });
      c = null;
    } catch (e, st) {
      debugPrint('Login video init failed: $e\n$st');
      await c?.dispose();
      if (mounted) {
        setState(() {
          _videoFailed = true;
          _videoReady = false;
          _videoController = null;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _videoController;
    if (c == null || !_videoReady) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      c.pause();
    } else if (state == AppLifecycleState.resumed) {
      c.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _referralController.dispose();
    _referralFocusNode.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      AppToast.showInfo(context, 'Could not open link');
    }
  }

  bool _referralReadyForSignIn() {
    if (_previewLoading && !_autoReferralFromLink) return false;
    final typed = _referralController.text.trim();
    if (typed.isEmpty) return true;
    if (_autoReferralFromLink) {
      final pending = ref.read(authProvider.notifier).peekPendingReferralCode();
      if (pending != null && pending.toUpperCase() == typed.toUpperCase()) {
        return true;
      }
    }
    final staged = _stagedReferralDisplay;
    return staged != null && staged == typed.toUpperCase();
  }

  Future<void> _handleGoogleLogin() async {
    debugPrint('🖱️  [UI] Google Sign-In button pressed');

    if (!_referralReadyForSignIn()) {
      AppToast.showInfo(
        context,
        _autoReferralFromLink
            ? 'Verifying your referral code…'
            : 'Tap Apply to confirm your referral code first.',
      );
      return;
    }

    final refCode = _referralController.text.trim();
    if (refCode.isNotEmpty && !ReferralCodeFormat.isValid(refCode)) {
      AppToast.showInfo(
        context,
        'Referral code must be 6 or 8 characters (e.g. JO4832 or JOE48392)',
      );
      return;
    }

    setState(() => _googlePressed = true);
    await ref
        .read(authProvider.notifier)
        .setPendingReferralCode(refCode.isEmpty ? null : refCode.toUpperCase());
    await ref.read(authProvider.notifier).signInWithGoogle();
    if (mounted && !ref.read(authProvider).isLoading) {
      setState(() => _googlePressed = false);
    }
  }

  void _showNetworkErrorDialog(BuildContext context, String errorMessage) {
    final scheme = Theme.of(context).colorScheme;
    final isNoRouteToHost =
        errorMessage.toLowerCase().contains('no route to host') ||
        errorMessage.toLowerCase().contains('errno: 113');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.wifi_off, color: scheme.error),
            const SizedBox(width: 12),
            const Expanded(child: Text('Network Error')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (kDebugMode && isNoRouteToHost) ...[
                Text(
                  'Backend server is not reachable. Check backend URL and network.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
              ],
              Text(
                kDebugMode
                    ? 'Check backend connectivity and try again.'
                    : 'Please check your connection and try again.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(authProvider.notifier).clearError();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(authProvider.notifier).clearError();
              final currentState = ref.read(authProvider);
              if (currentState.firebaseUser != null) {
                ref.read(authProvider.notifier).syncUserToBackend();
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required VoidCallback? onPressed,
    required Widget leading,
    required String label,
    required String busyLabel,
    required bool showSpinner,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              if (showSpinner) const SizedBox(width: 36) else leading,
              Expanded(
                child: showSpinner
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              busyLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Color(0xFF1A1A1A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _referralSection(bool pillsEnabled) {
    if (_showStagedChip) {
      return _referralStagedChip(pillsEnabled);
    }
    if (_showReferralVerifying) {
      return _referralVerifyingRow();
    }
    if (_referralExpanded || _referralInlineError != null) {
      return _referralCompactInputRow(pillsEnabled);
    }
    return _referralCollapsedLink(pillsEnabled);
  }

  Widget _referralCollapsedLink(bool pillsEnabled) {
    return Align(
      alignment: Alignment.center,
      child: TextButton(
        onPressed: pillsEnabled ? _openReferralSection : null,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Have a referral code?',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.underline,
            decorationColor: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }

  Widget _referralVerifyingRow() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Verifying referral code…',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _referralStagedChip(bool pillsEnabled) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: Colors.green.shade300,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Referral applied · ${_stagedReferralDisplay!}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: pillsEnabled ? () => unawaited(_editStagedReferral()) : null,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Change',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _referralCompactInputRow(bool pillsEnabled) {
    final canApply = pillsEnabled && !_previewLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: _referralGlassInput(canApply)),
            const SizedBox(width: 6),
            TextButton(
              onPressed: pillsEnabled ? _closeReferralSection : null,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Not now',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        if (_referralInlineError != null) ...[
          const SizedBox(height: 6),
          Text(
            _referralInlineError!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.red.shade300,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }

  Widget _referralGlassInput(bool canApply) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _referralController,
              focusNode: _referralFocusNode,
              enabled: canApply,
              textInputAction: TextInputAction.done,
              onSubmitted: canApply ? (_) => _runReferralPreview() : null,
              decoration: InputDecoration(
                hintText: 'Referral code',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                isDense: true,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
              onChanged: (_) {
                _activePreviewId = ++_previewRequestId;
                if (_stagedReferralDisplay != null) {
                  unawaited(
                    ref
                        .read(authProvider.notifier)
                        .setPendingReferralCode(null),
                  );
                  setState(() {
                    _stagedReferralDisplay = null;
                    _referralInlineError = null;
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 38,
            child: ElevatedButton(
              onPressed: canApply ? () => _runReferralPreview() : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.2),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(72, 38),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: _previewLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    )
                  : const Text(
                      'Apply',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoginBusy = ref.watch(
      authProvider.select(
        (s) => s.isLoading ||
            (s.firebaseUser != null && s.user == null && s.error == null),
      ),
    );

    ref.listen(authProvider, (previous, next) {
      if (previous?.isLoading == true &&
          next.isLoading == false &&
          mounted &&
          _googlePressed) {
        setState(() => _googlePressed = false);
      }

      if (next.isAuthenticated &&
          mounted &&
          previous?.isAuthenticated != true) {
        debugPrint('✅ [UI] User authenticated, navigating...');
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!context.mounted) return;
          final hostRoute = hostOnboardingRedirectPath(next.user);
          if (hostRoute != null) {
            context.go(hostRoute);
            return;
          }
          if (next.user?.gender == null || next.user!.gender!.isEmpty) {
            context.go('/gender');
          } else {
            context.go('/home');
          }
        });
      }
      if (next.error != null &&
          mounted &&
          !next.isLoading &&
          previous?.error != next.error) {
        final errorMessage = next.error!;
        if (errorMessage.toLowerCase().contains('network') ||
            errorMessage.toLowerCase().contains('connection') ||
            errorMessage.toLowerCase().contains('no route to host')) {
          _showNetworkErrorDialog(context, errorMessage);
        } else {
          AppToast.showError(
            context,
            ErrorHandler.getHumanReadableError(errorMessage),
            duration: const Duration(seconds: 5),
          );
        }
      }
    });

    final showGoogleSpinner = _googlePressed && isLoginBusy;
    final pillsEnabled = !isLoginBusy;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_videoReady && _videoController != null)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              )
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: const AssetImage(AppConstants.loaderBackgroundAsset),
                    fit: BoxFit.cover,
                    colorFilter: _videoFailed
                        ? null
                        : ColorFilter.mode(
                            Colors.black.withValues(alpha: 0.3),
                            BlendMode.darken,
                          ),
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            if (!_videoReady && !_videoFailed)
              const Center(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
              child: const SizedBox.expand(),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppConstants.appName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 56,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (isLoginBusy)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: Colors.white24,
                        color: Colors.white,
                      ),
                    ),
                  SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      _loginSectionHorizontalPadding,
                      _loginSectionTopPadding,
                      _loginSectionHorizontalPadding,
                      _loginSectionBottomPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _referralSection(pillsEnabled),
                        const SizedBox(height: _referralToGoogleGap),
                        _pillButton(
                          onPressed: pillsEnabled && !_previewLoading
                              ? _handleGoogleLogin
                              : null,
                          leading: const Icon(
                            Icons.g_mobiledata,
                            size: 36,
                            color: Color(0xFF1A1A1A),
                          ),
                          label: 'Continue with Google',
                          busyLabel: 'Signing in…',
                          showSpinner: showGoogleSpinner,
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'Proceeding means you agree to our',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 12,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: () =>
                                        _openUrl(AppConstants.privacyPolicyUrl),
                                    child: Text(
                                      'Privacy Policy',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.95,
                                        ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Colors.white
                                            .withValues(alpha: 0.95),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    ' and ',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.88,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () =>
                                        _openUrl(AppConstants.termsOfUseUrl),
                                    child: Text(
                                      'Terms of Use',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.95,
                                        ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Colors.white
                                            .withValues(alpha: 0.95),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '.',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.88,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
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
          ],
        ),
      ),
    );
  }
}
