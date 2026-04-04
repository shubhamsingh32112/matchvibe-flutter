import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Extracts the display name for a user from Stream Chat user data.
///
/// Creators/admins: prefer Stream [User.name] (synced to public creator name on the server).
/// Regular users: prefer [username] in extraData, then non-phone [name], then id.
String extractDisplayName(User? user) {
  if (user == null) return 'User';

  final appRole = user.extraData['appRole'] as String?;
  final isCreatorLike =
      appRole == 'creator' || appRole == 'admin';

  if (isCreatorLike) {
    final streamName = user.name.trim();
    if (streamName.isNotEmpty &&
        !streamName.startsWith('+') &&
        !RegExp(r'^\d+$').hasMatch(streamName)) {
      return streamName;
    }
  }

  // Regular users (and creator fallback): username from extraData
  final username = user.extraData['username'] as String?;
  if (username != null && username.trim().isNotEmpty) {
    return username.trim();
  }

  // Name field (may be phone number if username not set)
  final name = user.name;
  if (name.trim().isNotEmpty) {
    final trimmedName = name.trim();
    if (!trimmedName.startsWith('+') && !RegExp(r'^\d+$').hasMatch(trimmedName)) {
      return trimmedName;
    }
  }
  
  // Priority 3: user ID (fallback)
  if (user.id.isNotEmpty) {
    return user.id;
  }
  
  return 'User';
}

/// Extracts the other user from a channel (the one that's not the current user).
/// Returns null if not found, if there are not exactly 2 members, or if the
/// "other" user would be the current user (prevents showing own name).
///
/// BUG FIX: Previously, orElse: () => memberList.first returned the current user
/// when only one member was in the list (pagination/sync delay), causing users
/// to see their own name instead of the creator's.
User? getOtherUserFromChannel(Channel channel, String currentUserId) {
  final channelState = channel.state;
  if (channelState == null) return null;

  // Access members - Stream Chat Flutter uses List<Member>
  final members = channelState.members;
  if (members.isEmpty) return null;

  final memberList = List<Member>.from(members);

  if (memberList.isEmpty) return null;

  // Find the member that is NOT the current user.
  // CRITICAL: Do NOT use orElse that returns memberList.first — that would
  // return the current user when only one member exists, causing "own name" bug.
  Member? otherMember;
  try {
    otherMember = memberList.firstWhere((m) => m.userId != currentUserId);
  } catch (_) {
    // No match — all members might be current user (sync issue)
    debugPrint('⚠️ [CHAT] No other member found; members may be incomplete');
    return null;
  }

  final otherUser = otherMember.user;
  if (otherUser == null) return null;

  // Defensive: never return the current user as "other"
  if (otherUser.id == currentUserId) {
    debugPrint('⚠️ [CHAT] getOtherUserFromChannel would return current user; rejecting');
    return null;
  }

  return otherUser;
}

/// Gets the display name for the other user in a channel.
String getOtherUserDisplayName(Channel channel, String currentUserId) {
  final otherUser = getOtherUserFromChannel(channel, currentUserId);
  return extractDisplayName(otherUser);
}
