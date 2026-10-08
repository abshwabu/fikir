import 'dart:convert';

class OnboardingState {
  const OnboardingState({
    this.currentStep = 0,
    this.name = '',
    this.birthdate,
    this.gender = 'woman',
    this.interestedIn = const ['men'],
    this.photoPaths = const [],
    this.interests = const [],
    this.latitude,
    this.longitude,
    this.city = 'Addis Ababa (Bole)',
    this.religion,
    this.languages = const ['Amharic (አማርኛ)'],
    this.bio = '',
    this.jobTitle = '',
  });

  factory OnboardingState.fromJson(Map<String, dynamic> json) {
    return OnboardingState(
      currentStep: (json['currentStep'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      birthdate: json['birthdate'] != null
          ? DateTime.tryParse(json['birthdate'] as String)
          : null,
      gender: (json['gender'] as String?) ?? 'woman',
      interestedIn: (json['interestedIn'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['men'],
      photoPaths: (json['photoPaths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      interests: (json['interests'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      city: (json['city'] as String?) ?? 'Addis Ababa (Bole)',
      religion: json['religion'] as String?,
      languages: (json['languages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['Amharic (አማርኛ)'],
      bio: (json['bio'] as String?) ?? '',
      jobTitle: (json['jobTitle'] as String?) ?? '',
    );
  }

  final int currentStep;
  final String name;
  final DateTime? birthdate;
  final String gender;
  final List<String> interestedIn;
  final List<String> photoPaths;
  final List<String> interests;
  final double? latitude;
  final double? longitude;
  final String city;
  final String? religion;
  final List<String> languages;
  final String bio;
  final String jobTitle;

  static const int totalSteps = 7;

  OnboardingState copyWith({
    int? currentStep,
    String? name,
    DateTime? birthdate,
    String? gender,
    List<String>? interestedIn,
    List<String>? photoPaths,
    List<String>? interests,
    double? latitude,
    double? longitude,
    String? city,
    String? religion,
    List<String>? languages,
    String? bio,
    String? jobTitle,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      name: name ?? this.name,
      birthdate: birthdate ?? this.birthdate,
      gender: gender ?? this.gender,
      interestedIn: interestedIn ?? this.interestedIn,
      photoPaths: photoPaths ?? this.photoPaths,
      interests: interests ?? this.interests,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      city: city ?? this.city,
      religion: religion ?? this.religion,
      languages: languages ?? this.languages,
      bio: bio ?? this.bio,
      jobTitle: jobTitle ?? this.jobTitle,
    );
  }

  Map<String, dynamic> toJson() => {
        'currentStep': currentStep,
        'name': name,
        'birthdate': birthdate?.toIso8601String(),
        'gender': gender,
        'interestedIn': interestedIn,
        'photoPaths': photoPaths,
        'interests': interests,
        'latitude': latitude,
        'longitude': longitude,
        'city': city,
        'religion': religion,
        'languages': languages,
        'bio': bio,
        'jobTitle': jobTitle,
      };

  String encode() => jsonEncode(toJson());

  static OnboardingState decode(String str) {
    try {
      return OnboardingState.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (_) {
      return const OnboardingState();
    }
  }
}
