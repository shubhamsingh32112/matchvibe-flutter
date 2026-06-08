import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vip_models.dart';
import '../services/vip_api_service.dart';

final vipApiServiceProvider = Provider<VipApiService>((ref) => VipApiService());

final vipPlansProvider = FutureProvider<VipPlansResponse>((ref) async {
  return ref.read(vipApiServiceProvider).fetchPlans();
});

/// Legacy provider — maps multi-plan response to single [VipPlan].
final vipPlanProvider = FutureProvider<VipPlan>((ref) async {
  final response = await ref.watch(vipPlansProvider.future);
  return VipPlan.fromPlansResponse(response);
});

final vipStatusProvider = FutureProvider<VipStatus>((ref) async {
  return ref.read(vipApiServiceProvider).fetchStatus();
});
