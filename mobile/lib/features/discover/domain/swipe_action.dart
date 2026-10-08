import 'package:equatable/equatable.dart';
import 'package:fikir/features/discover/domain/discovery_card.dart';

enum SwipeDirection {
  like,
  nope,
  superLike;

  String get apiValue {
    switch (this) {
      case SwipeDirection.like:
        return 'like';
      case SwipeDirection.nope:
        return 'nope';
      case SwipeDirection.superLike:
        return 'super';
    }
  }

  static SwipeDirection fromString(String val) {
    switch (val.toLowerCase()) {
      case 'like':
        return SwipeDirection.like;
      case 'nope':
      case 'dislike':
      case 'pass':
        return SwipeDirection.nope;
      case 'super':
      case 'superlike':
      case 'super_like':
        return SwipeDirection.superLike;
      default:
        return SwipeDirection.nope;
    }
  }
}

class SwipeResult extends Equatable {
  const SwipeResult({
    required this.matched,
    this.matchId,
    this.matchedProfile,
  });

  factory SwipeResult.fromJson(
    Map<String, dynamic> json, {
    DiscoveryProfileCard? matchedProfile,
  }) {
    final match = json['match'] as Map<String, dynamic>?;
    final matchId = match != null ? (match['id'] as String?) : null;
    return SwipeResult(
      matched: json['matched'] as bool? ?? false,
      matchId: matchId,
      matchedProfile: matchedProfile,
    );
  }

  final bool matched;
  final String? matchId;
  final DiscoveryProfileCard? matchedProfile;

  @override
  List<Object?> get props => [matched, matchId, matchedProfile];
}
