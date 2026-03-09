import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/creator_model.dart';
import '../../../shared/models/profile_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../admin/providers/admin_view_provider.dart';
import 'availability_provider.dart';
import '../../user/providers/user_availability_provider.dart';
import '../utils/creator_shuffle_utils.dart';

// Provider to fetch creators (for users)
// 🔥 FIX: Seeds creatorAvailabilityProvider with initial availability from API
final creatorsProvider = FutureProvider<List<CreatorModel>>((ref) async {
  try {
    debugPrint('🔄 [HOME] Fetching creators from API...');
    final apiClient = ApiClient();
    final response = await apiClient.get('/creator');
    
    if (response.statusCode == 200) {
      final responseData = response.data;
      
      // Check if response has the expected structure
      if (responseData['success'] == true && responseData['data'] != null) {
        final creatorsData = responseData['data']['creators'] as List?;
        
        if (creatorsData == null) {
          debugPrint('⚠️  [HOME] Response data.creators is null');
          return [];
        }
        
        final creators = creatorsData
            .map((json) => CreatorModel.fromJson(json as Map<String, dynamic>))
            .toList();
        
        debugPrint('✅ [HOME] Parsed ${creators.length} creator(s) from API');
        
        // 🔥 FIX: Seed creatorAvailabilityProvider with initial availability
        // from the API response (backed by Redis on the server).
        final apiAvailability = <String, CreatorAvailability>{};
        for (final creator in creators) {
          if (creator.firebaseUid != null) {
            apiAvailability[creator.firebaseUid!] = creator.availability == 'online'
                ? CreatorAvailability.online
                : CreatorAvailability.busy;
          }
        }
        ref.read(creatorAvailabilityProvider.notifier).seedFromApi(apiAvailability);
        
        return creators;
      } else {
        debugPrint('⚠️  [HOME] Response structure unexpected: success=${responseData['success']}, data=${responseData['data']}');
        return [];
      }
    } else {
      debugPrint('❌ [HOME] API returned non-200 status: ${response.statusCode}');
      return [];
    }
  } catch (e, stackTrace) {
    debugPrint('❌ [HOME] Error fetching creators: $e');
    debugPrint('   Stack trace: $stackTrace');
    return [];
  }
});

// Provider to fetch users (for creators)
final usersProvider = FutureProvider<List<UserProfileModel>>((ref) async {
  try {
    final apiClient = ApiClient();
    final response = await apiClient.get('/user/list');
    
    if (response.statusCode == 200) {
      final usersData = response.data['data']['users'] as List;
      final users = usersData
          .map((json) => UserProfileModel.fromJson(json as Map<String, dynamic>))
          .toList();
      
      // 🔥 FIX: Seed userAvailabilityProvider with initial availability
      // from the API response (backed by Redis on the server).
      final apiAvailability = <String, UserAvailability>{};
      for (final user in users) {
        if (user.firebaseUid != null) {
          apiAvailability[user.firebaseUid!] = user.availability == 'online'
              ? UserAvailability.online
              : UserAvailability.offline;
        }
      }
      ref.read(userAvailabilityProvider.notifier).seedFromApi(apiAvailability);
      
      return users;
    }
    print('❌ [HOME] Failed to fetch users: Status ${response.statusCode}');
    print('   Response: ${response.data}');
    return [];
  } catch (e) {
    print('❌ [HOME] Error fetching users: $e');
    rethrow; // Re-throw to show error in UI
  }
});

/// 🔥 BACKEND-AUTHORITATIVE Provider that returns ALL creators/users based on user role
final homeFeedProvider = Provider<List<dynamic>>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  
  if (user == null) {
    return [];
  }
  
  // If user is an admin, check their view mode preference
  if (user.role == 'admin') {
    final adminViewMode = ref.watch(adminViewModeProvider);
    final creatorsAsync = ref.watch(creatorsProvider);
    
    // Default to user view if not set
    if (adminViewMode == null || adminViewMode == AdminViewMode.user) {
      // Admin viewing as user: show ALL creators (sorted and shuffled)
      final availabilityMap = ref.watch(creatorAvailabilityProvider);
      return creatorsAsync.when(
        data: (creators) {
          // Sort and shuffle for admin user view as well
          return sortAndShuffleCreatorsByAvailability(
            creators,
            availabilityMap,
            user.id,
          );
        },
        loading: () => [],
        error: (_, __) => [],
      );
    } else {
      // Admin viewing as creator: show users
      final usersAsync = ref.watch(usersProvider);
      return usersAsync.when(
        data: (users) => users,
        loading: () => [],
        error: (_, __) => [],
      );
    }
  }
  
  // If user is a creator, show users
  if (user.role == 'creator') {
    final usersAsync = ref.watch(usersProvider);
    return usersAsync.when(
      data: (users) => users,
      loading: () => [],
      error: (_, __) => [],
    );
  }
  
  // If user is a regular user, show ALL creators.
  // Availability (online/busy) is managed via Socket.IO + Redis in real-time.
  final creatorsAsync = ref.watch(creatorsProvider);
  // Watch real-time availability for accurate sorting
  final availabilityMap = ref.watch(creatorAvailabilityProvider);
  
  return creatorsAsync.when(
    data: (creators) {
      // Sort and shuffle: online creators first, busy creators at bottom
      // Shuffling is seeded by user ID for consistent order per user session
      final sortedAndShuffled = sortAndShuffleCreatorsByAvailability(
        creators,
        availabilityMap,
        user.id,
      );
      
      final onlineCount = sortedAndShuffled
          .where((c) => c.firebaseUid != null &&
              (availabilityMap[c.firebaseUid] ?? 
               (c.availability == 'online' 
                   ? CreatorAvailability.online 
                   : CreatorAvailability.busy)) == CreatorAvailability.online)
          .length;
      
      debugPrint('✅ [HOME] Returning ${sortedAndShuffled.length} creator(s) - $onlineCount online, ${sortedAndShuffled.length - onlineCount} busy');
      return sortedAndShuffled;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});
