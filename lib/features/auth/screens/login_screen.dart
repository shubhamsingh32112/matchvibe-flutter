import 'dart:async' show unawaited;
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/app_modal_bottom_sheet.dart';
import '../../../core/utils/referral_code_format.dart';
import '../../referral/services/referral_service.dart';
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
  static const double _referralFieldGap = 8;
  static const double _referralApplyGap = 10;
  static const double _referralToGoogleGap = 14;
  static const double _socialButtonsGap = 12;

  final _referralController = TextEditingController();
  final _referralFocusNode = FocusNode();
  final _referralService = ReferralService();

  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _videoFailed = false;

  /// Tracks that the user started Google sign-in (for in-pill spinner).
  bool _googlePressed = false;

  /// Phone sheet is sending OTP (for in-pill spinner on main screen).
  bool _phoneSending = false;

  /// After successful [GET /referral/preview] — normalized code shown in banner.
  String? _stagedReferralDisplay;

  String? _referralInlineError;
  bool _previewLoading = false;
  int _previewRequestId = 0;
  int _activePreviewId = 0;

  /// Referral code came from install referrer or `?ref=` deep link (auto-stage for login).
  bool _autoReferralFromLink = false;

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
      });
    } on ApplyReferralException catch (e) {
      if (requestId != _activePreviewId) return;
      await ref.read(authProvider.notifier).setPendingReferralCode(null);
      if (!mounted) return;
      setState(() {
        _previewLoading = false;
        _stagedReferralDisplay = null;
        _referralInlineError = e.message;
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
      });
    } catch (e) {
      if (requestId != _activePreviewId) return;
      await ref.read(authProvider.notifier).setPendingReferralCode(null);
      if (!mounted) return;
      setState(() {
        _previewLoading = false;
        _stagedReferralDisplay = null;
        _referralInlineError = 'Could not verify referral code. Try again.';
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

  void _showPhoneLoginSheet() {
    final rootContext = context;
    String? phoneValue;
    var isSending = false;

    showAppModalBottomSheet<void>(
      context: context,
      barrierOpacity: 0.54,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: StatefulBuilder(
                  builder: (context, setModalState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const Text(
                          'Continue with Phone',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We\'ll send you a verification code.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Color(0xFF90CAF9),
                              onPrimary: Colors.black,
                              surface: Color(0xFF2A2A2A),
                              onSurface: Colors.white,
                            ),
                          ),
                          child: IntlPhoneField(
                            decoration: InputDecoration(
                              labelText: 'Phone number',
                              labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF90CAF9),
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            style: const TextStyle(color: Colors.white),
                            dropdownTextStyle: const TextStyle(
                              color: Colors.white,
                            ),
                            flagsButtonPadding: const EdgeInsets.only(left: 8),
                            initialCountryCode: 'IN',
                            enabled: !isSending,
                            onChanged: (phone) {
                              phoneValue = phone.completeNumber;
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: isSending
                                ? null
                                : () async {
                                    if (!_referralReadyForSignIn()) {
                                      AppToast.showInfo(
                                        sheetContext,
                                        'Tap Apply to confirm your referral code first.',
                                      );
                                      return;
                                    }
                                    final phone = phoneValue?.trim();
                                    if (phone == null || phone.isEmpty) {
                                      AppToast.showInfo(
                                        sheetContext,
                                        'Please enter your phone number',
                                      );
                                      return;
                                    }
                                    final refCode = _referralController.text
                                        .trim();
                                    if (refCode.isNotEmpty &&
                                        !ReferralCodeFormat.isValid(refCode)) {
                                      AppToast.showInfo(
                                        sheetContext,
                                        'Referral code must be 6 or 8 characters',
                                      );
                                      return;
                                    }

                                    setModalState(() => isSending = true);
                                    if (rootContext.mounted) {
                                      setState(() => _phoneSending = true);
                                    }
                                    try {
                                      await ref
                                          .read(authProvider.notifier)
                                          .setPendingReferralCode(
                                            refCode.isEmpty
                                                ? null
                                                : refCode.toUpperCase(),
                                          );
                                      final result = await ref
                                          .read(authProvider.notifier)
                                          .signInWithPhone(phone);

                                      if (!sheetContext.mounted) return;

                                      if (!result.success &&
                                          result.error != null &&
                                          result.error!.isNotEmpty) {
                                        AppToast.showError(
                                          sheetContext,
                                          result.error!,
                                        );
                                      }

                                      if (result.status ==
                                              PhoneAuthStartStatus
                                                  .alreadyAuthenticated ||
                                          result.status ==
                                              PhoneAuthStartStatus
                                                  .autoVerified ||
                                          (result.status ==
                                                  PhoneAuthStartStatus
                                                      .syncingBackend &&
                                              result.success)) {
                                        if (rootContext.mounted &&
                                            Navigator.of(rootContext)
                                                .canPop()) {
                                          Navigator.of(rootContext).pop();
                                        }
                                      }
                                    } finally {
                                      if (sheetContext.mounted) {
                                        setModalState(() => isSending = false);
                                      }
                                      if (rootContext.mounted) {
                                        setState(() => _phoneSending = false);
                                      }
                                    }
                                  },
                            borderRadius: BorderRadius.circular(28),
                            child: Ink(
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.94),
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: isSending
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      )
                                    : const Text(
                                        'Send code',
                                        style: TextStyle(
                                          color: Color(0xFF1A1A1A),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
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

  bool _isLoginBusy(AuthState authState) {
    return authState.isLoading ||
        (authState.firebaseUser != null &&
            authState.user == null &&
            authState.error == null);
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

  Widget _referralBlock(bool pillsEnabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Referral code (optional)',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: _referralFieldGap),
        TextField(
          controller: _referralController,
          focusNode: _referralFocusNode,
          enabled: pillsEnabled && !_previewLoading,
          decoration: InputDecoration(
            hintText: 'e.g. JOE48392 or JO4832',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.12),
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF90CAF9), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          textCapitalization: TextCapitalization.characters,
          maxLength: 8,
          onChanged: (_) {
            _activePreviewId = ++_previewRequestId;
            if (_stagedReferralDisplay != null) {
              unawaited(
                ref.read(authProvider.notifier).setPendingReferralCode(null),
              );
              setState(() {
                _stagedReferralDisplay = null;
                _referralInlineError = null;
              });
            }
          },
        ),
        const SizedBox(height: _referralApplyGap),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: pillsEnabled && !_previewLoading
                ? () => _runReferralPreview()
                : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _previewLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Apply'),
          ),
        ),
        if (_referralInlineError != null) ...[
          const SizedBox(height: 8),
          Text(
            _referralInlineError!,
            style: TextStyle(
              color: Colors.red.shade200,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ],
        if (_stagedReferralDisplay != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade300,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Referral validated: ${_stagedReferralDisplay!}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Continue with Google or phone to finish sign-in.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: pillsEnabled ? _clearStagedReferral : null,
                  child: Text(
                    'Change',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoginBusy = _isLoginBusy(authState);

    ref.listen(authProvider, (previous, next) {
      if (previous?.isLoading == true &&
          next.isLoading == false &&
          mounted &&
          _googlePressed) {
        setState(() => _googlePressed = false);
      }

      if (next.verificationId != null &&
          next.phoneNumber != null &&
          !next.isLoading &&
          mounted &&
          (_phoneSending ||
              previous?.verificationId != next.verificationId)) {
        setState(() => _phoneSending = false);
        debugPrint('✅ [UI] OTP sent, navigating to OTP screen...');
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!context.mounted) return;
          final nav = Navigator.of(context);
          if (nav.canPop()) {
            nav.pop();
          }
          context.push(
            '/otp',
            extra: {
              'phoneNumber': next.phoneNumber!,
              'verificationId': next.verificationId!,
            },
          );
        });
      }
      if (_phoneSending &&
          mounted &&
          !next.isLoading &&
          next.error == null &&
          next.verificationId == null &&
          next.isAuthenticated) {
        setState(() => _phoneSending = false);
      }
      if (next.isAuthenticated &&
          mounted &&
          previous?.isAuthenticated != true) {
        debugPrint('✅ [UI] User authenticated, navigating...');
        if (next.user?.gender == null || next.user!.gender!.isEmpty) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!context.mounted) return;
            context.go('/gender');
          });
        } else {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!context.mounted) return;
            context.go('/home');
          });
        }
      }
      if (next.error != null &&
          mounted &&
          !next.isLoading &&
          previous?.error != next.error) {
        if (_phoneSending) {
          setState(() => _phoneSending = false);
        }
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
    final showPhoneSpinner = _phoneSending && isLoginBusy;
    final pillsEnabled = !isLoginBusy;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _loginSectionHorizontalPadding,
                      _loginSectionTopPadding,
                      _loginSectionHorizontalPadding,
                      _loginSectionBottomPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _referralBlock(pillsEnabled),
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
                        const SizedBox(height: _socialButtonsGap),
                        _pillButton(
                          onPressed: pillsEnabled && !_previewLoading
                              ? _showPhoneLoginSheet
                              : null,
                          leading: const Icon(
                            Icons.phone_android_rounded,
                            size: 26,
                            color: Color(0xFF1A1A1A),
                          ),
                          label: 'Continue with Phone',
                          busyLabel: 'Sending…',
                          showSpinner: showPhoneSpinner,
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
