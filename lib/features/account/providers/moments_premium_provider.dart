import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/moments_premium_models.dart';
import '../services/moments_premium_api_service.dart';

final momentsPremiumApiServiceProvider = Provider<MomentsPremiumApiService>(
  (ref) => MomentsPremiumApiService(),
);

final momentsPremiumPlansProvider = FutureProvider<MomentsPremiumPlansResponse>(
  (ref) async {
    return ref.read(momentsPremiumApiServiceProvider).fetchPlans();
  },
);

final momentsPremiumStatusProvider = FutureProvider<MomentsPremiumStatus>(
  (ref) async {
    return ref.read(momentsPremiumApiServiceProvider).fetchStatus();
  },
);
