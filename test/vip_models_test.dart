import 'package:flutter_test/flutter_test.dart';
import 'package:zztherapy/features/vip/models/vip_models.dart';

void main() {
  group('VipPlansResponse', () {
    test('parses three-plan payload in display order', () {
      final response = VipPlansResponse.fromJson({
        'plans': [
          {
            'planId': 'vip_6months',
            'label': '6 Months',
            'durationDays': 180,
            'priceInr': 2199,
            'monthlyEquivalentInr': 367,
            'isActive': true,
          },
          {
            'planId': 'vip_yearly',
            'label': '12 Months',
            'durationDays': 365,
            'priceInr': 3999,
            'monthlyEquivalentInr': 333,
            'savingsLabel': 'Save ₹1,989 / year',
            'badge': 'bestValue',
            'isActive': true,
          },
          {
            'planId': 'vip_monthly',
            'label': '1 Month',
            'durationDays': 30,
            'priceInr': 499,
            'monthlyEquivalentInr': 499,
            'badge': 'mostPopular',
            'isActive': true,
          },
        ],
        'perks': {
          'freeMomentsPerDay': 10,
          'rechargeDiscountPercent': 10,
          'momentDiscountPercent': 10,
        },
      });

      expect(response.plans, hasLength(3));
      expect(response.plans.first.planId, 'vip_6months');
      expect(response.plans.last.planId, 'vip_monthly');
      expect(response.defaultPlan?.planId, 'vip_monthly');
    });

    test('parses legacy single-plan payload', () {
      final response = VipPlansResponse.fromJson({
        'planId': 'vip_monthly',
        'durationDays': 30,
        'priceInr': 499,
        'isActive': true,
        'freeMomentsPerDay': 10,
        'rechargeDiscountPercent': 10,
        'momentDiscountPercent': 10,
      });

      expect(response.plans, hasLength(1));
      expect(response.plans.first.planId, 'vip_monthly');
    });
  });
}
