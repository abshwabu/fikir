import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/design/widgets/gradient_button.dart';
import 'package:fikir/features/discover/domain/discovery_card.dart';
import 'package:fikir/features/discover/domain/swipe_action.dart';
import 'package:fikir/features/discover/presentation/discovery_notifier.dart';
import 'package:fikir/features/discover/presentation/widgets/action_buttons_row.dart';
import 'package:fikir/features/discover/presentation/widgets/candidate_detail_sheet.dart';
import 'package:fikir/features/discover/presentation/widgets/discovery_filter_sheet.dart';
import 'package:fikir/features/discover/presentation/widgets/match_celebration_dialog.dart';
import 'package:fikir/features/discover/presentation/widgets/swipeable_card_stack.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final GlobalKey<SwipeableCardStackState> _stackKey = GlobalKey<SwipeableCardStackState>();
  bool _showingMatchDialog = false;
  bool _showingLimitDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discoveryNotifierProvider.notifier).precacheUpcoming(context);
    });
  }

  void _listenForStateEvents() {
    ref.listen(discoveryNotifierProvider, (previous, next) {
      // 1. Precache images on deck update
      if (previous?.cards != next.cards && next.cards.isNotEmpty) {
        ref.read(discoveryNotifierProvider.notifier).precacheUpcoming(context);
      }

      // 2. Surface match celebration
      if (next.latestMatch != null && !_showingMatchDialog) {
        _showingMatchDialog = true;
        final matchedCard = next.latestMatch!.matchedProfile ??
            (next.history.isNotEmpty ? next.history.first : null);

        if (matchedCard != null) {
          MatchCelebrationDialog.show(
            context,
            matchedCandidate: matchedCard,
            matchId: next.latestMatch!.matchId,
            onKeepSwiping: () {
              _showingMatchDialog = false;
              ref.read(discoveryNotifierProvider.notifier).clearLatestMatch();
            },
          );
        } else {
          _showingMatchDialog = false;
          ref.read(discoveryNotifierProvider.notifier).clearLatestMatch();
        }
      }

      // 3. Surface daily limit dialog
      if (next.isLimitReached && !_showingLimitDialog) {
        _showingLimitDialog = true;
        _showDailyLimitSheet(next.dailyResetTime);
      }
    });
  }

  void _showDailyLimitSheet(DateTime? resetTime) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final remaining = resetTime != null && resetTime.isAfter(now)
        ? resetTime.difference(now)
        : const Duration(hours: 12);
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final timeStr = '${hours}h ${minutes}m';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FikirColors.gold.withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: FikirColors.gold,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n?.dailyLimitTitle ?? "You're Out of Likes!",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n?.dailyLimitDesc ??
                    'You have reached your daily swipe limit. Get unlimited likes with Fikir Gold or wait for reset.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  l10n?.resetsIn(timeStr) ?? 'Resets in $timeStr',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 24),
              GradientButton(
                text: l10n?.getFikirGold ?? 'Get Fikir Gold',
                icon: const Icon(Icons.star_rounded, color: Colors.white),
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      _showingLimitDialog = false;
      ref.read(discoveryNotifierProvider.notifier).dismissLimitModal();
    });
  }

  void _openFilters() {
    final state = ref.read(discoveryNotifierProvider);
    DiscoveryFilterSheet.show(
      context,
      initialFilters: state.filters,
      onApply: (newFilters) {
        ref.read(discoveryNotifierProvider.notifier).updateFilters(newFilters);
      },
    );
  }

  void _openProfileDetail(DiscoveryProfileCard card) {
    CandidateDetailSheet.show(
      context,
      candidate: card,
      onLike: () {
        _stackKey.currentState?.triggerSwipe(SwipeDirection.like);
      },
      onNope: () {
        _stackKey.currentState?.triggerSwipe(SwipeDirection.nope);
      },
      onSuperLike: () {
        _stackKey.currentState?.triggerSwipe(SwipeDirection.superLike);
      },
      onReport: (reason) {
        ref.read(discoveryNotifierProvider.notifier).reportUser(
              targetId: card.userId,
              reason: reason,
            );
      },
      onBlock: () {
        ref.read(discoveryNotifierProvider.notifier).blockUser(
              targetId: card.userId,
              reason: 'User blocked from discovery profile',
            );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _listenForStateEvents();
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(discoveryNotifierProvider);
    final notifier = ref.read(discoveryNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => FikirColors.primaryGradient.createShader(bounds),
              child: const Icon(
                Icons.local_fire_department_rounded,
                size: 28,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              l10n?.appName ?? 'Fikir',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: l10n?.discoverySettings ?? 'Discovery Settings',
            onPressed: _openFilters,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Location Services Warning Banner (if disabled)
            if (state.isLocationDisabled) _buildLocationWarningBanner(l10n),

            // Card stack or Empty/Loading state
            Expanded(
              child: state.isLoading && state.cards.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : state.hasCards
                      ? SwipeableCardStack(
                          key: _stackKey,
                          cards: state.cards,
                          onSwipe: notifier.swipe,
                          onInfoTap: _openProfileDetail,
                        )
                      : RefreshIndicator(
                          onRefresh: notifier.refreshDeck,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.65,
                              child: _buildEmptyDeckState(l10n),
                            ),
                          ),
                        ),
            ),

            // Action Buttons Row (Active when cards are present)
            if (state.hasCards)
              ActionButtonsRow(
                canRewind: state.canRewind,
                onRewind: notifier.rewind,
                onNope: () => _stackKey.currentState?.triggerSwipe(SwipeDirection.nope),
                onSuperLike: () =>
                    _stackKey.currentState?.triggerSwipe(SwipeDirection.superLike),
                onLike: () => _stackKey.currentState?.triggerSwipe(SwipeDirection.like),
                onBoost: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Boost activated! Your profile is prioritized in Addis.',
                      ),
                      backgroundColor: FikirColors.boost,
                    ),
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationWarningBanner(AppLocalizations? l10n) {
    return Container(
      color: Colors.amber.shade800,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.location_off_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n?.locationDisabledTitle ?? 'Location Services Needed',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(discoveryNotifierProvider.notifier)
                  .setLocationDisabled(false);
            },
            child: Text(
              l10n?.enableGps ?? 'Enable GPS',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDeckState(AppLocalizations? l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FikirColors.primaryCoral.withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.person_search_rounded,
                size: 72,
                color: FikirColors.primaryCoral,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n?.noMoreProfiles ?? 'No more profiles nearby',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              l10n?.noMoreProfilesDesc ??
                  'Expand your distance or age preferences to meet more people.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: FikirColors.primaryCoral,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              icon: const Icon(Icons.tune_rounded, size: 20),
              onPressed: _openFilters,
              label: Text(
                l10n?.expandPreferences ?? 'Expand Preferences',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
