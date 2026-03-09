import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
// OTP screen - commented out (phone login disabled, using Google Sign-In only)
// import '../../features/auth/screens/otp_screen.dart';
import '../../features/onboarding/screens/gender_selection_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/favorite_creators_screen.dart';
import '../../features/recent/screens/recent_screen.dart';
import '../../features/account/screens/account_screen.dart';
import '../../features/account/screens/account_settings_screen.dart';
import '../../features/account/screens/blocked_buddies_screen.dart';
import '../../features/account/screens/delete_account_screen.dart';
import '../../features/account/screens/edit_profile_screen.dart';
import '../../features/wallet/screens/wallet_screen.dart';
import '../../features/wallet/screens/payment_status_screen.dart';
import '../../features/wallet/screens/transactions_screen.dart';
import '../../features/account/screens/help_support_screen.dart';
import '../../features/creator/screens/creator_tasks_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../../features/video/screens/video_call_screen.dart';
import '../../features/withdrawal/screens/withdrawal_screen.dart';
import '../../features/support/screens/support_screen.dart';
import '../../features/support/screens/payment_complaint_screen.dart';
import '../../features/wallet/models/transaction_model.dart';

/// Global GoRouter instance
/// 
/// Use this for navigation from anywhere (overlays, lifecycle handlers, Stream callbacks)
/// Do NOT use BuildContext.push() from outside widget tree - it will fail
/// 
/// Example:
/// ```dart
/// appRouter.push('/call', extra: call);
/// ```
final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
          // OTP route - redirect to login (phone login disabled, Google Sign-In only)
          GoRoute(
            path: '/otp',
            redirect: (_, __) => '/login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/gender',
            builder: (context, state) => const GenderSelectionScreen(),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/home/favorites',
            builder: (context, state) => const FavoriteCreatorsScreen(),
          ),
    GoRoute(
      path: '/recent',
      builder: (context, state) => const RecentScreen(),
    ),
    GoRoute(
      path: '/chat-list',
      builder: (context, state) => const ChatListScreen(),
    ),
          GoRoute(
            path: '/account',
            builder: (context, state) => const AccountScreen(),
          ),
          GoRoute(
            path: '/edit-profile',
            builder: (context, state) => const EditProfileScreen(),
          ),
          GoRoute(
            path: '/wallet',
            builder: (context, state) => const WalletScreen(),
          ),
          GoRoute(
            path: '/wallet/payment-status',
            builder: (context, state) {
              final payment = state.uri.queryParameters['payment'] ?? '';
              final isSuccess = payment == 'success';
              final coinsAdded =
                  int.tryParse(state.uri.queryParameters['coinsAdded'] ?? '0') ??
                      0;
              final message = state.uri.queryParameters['message'];

              return PaymentStatusScreen(
                isSuccess: isSuccess,
                coinsAdded: coinsAdded,
                message: message,
              );
            },
          ),
          GoRoute(
            path: '/transactions',
            builder: (context, state) => const TransactionsScreen(),
          ),
          GoRoute(
            path: '/help-support',
            builder: (context, state) => const HelpSupportScreen(),
          ),
          GoRoute(
            path: '/account/settings',
            builder: (context, state) => const AccountSettingsScreen(),
          ),
          GoRoute(
            path: '/account/settings/blocked-buddies',
            builder: (context, state) => const BlockedBuddiesScreen(),
          ),
          GoRoute(
            path: '/account/settings/delete-account',
            builder: (context, state) => const DeleteAccountScreen(),
          ),
          GoRoute(
            path: '/creator/tasks',
            builder: (context, state) {
              // 🔒 PHASE T2: Role guard at route level (backend also checks, but never trust just UI)
              // This is handled in the screen itself, but we can add a redirect here too
              return const CreatorTasksScreen();
            },
          ),
          GoRoute(
            path: '/creator/withdraw',
            builder: (context, state) => const WithdrawalScreen(),
          ),
          GoRoute(
            path: '/support',
            builder: (context, state) => const SupportScreen(),
          ),
          GoRoute(
            path: '/support/payment-complaint',
            builder: (context, state) {
              final transaction = state.extra as TransactionModel?;
              if (transaction == null) {
                return const Scaffold(
                  body: Center(child: Text('Missing transaction details')),
                );
              }
              return PaymentComplaintScreen(transaction: transaction);
            },
          ),
    GoRoute(
      path: '/chat/:channelId',
      builder: (context, state) {
        final channelId = state.pathParameters['channelId'];
        if (channelId == null) {
          return const Scaffold(
            body: Center(child: Text('Missing channel ID')),
          );
        }
        return ChatScreen(channelId: channelId);
      },
    ),
    GoRoute(
      path: '/call',
      builder: (context, state) {
        // VideoCallScreen is a pure renderer driven by CallConnectionController.
        // Navigation here is triggered ONLY after phase == connected.
        return const VideoCallScreen();
      },
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Error: ${state.error}'),
    ),
  ),
);
