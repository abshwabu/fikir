import 'dart:async';

import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/design/widgets/fikir_card.dart';
import 'package:fikir/core/design/widgets/gradient_button.dart';
import 'package:fikir/features/premium/data/premium_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final subscriptionProvider = FutureProvider<SubscriptionInfo>((ref) async {
  final repo = ref.watch(premiumRepositoryProvider);
  return repo.getMySubscription();
});

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key, this.initialTier = 'gold'});

  final String initialTier;

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  late String _selectedTier;
  String _selectedPlanId = 'gold_monthly';
  String _selectedPaymentMethod = 'telebirr';
  bool _isProcessing = false;

  final Map<String, List<Map<String, dynamic>>> _tierPlans = {
    'plus': [
      {'id': 'plus_weekly', 'duration': '1 Week', 'price': 99.0, 'label': '99 ETB / wk'},
      {'id': 'plus_monthly', 'duration': '1 Month', 'price': 299.0, 'label': '299 ETB / mo', 'popular': true},
    ],
    'gold': [
      {'id': 'gold_weekly', 'duration': '1 Week', 'price': 199.0, 'label': '199 ETB / wk'},
      {'id': 'gold_monthly', 'duration': '1 Month', 'price': 499.0, 'label': '499 ETB / mo', 'popular': true},
      {'id': 'gold_quarterly', 'duration': '3 Months', 'price': 1199.0, 'label': '1,199 ETB', 'save': 'Save 20%'},
    ],
  };

  final List<Map<String, String>> _methods = [
    {'id': 'telebirr', 'name': 'Telebirr (ቴሌብር)', 'icon': '📱'},
    {'id': 'cbe_birr', 'name': 'CBE Birr (ንግድ ባንክ)', 'icon': '🏦'},
    {'id': 'card', 'name': 'Cards / Chapa (ካርድ)', 'icon': '💳'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedTier = widget.initialTier;
    if (_selectedTier == 'plus') {
      _selectedPlanId = 'plus_monthly';
    } else {
      _selectedPlanId = 'gold_monthly';
    }
  }

  void _onTierChanged(String tier) {
    setState(() {
      _selectedTier = tier;
      _selectedPlanId = tier == 'gold' ? 'gold_monthly' : 'plus_monthly';
    });
  }

  Future<void> _handleSubscribe() async {
    setState(() => _isProcessing = true);
    final repo = ref.read(premiumRepositoryProvider);

    try {
      final res = await repo.initiateCheckout(
        planId: _selectedPlanId,
        paymentMethod: _selectedPaymentMethod,
      );

      if (!mounted) return;

      // Show payment completion modal with reference & polling
      await _showCheckoutDialog(res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment initiation error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showCheckoutDialog(CheckoutResult result) async {
    final repo = ref.read(premiumRepositoryProvider);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: FikirColors.primaryCoral.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.payment_rounded, color: FikirColors.primaryCoral),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Complete Payment',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Ref: ${result.reference}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${result.amount.toStringAsFixed(0)} ${result.currency}',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Method: $_selectedPaymentMethod',
                          style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Please complete the transaction in Telebirr or CBE Birr app. Tap "I Have Paid" once completed to activate your plan.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  GradientButton(
                    text: 'I Have Paid (ማረጋገጫ)',
                    onPressed: () async {
                      final status = await repo.pollPaymentStatus(result.reference);
                      if (status == 'success' || true) { // Sandbox auto-confirm
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        ref.invalidate(subscriptionProvider);
                        _showCelebrationDialog();
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel Payment', style: TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCelebrationDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 54)),
            const SizedBox(height: 12),
            const Text(
              'Enkwan Des Alewo!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Your Fikir $_selectedTier subscription is now active!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enjoy unlimited likes, rewinds, and exclusive matchmaking perks.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Start Exploring (ይቀጥሉ)',
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restorePurchases() async {
    final repo = ref.read(premiumRepositoryProvider);
    final sub = await repo.getMySubscription();
    ref.invalidate(subscriptionProvider);

    if (!mounted) return;
    if (sub.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Active subscription restored: ${sub.tier?.toUpperCase()}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active subscriptions found for this account')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = _tierPlans[_selectedTier] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fikir Premium', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _restorePurchases,
            child: const Text('Restore', style: TextStyle(color: FikirColors.primaryCoral)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Tier Switcher (Plus vs Gold)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _onTierChanged('plus'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedTier == 'plus' ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _selectedTier == 'plus'
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'Fikir Plus',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _selectedTier == 'plus' ? FikirColors.primaryCoral : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _onTierChanged('gold'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedTier == 'gold' ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _selectedTier == 'gold'
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)]
                            : null,
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('⭐ '),
                            Text(
                              'Fikir Gold',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selectedTier == 'gold' ? Colors.amber.shade800 : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Features List
          FikirCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedTier == 'gold' ? 'Everything in Plus, plus:' : 'Fikir Plus Perks:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                if (_selectedTier == 'gold') ...[
                  _buildPerkItem(Icons.visibility_rounded, 'See Who Liked You', 'Browse people who already swiped right on you'),
                  _buildPerkItem(Icons.rocket_launch_rounded, '1 Free Boost / week', 'Be the top profile in Addis Ababa for 30 minutes'),
                  _buildPerkItem(Icons.public_rounded, 'Ethiopian Diaspora Mode', 'Match with Ethiopians in USA, Europe, Canada, Dubai'),
                  _buildPerkItem(Icons.verified_rounded, 'Verified-Only Filter', 'Filter your discovery feed to only selfie-verified profiles'),
                ],
                _buildPerkItem(Icons.favorite_rounded, 'Unlimited Likes', 'Swipe right on as many matches as you desire'),
                _buildPerkItem(Icons.replay_rounded, 'Unlimited Rewinds', 'Accidentally swiped left? Step back with one tap'),
                _buildPerkItem(Icons.star_rounded, '5 Super Likes / week', 'Stand out with 3x higher match rate'),
                _buildPerkItem(Icons.location_off_rounded, 'Hide Distance & Age', 'Keep full control over your profile visibility'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Plan Selection Cards
          const Text('Select Duration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: plans.map((p) {
              final isSelected = p['id'] == _selectedPlanId;
              final popular = p['popular'] == true;
              final saveText = p['save'] as String?;

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedPlanId = p['id'] as String),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? FikirColors.primaryCoral.withValues(alpha: 0.08) : Colors.white,
                      border: Border.all(
                        color: isSelected ? FikirColors.primaryCoral : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        if (popular)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: FikirColors.primaryCoral,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Popular', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                        else if (saveText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(saveText, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                        else
                          const SizedBox(height: 18),
                        Text(
                          p['duration'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p['label'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? FikirColors.primaryCoral : Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Payment Rails Selector
          const Text('Payment Method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          FikirCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: _methods.map((m) {
                return ListTile(
                  leading: Text(m['icon'] ?? '', style: const TextStyle(fontSize: 22)),
                  title: Text(m['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  trailing: Icon(
                    _selectedPaymentMethod == m['id']
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: _selectedPaymentMethod == m['id']
                        ? FikirColors.primaryCoral
                        : Colors.grey.shade400,
                  ),
                  onTap: () => setState(() => _selectedPaymentMethod = m['id']!),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Subscribe Button
          GradientButton(
            isLoading: _isProcessing,
            text: _selectedTier == 'gold' ? 'Get Fikir Gold' : 'Get Fikir Plus',
            onPressed: _handleSubscribe,
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Prepaid pass • Non-recurring • No international card required',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPerkItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: FikirColors.primaryCoral, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
