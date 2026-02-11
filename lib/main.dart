import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'firebase_options.dart';
import 'app/router/app_router.dart';
import 'app/widgets/app_lifecycle_wrapper.dart';
import 'app/widgets/stream_chat_wrapper.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/chat/providers/stream_chat_provider.dart';
import 'features/video/widgets/incoming_call_listener.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  // Note: You'll need to add your firebase_options.dart file
  // Run: flutterfire configure
  try {
<<<<<<< HEAD
    await Firebase.initializeApp();
=======
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _firebaseInitialized = true;
>>>>>>> 6caedcda0209c58437b74b5a57398940c89ff7ed
    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    debugPrint('❌ Firebase initialization error: $e');
    debugPrint('⚠️  Please run: flutterfire configure');
    debugPrint('⚠️  App will continue but authentication will not work');
    // Continue anyway - will show error in UI
  }

  // ─── Initialize local notifications plugin ONCE, globally, early ───
  final localNotifications = FlutterLocalNotificationsPlugin();

  const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
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

  // Create the Android notification channel
  if (Platform.isAndroid) {
    const channel = AndroidNotificationChannel(
      'chat_messages',
      'Chat Messages',
      description: 'Notifications for new chat messages',
      importance: Importance.high,
    );
    await localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  debugPrint('✅ Local notifications plugin initialized globally');

  // Inject the single instance into PushNotificationService
  PushNotificationService().setNotificationsPlugin(localNotifications);

  // Register FCM background message handler (must be top-level function)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamChatWrapper(
      child: MaterialApp.router(
        title: 'Eazy Talks',
        theme: AppTheme.darkTheme,
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
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Helper widget to build StreamChat inside MaterialApp (where Localizations is available)
class _StreamChatBuilder extends ConsumerWidget {
  final Widget? child;

  const _StreamChatBuilder({this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamClient = ref.watch(streamChatNotifierProvider);
    
    // CRITICAL: Always wrap with StreamChat widget
    // Client is initialized immediately in provider, so it's always available
    // This ensures StreamChat is in the widget tree for ALL routes (including ChatScreen)
    // AND it's inside MaterialApp so Localizations is available
    return StreamChat(
      client: streamClient!,
      child: child ?? const SizedBox.shrink(),
    );
  }
}
