import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds a pending toast message to show on the home screen.
///
/// When the creator doesn't pick up within 15s, we navigate to home and set
/// this to trigger a snackbar: "Creator is busy".
final creatorBusyToastProvider = StateProvider<String?>((ref) => null);
