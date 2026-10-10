import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fikir/core/utils/image_cache_manager.dart';
import 'package:fikir/features/discover/data/discovery_repository.dart';
import 'package:fikir/features/discover/data/swipe_repository.dart';
import 'package:fikir/features/discover/domain/discovery_filters.dart';
import 'package:fikir/features/discover/domain/discovery_state.dart';
import 'package:fikir/features/discover/domain/swipe_action.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  DiscoveryNotifier({
    required DiscoveryRepository discoveryRepo,
    required SwipeRepository swipeRepo,
  })  : _discoveryRepo = discoveryRepo,
        _swipeRepo = swipeRepo,
        super(
          DiscoveryState(
            dailyResetTime: DateTime.now().add(const Duration(hours: 18)),
          ),
        ) {
    _initMatchSubscription();
    loadDeck();
  }

  final DiscoveryRepository _discoveryRepo;
  final SwipeRepository _swipeRepo;
  StreamSubscription<SwipeResult>? _matchSub;

  void _initMatchSubscription() {
    _matchSub = _swipeRepo.matchStream.listen((matchResult) {
      state = state.copyWith(latestMatch: matchResult);
    });
  }

  @override
  void dispose() {
    _matchSub?.cancel();
    super.dispose();
  }

  Future<void> loadDeck() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final deck = await _discoveryRepo.fetchDeck(
        filters: state.filters,
      );
      state = state.copyWith(
        cards: deck,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> refreshDeck() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final deck = await _discoveryRepo.fetchDeck(
        filters: state.filters,
      );
      state = state.copyWith(
        cards: deck,
        history: [],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _refillDeckIfNeeded() async {
    if (state.cards.length >= 5 || state.isRefilling) return;

    state = state.copyWith(isRefilling: true);
    try {
      final moreCards = await _discoveryRepo.fetchDeck(
        filters: state.filters,
      );

      // Deduplicate cards against remaining deck and history
      final existingIds = {
        ...state.cards.map((c) => c.userId),
        ...state.history.map((c) => c.userId),
      };

      final newUniqueCards = moreCards.where((c) => !existingIds.contains(c.userId)).toList();

      state = state.copyWith(
        cards: [...state.cards, ...newUniqueCards],
        isRefilling: false,
      );
    } catch (_) {
      state = state.copyWith(isRefilling: false);
    }
  }

  void precacheUpcoming(BuildContext context) {
    // Precache the next 3 cards' primary photo
    final candidates = state.cards.take(3);
    for (final candidate in candidates) {
      if (candidate.primaryPhotoUrl.startsWith('http://') ||
          candidate.primaryPhotoUrl.startsWith('https://')) {
        precacheImage(
          CachedNetworkImageProvider(
            candidate.primaryPhotoUrl,
            cacheManager: FikirImageCacheManager.instance,
          ),
          context,
        );
      }
      // Lazily precache 2nd photo if present
      if (candidate.photos.length > 1 &&
          (candidate.photos[1].url.startsWith('http://') ||
              candidate.photos[1].url.startsWith('https://'))) {
        precacheImage(
          CachedNetworkImageProvider(
            candidate.photos[1].url,
            cacheManager: FikirImageCacheManager.instance,
          ),
          context,
        );
      }
    }
  }

  Future<void> swipe(SwipeDirection direction) async {
    if (state.cards.isEmpty) return;

    // Check daily limit for like/superLike
    if ((direction == SwipeDirection.like || direction == SwipeDirection.superLike) &&
        state.dailyLikesRemaining <= 0) {
      state = state.copyWith(isLimitReached: true);
      return;
    }

    final topCard = state.cards.first;
    final remainingCards = state.cards.sublist(1);
    final updatedHistory = [topCard, ...state.history];
    final updatedLikes = (direction == SwipeDirection.like || direction == SwipeDirection.superLike)
        ? state.dailyLikesRemaining - 1
        : state.dailyLikesRemaining;

    // 1. Optimistically animate/remove card immediately
    state = state.copyWith(
      cards: remainingCards,
      history: updatedHistory,
      dailyLikesRemaining: updatedLikes,
    );

    // 2. Persist to outbox queue & send via backend in background
    unawaited(
      _swipeRepo.recordSwipe(
        targetUserId: topCard.userId,
        direction: direction,
        candidate: topCard,
      ),
    );

    // 3. Refill if below threshold
    if (remainingCards.length < 5) {
      unawaited(_refillDeckIfNeeded());
    }
  }

  Future<void> rewind() async {
    if (state.history.isEmpty) return;

    final lastCard = state.history.first;
    final remainingHistory = state.history.sublist(1);

    // Optimistically restore card back to front of deck
    state = state.copyWith(
      cards: [lastCard, ...state.cards],
      history: remainingHistory,
    );

    await _swipeRepo.rewind(targetUserId: lastCard.userId);
  }

  Future<void> updateFilters(DiscoveryFilters newFilters) async {
    state = state.copyWith(filters: newFilters, isLoading: true);
    await _discoveryRepo.updateFilters(newFilters);
    await refreshDeck();
  }

  Future<void> reportUser({
    required String targetId,
    required String reason,
    String details = '',
  }) async {
    // Remove reported user from deck immediately
    state = state.copyWith(
      cards: state.cards.where((c) => c.userId != targetId).toList(),
      history: state.history.where((c) => c.userId != targetId).toList(),
    );

    await _discoveryRepo.reportUser(
      targetId: targetId,
      reason: reason,
      details: details,
    );
  }

  Future<void> blockUser({
    required String targetId,
    required String reason,
  }) async {
    // Remove blocked user from deck immediately
    state = state.copyWith(
      cards: state.cards.where((c) => c.userId != targetId).toList(),
      history: state.history.where((c) => c.userId != targetId).toList(),
    );

    await _discoveryRepo.blockUser(
      targetId: targetId,
      reason: reason,
    );
  }

  void clearLatestMatch() {
    state = state.copyWith(clearLatestMatch: true);
  }

  void dismissLimitModal() {
    state = state.copyWith(isLimitReached: false);
  }

  void setLocationDisabled(bool disabled) {
    state = state.copyWith(isLocationDisabled: disabled);
  }
}

final discoveryNotifierProvider =
    StateNotifierProvider<DiscoveryNotifier, DiscoveryState>((ref) {
  final discoveryRepo = ref.watch(discoveryRepositoryProvider);
  final swipeRepo = ref.watch(swipeRepositoryProvider);
  return DiscoveryNotifier(
    discoveryRepo: discoveryRepo,
    swipeRepo: swipeRepo,
  );
});
