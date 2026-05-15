import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'app/router/app_router.dart';
import 'app/widgets/app_lifecycle_wrapper.dart';
import 'app/widgets/stream_chat_wrapper.dart';
import 'core/api/api_client.dart';
import 'core/services/memory_pressure_observer.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/chat/providers/stream_chat_provider.dart';
import 'features/video/services/security_service.dart';
import 'features/video/widgets/incoming_call_listener.dart';
import 'features/video/widgets/outgoing_call_overlay.dart';
import 'shared/providers/image_service_degraded_provider.dart';
import 'shared/widgets/image_service_degraded_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bump default 100MB image cache to 150MB so feed grid + gallery + call
  // backgrounds don't churn against each other on mid-range devices.
  // Also lift the default 1000-image count cap a bit so a long scroll session
  // doesn't evict warm avatars while the gallery hydrates.
  // Plan §7.3 + §11.3 + §16: monitor low-mem Android closely once shipped.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 150 << 20;
  PaintingBinding.instance.imageCache.maximumSize = 1500;

  // Register the memory-pressure ladder + 30s cache-size telemetry. Runs for
  // the full lifetime of the process — no dispose needed.
  MemoryPressureObserver.instance.register();

  // Load environment file based on build mode
  // Detect build mode: kReleaseMode is true in release builds, false in debug/profile
  final bool isProduction = kReleaseMode;
  final envFile = isProduction ? ".env.production" : ".env.development";

  if (kDebugMode) {
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('🔧 [ENV] Loading environment configuration');
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint(
      '   📦 Build Mode: ${isProduction ? "PRODUCTION" : "DEVELOPMENT"}',
    );
    debugPrint('   📄 Env File: $envFile');
    debugPrint('═══════════════════════════════════════════════════════');
  }

  await dotenv.load(fileName: envFile);

  // Release builds: debugPrint is stripped; use developer.log for adb logcat.
  //   adb logcat | findstr MatchVibe
  if (kReleaseMode) {
    final api = (dotenv.env['API_BASE_URL'] ?? '').trim();
    final socket = (dotenv.env['SOCKET_URL'] ?? '').trim();
    final hasGoogleWeb = (dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '')
        .trim()
        .isNotEmpty;
    final apiHost = Uri.tryParse(api)?.host ?? '';
    final socketHost = Uri.tryParse(socket)?.host ?? '';
    developer.log(
      'env=$envFile apiHost=$apiHost apiLen=${api.length} '
      'socketHost=$socketHost GOOGLE_WEB_CLIENT_ID_set=$hasGoogleWeb',
      name: 'MatchVibe',
    );
  }

  if (kDebugMode) {
    debugPrint('✅ [ENV] Environment loaded successfully');
    debugPrint(
      '   🌐 API_BASE_URL: ${dotenv.env['API_BASE_URL'] ?? "NOT SET"}',
    );
    debugPrint('   🔌 SOCKET_URL: ${dotenv.env['SOCKET_URL'] ?? "NOT SET"}');
    final apiBase = (dotenv.env['API_BASE_URL'] ?? '').trim();
    if (apiBase.contains('localhost') || apiBase.contains('127.0.0.1')) {
      debugPrint(
        '⚠️ [ENV] Debug/profile uses $envFile with a loopback API_BASE_URL. '
        'A physical device cannot reach your PC. Use a LAN URL in .env.development, '
        'adb reverse, or a release build to load .env.production.',
      );
    }
  }
  if (isProduction) {
    // Fail-safe warnings: if these are missing, the app will silently fall back to localhost and break in production.
    final requiredKeys = <String>[
      'API_BASE_URL',
      'SOCKET_URL',
      'WEBSITE_BASE_URL',
    ];
    final missing = requiredKeys
        .where((k) => (dotenv.env[k] ?? '').trim().isEmpty)
        .toList();
    final baseUrl = (dotenv.env['API_BASE_URL'] ?? '').trim();
    if (missing.isNotEmpty || baseUrl.contains('localhost')) {
      // Always print this warning, even in release builds
      debugPrint('❌ [ENV] Production env sanity check failed.');
      debugPrint('   Missing keys: $missing');
      debugPrint('   API_BASE_URL: "${dotenv.env['API_BASE_URL']}"');
      debugPrint('   ⚠️  App may be using wrong backend URL!');
    } else {
      if (kDebugMode) {
        debugPrint('✅ [ENV] Production environment validated');
        debugPrint('   🌐 Using production backend: $baseUrl');
      }
    }
  }

  final localNotifications = FlutterLocalNotificationsPlugin();
  final initFutures = <Future<void>>[
    SecurityService.initializeAppSecurity(),
    _initializeFirebaseSafely(),
    _initializeLocalNotifications(localNotifications),
  ];
  await Future.wait(initFutures);

  // Inject the single instance into PushNotificationService
  PushNotificationService().setNotificationsPlugin(localNotifications);

  // Register FCM background message handler (must be top-level function)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: MyApp()));
}

Future<void> _initializeFirebaseSafely() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    debugPrint('❌ Firebase initialization error: $e');
    debugPrint('⚠️  Please run: flutterfire configure');
    debugPrint('⚠️  App will continue but authentication will not work');
  }
}

Future<void> _initializeLocalNotifications(
  FlutterLocalNotificationsPlugin localNotifications,
) async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await localNotifications.initialize(
    initSettings,
    onDidReceiveNotificationResponse: onLocalNotificationTap,
  );

  if (Platform.isAndroid) {
    const channel = AndroidNotificationChannel(
      'chat_messages',
      'Chat Messages',
      description: 'Notifications for new chat messages',
      importance: Importance.high,
    );
    await localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  debugPrint('✅ Local notifications plugin initialized globally');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamChatWrapper(
      child: MaterialApp.router(
        title: 'Match Vibe',
        theme: AppTheme.lightTheme,
        routerConfig: appRouter,
        debugShowCheckedModeBanner: false,
        // Localizations configuration (required by StreamChat)
        supportedLocales: const [Locale('en')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // CRITICAL: All widgets that use Navigator/GoRouter/Material widgets MUST be inside MaterialApp
        // This ensures Directionality, Navigator, Theme, and MediaQuery are available
        // Order: StreamChat → AppLifecycleWrapper → IncomingCallListener → router child
        builder: (context, child) {
          return _StreamChatBuilder(
            child: AppLifecycleWrapper(
              child: IncomingCallListener(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    child ?? const SizedBox.shrink(),
                    const OutgoingCallOverlay(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Helper widget to build StreamChat inside MaterialApp (where Localizations is available)
class _StreamChatBuilder extends ConsumerStatefulWidget {
  final Widget? child;

  const _StreamChatBuilder({this.child});

  @override
  ConsumerState<_StreamChatBuilder> createState() => _StreamChatBuilderState();
}

class _StreamChatBuilderState extends ConsumerState<_StreamChatBuilder> {
  @override
  void initState() {
    super.initState();
    // Wire the Dio interceptor's degraded-mode hook to the Riverpod
    // provider once the widget tree (and its ProviderScope) is alive.
    ApiClient.setImageServiceDegradedCallback((degraded) {
      final notifier = ref.read(imageServiceDegradedProvider.notifier);
      if (degraded) {
        notifier.markDegraded();
      } else {
        notifier.markHealthy();
      }
    });
  }

  @override
  void dispose() {
    ApiClient.setImageServiceDegradedCallback(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final streamClient = ref.watch(streamChatNotifierProvider);

    // CRITICAL: Always wrap with StreamChat widget
    // Client is initialized immediately in provider, so it's always available
    // This ensures StreamChat is in the widget tree for ALL routes (including ChatScreen)
    // AND it's inside MaterialApp so Localizations is available
    return StreamChat(
      client: streamClient!,
      child: Column(
        children: [
          const ImageServiceDegradedBanner(),
          Expanded(child: widget.child ?? const SizedBox.shrink()),
        ],
      ),
    );
  }
}
