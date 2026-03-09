import '../../../shared/models/creator_model.dart';
import '../providers/availability_provider.dart';

/// Seeded random number generator for consistent shuffling
class SeededRandom {
  final int seed;
  int _state;

  SeededRandom(this.seed) : _state = seed;

  /// Generate next random integer in range [0, max)
  int nextInt(int max) {
    _state = (_state * 1103515245 + 12345) & 0x7fffffff;
    return _state % max;
  }

  /// Generate next random double in range [0.0, 1.0)
  double nextDouble() {
    _state = (_state * 1103515245 + 12345) & 0x7fffffff;
    return _state / 0x7fffffff;
  }
}

/// Shuffle a list using Fisher-Yates algorithm with seeded random
List<T> seededShuffle<T>(List<T> list, int seed) {
  final shuffled = List<T>.from(list);
  final random = SeededRandom(seed);
  
  for (int i = shuffled.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final temp = shuffled[i];
    shuffled[i] = shuffled[j];
    shuffled[j] = temp;
  }
  
  return shuffled;
}

/// Generate a seed from user ID for consistent shuffling per user
int generateSeedFromUserId(String userId) {
  // Convert user ID string to a numeric seed
  int hash = 0;
  for (int i = 0; i < userId.length; i++) {
    hash = ((hash << 5) - hash) + userId.codeUnitAt(i);
    hash = hash & hash; // Convert to 32-bit integer
  }
  return hash.abs();
}

/// Sort and shuffle creators by availability:
/// - Online creators first (shuffled within group)
/// - Busy creators at bottom (shuffled within group)
/// 
/// Uses real-time availability from creatorAvailabilityProvider for accurate status.
/// Shuffling is seeded by user ID to ensure consistent order per user session.
List<CreatorModel> sortAndShuffleCreatorsByAvailability(
  List<CreatorModel> creators,
  Map<String, CreatorAvailability> availabilityMap,
  String userId,
) {
  if (creators.isEmpty) return creators;

  // Separate creators into online and busy groups
  final onlineCreators = <CreatorModel>[];
  final busyCreators = <CreatorModel>[];

  for (final creator in creators) {
    // Use real-time availability if available, otherwise fall back to model's availability
    final availability = creator.firebaseUid != null
        ? (availabilityMap[creator.firebaseUid] ??
            (creator.availability == 'online'
                ? CreatorAvailability.online
                : CreatorAvailability.busy))
        : (creator.availability == 'online'
            ? CreatorAvailability.online
            : CreatorAvailability.busy);

    if (availability == CreatorAvailability.online) {
      onlineCreators.add(creator);
    } else {
      busyCreators.add(creator);
    }
  }

  // Generate seed from user ID for consistent shuffling
  final seed = generateSeedFromUserId(userId);

  // Shuffle each group independently
  final shuffledOnline = seededShuffle(onlineCreators, seed);
  // Use a different seed offset for busy creators to ensure different shuffle
  final shuffledBusy = seededShuffle(busyCreators, seed + 1);

  // Combine: online first, then busy
  return [...shuffledOnline, ...shuffledBusy];
}
