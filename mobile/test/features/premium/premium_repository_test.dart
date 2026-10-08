import 'package:dio/dio.dart';
import 'package:fikir/features/premium/data/premium_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class MockDioAdapter implements HttpClientAdapter {
  MockDioAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('Premium Models & Serialization', () {
    test('PremiumPlan.fromJson parses attributes correctly', () {
      final json = {
        'id': 'gold_monthly',
        'tier': 'gold',
        'name': 'Fikir Gold Monthly',
        'duration_days': 30,
        'price_etb': 499.0,
        'perks': ['See Who Likes You', 'Unlimited Likes'],
      };

      final plan = PremiumPlan.fromJson(json);

      expect(plan.id, equals('gold_monthly'));
      expect(plan.tier, equals('gold'));
      expect(plan.name, equals('Fikir Gold Monthly'));
      expect(plan.durationDays, equals(30));
      expect(plan.priceEtb, equals(499.0));
      expect(plan.perks, contains('See Who Likes You'));
    });

    test('CheckoutResult.fromJson parses checkout response', () {
      final json = {
        'reference': 'fikir_tx_12345',
        'checkout_url': 'https://checkout.chapa.co/checkout/payment/fikir_tx_12345',
        'amount': 499.0,
        'currency': 'ETB',
        'status': 'pending',
      };

      final checkout = CheckoutResult.fromJson(json);

      expect(checkout.reference, equals('fikir_tx_12345'));
      expect(checkout.checkoutUrl, startsWith('https://checkout.chapa.co'));
      expect(checkout.amount, equals(499.0));
      expect(checkout.currency, equals('ETB'));
      expect(checkout.status, equals('pending'));
    });

    test('SubscriptionInfo.fromJson parses active subscription', () {
      final json = {
        'active': true,
        'tier': 'gold',
        'plan_id': 'gold_monthly',
        'expires_at': '2026-11-08T00:00:00Z',
      };

      final sub = SubscriptionInfo.fromJson(json);

      expect(sub.isActive, isTrue);
      expect(sub.tier, equals('gold'));
      expect(sub.planId, equals('gold_monthly'));
      expect(sub.expiresAt, equals('2026-11-08T00:00:00Z'));
    });
  });

  group('PremiumRepository Offline Fallback', () {
    test('getPlans returns default ETB plans when backend is unreachable', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockDioAdapter((options) async {
        throw DioException(
          requestOptions: options,
          error: 'Connection refused',
          type: DioExceptionType.connectionError,
        );
      });

      final repo = PremiumRepository(dio);
      final plans = await repo.getPlans();

      expect(plans, isNotEmpty);
      expect(plans.any((p) => p.tier == 'plus'), isTrue);
      expect(plans.any((p) => p.tier == 'gold'), isTrue);
      final goldMonthly = plans.firstWhere((p) => p.id == 'gold_monthly');
      expect(goldMonthly.priceEtb, equals(499.0));
    });

    test('getMySubscription returns inactive subscription on error', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockDioAdapter((options) async {
        throw DioException(
          requestOptions: options,
          error: 'Unauthorized',
          type: DioExceptionType.badResponse,
        );
      });

      final repo = PremiumRepository(dio);
      final sub = await repo.getMySubscription();

      expect(sub.isActive, isFalse);
    });
  });
}
