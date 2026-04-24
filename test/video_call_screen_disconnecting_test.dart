import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zztherapy/features/video/controllers/call_connection_controller.dart';
import 'package:zztherapy/features/video/screens/video_call_screen.dart';

void main() {
  testWidgets('shows deterministic transition UI while idle fallback is active', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          callConnectionControllerProvider.overrideWith((ref) {
            final controller = CallConnectionController(ref);
            controller.state = const CallConnectionState(
              phase: CallConnectionPhase.idle,
            );
            return controller;
          }),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/call',
            routes: [
              GoRoute(
                path: '/call',
                builder: (context, state) => const VideoCallScreen(),
              ),
              GoRoute(
                path: '/home',
                builder: (context, state) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('shows deterministic transition UI while disconnecting', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          callConnectionControllerProvider.overrideWith((ref) {
            final controller = CallConnectionController(ref);
            controller.state = const CallConnectionState(
              phase: CallConnectionPhase.disconnecting,
            );
            return controller;
          }),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/call',
            routes: [
              GoRoute(
                path: '/call',
                builder: (context, state) => const VideoCallScreen(),
              ),
              GoRoute(
                path: '/home',
                builder: (context, state) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
