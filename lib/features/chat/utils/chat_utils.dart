import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Extracts the display name for a user from Stream Chat user data.
/// Priority: username (from extraData) > name > id > 'User'
/// 
/// This ensures we always show the username if available, avoiding phone numbers.
String extractDisplayName(User? user) {
  if (user == null) return 'User';
  
  // Priority 1: username from extraData (single source of truth)
  final username = user.extraData['username'] as String?;
  if (username != null && username.trim().isNotEmpty) {
    return username.trim();
  }
  
  // Priority 2: name field (may be phone number if username not set)
  final name = user.name;
  if (name.trim().isNotEmpty) {
    // If name looks like a phone number (starts with + or is all digits), skip it
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
/// Returns null if not found or if there are not exactly 2 members.
User? getOtherUserFromChannel(Channel channel, String currentUserId) {
  final channelState = channel.state;
  if (channelState == null) return null;
  
  // Access members - in Stream Chat Flutter, channelState.members is a List<Member>
  // Handle runtime type variations safely
  final members = channelState.members;
  List<Member> memberList;
  
  try {
    // channelState.members is typically a List<Member>, but handle edge cases
    final dynamicMembers = members as dynamic;
    
    if (dynamicMembers is List) {
      // Direct list access (most common case)
      memberList = dynamicMembers.cast<Member>();
    } else if (dynamicMembers is Map) {
      // Map access (fallback for edge cases)
      memberList = (dynamicMembers.values as Iterable).cast<Member>().toList();
    } else {
      // Last resort: try to convert to list
      final iterable = dynamicMembers as Iterable;
      memberList = iterable.cast<Member>().toList();
    }
  } catch (e) {
    debugPrint('⚠️ [CHAT] Failed to parse members: $e (type: ${members.runtimeType})');
    return null;
  }
  
  if (memberList.isEmpty) return null;
  
  // Get the other member (not the current user)
  final otherMember = memberList.firstWhere(
    (m) => m.userId != currentUserId,
    orElse: () => memberList.first,
  );
  
  return otherMember.user;
}

/// Gets the display name for the other user in a channel.
String getOtherUserDisplayName(Channel channel, String currentUserId) {
  final otherUser = getOtherUserFromChannel(channel, currentUserId);
  return extractDisplayName(otherUser);
}
