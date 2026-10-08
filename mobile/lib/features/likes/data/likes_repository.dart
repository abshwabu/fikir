import 'package:dio/dio.dart';
import 'package:fikir/core/network/dio_client.dart';
import 'package:fikir/features/discover/data/swipe_repository.dart';
import 'package:fikir/features/discover/domain/swipe_action.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LikedUserProfile {
  const LikedUserProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.city,
    required this.photoUrl,
    this.blurredPhotoUrl,
    this.blurhash,
    this.bio,
    this.isVerified = false,
  });

  factory LikedUserProfile.fromJson(Map<String, dynamic> json) {
    return LikedUserProfile(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'User',
      age: (json['age'] as num?)?.toInt() ?? 24,
      city: (json['city'] as String?) ?? 'Addis Ababa',
      photoUrl: (json['photo_url'] as String?) ?? '',
      blurredPhotoUrl: json['blurred_photo_url'] as String?,
      blurhash: json['blurhash'] as String?,
      bio: json['bio'] as String?,
      isVerified: (json['is_verified'] as bool?) ?? false,
    );
  }

  final String id;
  final String name;
  final int age;
  final String city;
  final String photoUrl;
  final String? blurredPhotoUrl;
  final String? blurhash;
  final String? bio;
  final bool isVerified;
}

class LikesResponse {
  const LikesResponse({
    required this.count,
    required this.isPremium,
    required this.profiles,
  });

  final int count;
  final bool isPremium;
  final List<LikedUserProfile> profiles;
}

final isPremiumProvider = StateProvider<bool>((ref) => false);

final likesRepositoryProvider = Provider<LikesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final swipeRepo = ref.watch(swipeRepositoryProvider);
  return LikesRepository(dio, swipeRepo);
});

class LikesRepository {
  LikesRepository(this._dio, this._swipeRepo);

  final Dio _dio;
  final SwipeRepository _swipeRepo;

  Future<LikesResponse> fetchLikes({bool isPremium = false}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/likes-you',
        queryParameters: {'limit': 20},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final count = (data['count'] as num?)?.toInt() ?? 0;
        final rawProfiles = (data['profiles'] as List<dynamic>?) ?? [];
        final profiles = rawProfiles
            .whereType<Map<String, dynamic>>()
            .map(LikedUserProfile.fromJson)
            .toList();

        return LikesResponse(
          count: count,
          isPremium: isPremium,
          profiles: profiles,
        );
      }
    } catch (_) {
      // Fallback to sample profiles for offline or initial demo
    }

    return LikesResponse(
      count: 4,
      isPremium: isPremium,
      profiles: const [
        LikedUserProfile(
          id: 'user_like_1',
          name: 'Bethlehem',
          age: 23,
          city: 'Bole, Addis Ababa',
          photoUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=400',
          bio: 'Coffee lover & architect. Let us explore Piassa together! ☕️',
          isVerified: true,
        ),
        LikedUserProfile(
          id: 'user_like_2',
          name: 'Meron',
          age: 25,
          city: 'Hawassa',
          photoUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400',
          bio: 'Loves sunset walks along Lake Hawassa. 🌅',
          isVerified: true,
        ),
        LikedUserProfile(
          id: 'user_like_3',
          name: 'Tigist',
          age: 24,
          city: 'Dire Dawa',
          photoUrl: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=400',
          bio: 'Software engineer living in Dire Dawa. Foodie & traveler.',
        ),
        LikedUserProfile(
          id: 'user_like_4',
          name: 'Hiwot',
          age: 26,
          city: 'Adama',
          photoUrl: 'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=400',
          bio: 'Bookworm & traditional music enthusiast. 🎶',
          isVerified: true,
        ),
      ],
    );
  }

  Future<void> likeBack(String targetUserId) async {
    await _swipeRepo.recordSwipe(
      targetUserId: targetUserId,
      direction: SwipeDirection.like,
    );
  }

  Future<void> pass(String targetUserId) async {
    await _swipeRepo.recordSwipe(
      targetUserId: targetUserId,
      direction: SwipeDirection.nope,
    );
  }
}
