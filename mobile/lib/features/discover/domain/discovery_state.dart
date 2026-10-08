import 'package:equatable/equatable.dart';
import 'package:fikir/features/discover/domain/discovery_card.dart';
import 'package:fikir/features/discover/domain/discovery_filters.dart';
import 'package:fikir/features/discover/domain/swipe_action.dart';

class DiscoveryState extends Equatable {
  const DiscoveryState({
    this.cards = const [],
    this.history = const [],
    this.isLoading = false,
    this.isRefilling = false,
    this.latestMatch,
    this.dailyLikesRemaining = 50,
    this.dailyResetTime,
    this.filters = const DiscoveryFilters(),
    this.isLocationDisabled = false,
    this.isLimitReached = false,
    this.errorMessage,
  });

  final List<DiscoveryProfileCard> cards;
  final List<DiscoveryProfileCard> history;
  final bool isLoading;
  final bool isRefilling;
  final SwipeResult? latestMatch;
  final int dailyLikesRemaining;
  final DateTime? dailyResetTime;
  final DiscoveryFilters filters;
  final bool isLocationDisabled;
  final bool isLimitReached;
  final String? errorMessage;

  DiscoveryProfileCard? get currentCard => cards.isNotEmpty ? cards.first : null;
  bool get hasCards => cards.isNotEmpty;
  bool get canRewind => history.isNotEmpty;

  DiscoveryState copyWith({
    List<DiscoveryProfileCard>? cards,
    List<DiscoveryProfileCard>? history,
    bool? isLoading,
    bool? isRefilling,
    SwipeResult? latestMatch,
    bool clearLatestMatch = false,
    int? dailyLikesRemaining,
    DateTime? dailyResetTime,
    DiscoveryFilters? filters,
    bool? isLocationDisabled,
    bool? isLimitReached,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DiscoveryState(
      cards: cards ?? this.cards,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      isRefilling: isRefilling ?? this.isRefilling,
      latestMatch: clearLatestMatch ? null : (latestMatch ?? this.latestMatch),
      dailyLikesRemaining: dailyLikesRemaining ?? this.dailyLikesRemaining,
      dailyResetTime: dailyResetTime ?? this.dailyResetTime,
      filters: filters ?? this.filters,
      isLocationDisabled: isLocationDisabled ?? this.isLocationDisabled,
      isLimitReached: isLimitReached ?? this.isLimitReached,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        cards,
        history,
        isLoading,
        isRefilling,
        latestMatch,
        dailyLikesRemaining,
        dailyResetTime,
        filters,
        isLocationDisabled,
        isLimitReached,
        errorMessage,
      ];
}
