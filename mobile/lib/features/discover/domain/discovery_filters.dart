import 'package:equatable/equatable.dart';

class DiscoveryFilters extends Equatable {
  const DiscoveryFilters({
    this.minAge = 18,
    this.maxAge = 45,
    this.maxDistanceKm = 50,
    this.genderPreference = 'everyone',
    this.verifiedOnly = false,
  });

  final int minAge;
  final int maxAge;
  final int maxDistanceKm;
  final String genderPreference; // 'women', 'men', 'everyone'
  final bool verifiedOnly;

  DiscoveryFilters copyWith({
    int? minAge,
    int? maxAge,
    int? maxDistanceKm,
    String? genderPreference,
    bool? verifiedOnly,
  }) {
    return DiscoveryFilters(
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      genderPreference: genderPreference ?? this.genderPreference,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'age_min': minAge,
      'age_max': maxAge,
      'distance_max': maxDistanceKm,
      'interested_in': genderPreference == 'everyone'
          ? ['woman', 'man']
          : genderPreference == 'women'
              ? ['woman']
              : ['man'],
      'verified_only': verifiedOnly,
    };
  }

  @override
  List<Object?> get props => [
        minAge,
        maxAge,
        maxDistanceKm,
        genderPreference,
        verifiedOnly,
      ];
}
