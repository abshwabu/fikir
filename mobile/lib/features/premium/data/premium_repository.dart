import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fikir/core/network/dio_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final premiumRepositoryProvider = Provider<PremiumRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return PremiumRepository(dio);
});

class PremiumPlan {
  const PremiumPlan({
    required this.id,
    required this.tier,
    required this.name,
    required this.durationDays,
    required this.priceEtb,
    required this.perks,
  });

  factory PremiumPlan.fromJson(Map<String, dynamic> json) {
    return PremiumPlan(
      id: json['id'] as String? ?? '',
      tier: json['tier'] as String? ?? 'plus',
      name: json['name'] as String? ?? '',
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 30,
      priceEtb: (json['price_etb'] as num?)?.toDouble() ?? 0.0,
      perks: (json['perks'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  final String id;
  final String tier;
  final String name;
  final int durationDays;
  final double priceEtb;
  final List<String> perks;
}

class CheckoutResult {
  const CheckoutResult({
    required this.reference,
    required this.checkoutUrl,
    required this.amount,
    required this.currency,
    required this.status,
  });

  factory CheckoutResult.fromJson(Map<String, dynamic> json) {
    return CheckoutResult(
      reference: json['reference'] as String? ?? '',
      checkoutUrl: json['checkout_url'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'ETB',
      status: json['status'] as String? ?? 'pending',
    );
  }

  final String reference;
  final String checkoutUrl;
  final double amount;
  final String currency;
  final String status;
}

class SubscriptionInfo {
  const SubscriptionInfo({
    required this.isActive,
    this.tier,
    this.planId,
    this.expiresAt,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return SubscriptionInfo(
      isActive: json['active'] as bool? ?? false,
      tier: json['tier'] as String?,
      planId: json['plan_id'] as String?,
      expiresAt: json['expires_at'] as String?,
    );
  }

  final bool isActive;
  final String? tier;
  final String? planId;
  final String? expiresAt;
}

class PremiumRepository {
  PremiumRepository(this._dio);

  final Dio _dio;

  Future<List<PremiumPlan>> getPlans() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/v1/plans');
      if (res.statusCode == 200 && res.data != null) {
        final list = res.data!['plans'] as List<dynamic>? ?? [];
        return list.map((e) => PremiumPlan.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      // Fallback default plans if network is offline
    }

    return const [
      PremiumPlan(
        id: 'plus_weekly',
        tier: 'plus',
        name: 'Fikir Plus Weekly',
        durationDays: 7,
        priceEtb: 99,
        perks: ['Unlimited Likes', 'Rewind', 'Hide Distance', '5 Super Likes/week'],
      ),
      PremiumPlan(
        id: 'plus_monthly',
        tier: 'plus',
        name: 'Fikir Plus Monthly',
        durationDays: 30,
        priceEtb: 299,
        perks: ['Unlimited Likes', 'Rewind', 'Hide Distance', '5 Super Likes/week'],
      ),
      PremiumPlan(
        id: 'gold_weekly',
        tier: 'gold',
        name: 'Fikir Gold Weekly',
        durationDays: 7,
        priceEtb: 199,
        perks: ['See Who Likes You', '1 Boost/week', '5 Super Likes/week', 'Diaspora Mode', 'Unlimited Likes'],
      ),
      PremiumPlan(
        id: 'gold_monthly',
        tier: 'gold',
        name: 'Fikir Gold Monthly',
        durationDays: 30,
        priceEtb: 499,
        perks: ['See Who Likes You', '1 Boost/week', '5 Super Likes/week', 'Diaspora Mode', 'Unlimited Likes'],
      ),
      PremiumPlan(
        id: 'gold_quarterly',
        tier: 'gold',
        name: 'Fikir Gold 3-Months',
        durationDays: 90,
        priceEtb: 1199,
        perks: ['See Who Likes You', '1 Boost/week', '5 Super Likes/week', 'Diaspora Mode', 'Unlimited Likes', 'Best Value Save 20%'],
      ),
    ];
  }

  Future<CheckoutResult> initiateCheckout({
    required String planId,
    required String paymentMethod,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/payments/checkout',
      data: {
        'plan_id': planId,
        'payment_method': paymentMethod,
        'provider': 'chapa',
        'return_url': 'fikir://payment/return',
      },
    );

    if (res.data != null) {
      return CheckoutResult.fromJson(res.data!);
    }
    throw Exception('Failed to initiate checkout');
  }

  Future<String> pollPaymentStatus(String reference) async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/payments/$reference');
    if (res.data != null) {
      return res.data!['status'] as String? ?? 'pending';
    }
    return 'pending';
  }

  Future<SubscriptionInfo> getMySubscription() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/v1/me/subscription');
      if (res.data != null) {
        return SubscriptionInfo.fromJson(res.data!);
      }
    } catch (_) {}
    return const SubscriptionInfo(isActive: false);
  }

  Future<Map<String, dynamic>?> exportUserData() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/me/export');
    return res.data;
  }
}
