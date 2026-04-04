import 'user_message_mapper.dart';

/// Converts error strings (e.g. auth state) to user-safe messages.
/// Prefer [UserMessageMapper.userMessageFor] for catch-block objects.
class ErrorHandler {
  static String getHumanReadableError(String error) {
    return UserMessageMapper.fromString(error);
  }
}
