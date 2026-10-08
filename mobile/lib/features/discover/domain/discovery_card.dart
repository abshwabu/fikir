import 'package:equatable/equatable.dart';

class ProfileCardPhoto extends Equatable {
  const ProfileCardPhoto({
    required this.id,
    required this.position,
    required this.url,
    this.blurhash,
    this.width = 600,
    this.height = 800,
  });

  factory ProfileCardPhoto.fromJson(Map<String, dynamic> json) {
    return ProfileCardPhoto(
      id: json['id'] as String? ?? '',
      position: (json['position'] as num?)?.toInt() ?? 0,
      url: json['url'] as String? ?? '',
      blurhash: json['blurhash'] as String?,
      width: (json['width'] as num?)?.toInt() ?? 600,
      height: (json['height'] as num?)?.toInt() ?? 800,
    );
  }

  final String id;
  final int position;
  final String url;
  final String? blurhash;
  final int width;
  final int height;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'position': position,
      'url': url,
      'blurhash': blurhash,
      'width': width,
      'height': height,
    };
  }

  @override
  List<Object?> get props => [id, position, url, blurhash, width, height];
}

class DiscoveryProfileCard extends Equatable {
  const DiscoveryProfileCard({
    required this.userId,
    required this.displayName,
    required this.age,
    required this.gender,
    required this.distanceKm,
    this.bio = '',
    this.jobTitle = '',
    this.education = '',
    this.heightCm,
    this.religion = '',
    this.city = '',
    this.region = '',
    this.verified = false,
    this.completenessScore = 0,
    this.interests = const [],
    this.photos = const [],
    this.lastActiveAt,
    this.boostUntil,
  });

  factory DiscoveryProfileCard.fromJson(Map<String, dynamic> json) {
    final photosRaw = json['photos'] as List<dynamic>? ?? [];
    final photos = photosRaw
        .map((p) => ProfileCardPhoto.fromJson(p as Map<String, dynamic>))
        .toList();

    final interestsRaw = json['interests'] as List<dynamic>? ?? [];
    final interests = interestsRaw.map((e) => e.toString()).toList();

    return DiscoveryProfileCard(
      userId: json['user_id'] as String? ?? json['id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? json['name'] as String? ?? '',
      age: (json['age'] as num?)?.toInt() ?? 25,
      gender: json['gender'] as String? ?? 'woman',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 5.0,
      bio: json['bio'] as String? ?? '',
      jobTitle: json['job_title'] as String? ?? '',
      education: json['education'] as String? ?? '',
      heightCm: (json['height_cm'] as num?)?.toInt(),
      religion: json['religion'] as String? ?? '',
      city: json['city'] as String? ?? 'Addis Ababa',
      region: json['region'] as String? ?? 'Addis Ababa',
      verified: json['verified'] as bool? ?? false,
      completenessScore: (json['completeness_score'] as num?)?.toInt() ?? 80,
      interests: interests,
      photos: photos,
      lastActiveAt: json['last_active_at'] != null
          ? DateTime.tryParse(json['last_active_at'] as String)
          : null,
      boostUntil: json['boost_until'] != null
          ? DateTime.tryParse(json['boost_until'] as String)
          : null,
    );
  }

  final String userId;
  final String displayName;
  final int age;
  final String gender;
  final double distanceKm;
  final String bio;
  final String jobTitle;
  final String education;
  final int? heightCm;
  final String religion;
  final String city;
  final String region;
  final bool verified;
  final int completenessScore;
  final List<String> interests;
  final List<ProfileCardPhoto> photos;
  final DateTime? lastActiveAt;
  final DateTime? boostUntil;

  String get primaryPhotoUrl => photos.isNotEmpty ? photos.first.url : '';
  String? get primaryBlurhash => photos.isNotEmpty ? photos.first.blurhash : null;

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'display_name': displayName,
      'age': age,
      'gender': gender,
      'distance_km': distanceKm,
      'bio': bio,
      'job_title': jobTitle,
      'education': education,
      'height_cm': heightCm,
      'religion': religion,
      'city': city,
      'region': region,
      'verified': verified,
      'completeness_score': completenessScore,
      'interests': interests,
      'photos': photos.map((p) => p.toJson()).toList(),
      'last_active_at': lastActiveAt?.toIso8601String(),
      'boost_until': boostUntil?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        userId,
        displayName,
        age,
        gender,
        distanceKm,
        bio,
        jobTitle,
        education,
        heightCm,
        religion,
        city,
        region,
        verified,
        completenessScore,
        interests,
        photos,
        lastActiveAt,
        boostUntil,
      ];
}
