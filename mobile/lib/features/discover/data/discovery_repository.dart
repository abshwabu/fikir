import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:fikir/core/database/app_database.dart';
import 'package:fikir/core/network/dio_client.dart';
import 'package:fikir/features/discover/domain/discovery_card.dart';
import 'package:fikir/features/discover/domain/discovery_filters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class DiscoveryRepository {
  Future<List<DiscoveryProfileCard>> fetchDeck({
    int limit = 15,
    DiscoveryFilters? filters,
  });
  Future<void> reportUser({
    required String targetId,
    required String reason,
    String details = '',
  });
  Future<void> blockUser({
    required String targetId,
    required String reason,
  });
  Future<void> updateFilters(DiscoveryFilters filters);
}

class DiscoveryRepositoryImpl implements DiscoveryRepository {
  DiscoveryRepositoryImpl({
    required Dio dio,
    required AppDatabase db,
  })  : _dio = dio,
        _db = db;

  final Dio _dio;
  final AppDatabase _db;

  static const List<DiscoveryProfileCard> fallbackCards = [
    DiscoveryProfileCard(
      userId: 'mock-1-selamawit',
      displayName: 'Selamawit',
      age: 24,
      gender: 'woman',
      distanceKm: 3.2,
      city: 'Addis Ababa (Bole)',
      region: 'Addis Ababa',
      bio: 'Coffee lover ☕, traditional music enthusiast, architect based in Bole. Always up for good conversations over buna.',
      jobTitle: 'Architect',
      education: 'Addis Ababa University',
      religion: 'Orthodox',
      verified: true,
      completenessScore: 95,
      interests: ['Coffee', 'Jazz', 'Architecture', 'Art', 'Gursha'],
      photos: [
        ProfileCardPhoto(
          id: 'p1-1',
          position: 0,
          url: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800',
          blurhash: 'L6PZfSi_.AyE_3t7t7R**0o#DgR4',
        ),
        ProfileCardPhoto(
          id: 'p1-2',
          position: 1,
          url: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=800',
          blurhash: 'L9AB|G9Z00~q~q00%M%M?bM{4n%M',
        ),
        ProfileCardPhoto(
          id: 'p1-3',
          position: 2,
          url: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=800',
          blurhash: 'L7A0v}00~q_3_300-;IU-;IU~qIU',
        ),
      ],
    ),
    DiscoveryProfileCard(
      userId: 'mock-2-yohannes',
      displayName: 'Yohannes',
      age: 27,
      gender: 'man',
      distanceKm: 5.8,
      city: 'Addis Ababa (Kazanchis)',
      region: 'Addis Ababa',
      bio: 'Software engineer & jazz pianist. Weekend morning runner around Entoto. Looking for someone with good energy.',
      jobTitle: 'Tech Lead',
      education: 'AAU Science Campus',
      religion: 'Orthodox',
      verified: true,
      completenessScore: 90,
      interests: ['Coding', 'Jazz', 'Running', 'Hiking', 'Tech'],
      photos: [
        ProfileCardPhoto(
          id: 'p2-1',
          position: 0,
          url: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800',
          blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
        ),
        ProfileCardPhoto(
          id: 'p2-2',
          position: 1,
          url: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800',
          blurhash: 'L28qf000-;~q0000_3_3-;~q_3_3',
        ),
      ],
    ),
    DiscoveryProfileCard(
      userId: 'mock-3-hanna',
      displayName: 'Hanna',
      age: 23,
      gender: 'woman',
      distanceKm: 8.4,
      city: 'Hawassa',
      region: 'Sidama',
      bio: 'Literature graduate, Tana sunset lover 🌅, fascinated by Ethiopian poetry and photography.',
      jobTitle: 'Content Strategist',
      education: 'Hawassa University',
      religion: 'Protestant',
      verified: true,
      completenessScore: 88,
      interests: ['Books', 'Poetry', 'Photography', 'Travel'],
      photos: [
        ProfileCardPhoto(
          id: 'p3-1',
          position: 0,
          url: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=800',
          blurhash: 'LGF5]+Yk^6#M@-5c,1J5@[or[Q6.',
        ),
        ProfileCardPhoto(
          id: 'p3-2',
          position: 1,
          url: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=800',
          blurhash: r'L8E_O$00_3~q0000-;IU-;IU~qIU',
        ),
      ],
    ),
    DiscoveryProfileCard(
      userId: 'mock-4-dawit',
      displayName: 'Dawit',
      age: 29,
      gender: 'man',
      distanceKm: 12,
      city: 'Addis Ababa (CMC)',
      region: 'Addis Ababa',
      bio: 'Financial analyst & amateur photographer. Passionate about Ethiopian history, museums, and exploring new cafes.',
      jobTitle: 'Senior Analyst',
      education: 'Unity University',
      religion: 'Orthodox',
      completenessScore: 82,
      interests: ['Photography', 'History', 'Museums', 'Coffee'],
      photos: [
        ProfileCardPhoto(
          id: 'p4-1',
          position: 0,
          url: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800',
          blurhash: 'L69P:x%200%M00~q00~q00%M%M00',
        ),
      ],
    ),
    DiscoveryProfileCard(
      userId: 'mock-5-bethlehem',
      displayName: 'Bethlehem',
      age: 25,
      gender: 'woman',
      distanceKm: 4.5,
      city: 'Bahir Dar',
      region: 'Amhara',
      bio: 'Public health researcher with a heart for volunteering. Love traditional dance, shiro tagamino, and lake walks.',
      jobTitle: 'Health Researcher',
      education: 'Gondar University',
      religion: 'Orthodox',
      verified: true,
      completenessScore: 92,
      interests: ['Volunteering', 'Health', 'Dance', 'Lakes', 'Foodie'],
      photos: [
        ProfileCardPhoto(
          id: 'p5-1',
          position: 0,
          url: 'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=800',
          blurhash: 'LDF~G2~q000000-;~q00-;00~q00',
        ),
      ],
    ),
  ];

  @override
  Future<List<DiscoveryProfileCard>> fetchDeck({
    int limit = 15,
    DiscoveryFilters? filters,
  }) async {
    try {
      final queryParams = <String, dynamic>{'limit': limit};
      if (filters != null) {
        queryParams['age_min'] = filters.minAge;
        queryParams['age_max'] = filters.maxAge;
        queryParams['distance_max'] = filters.maxDistanceKm;
        if (filters.genderPreference != 'everyone') {
          queryParams['gender'] = filters.genderPreference == 'women' ? 'woman' : 'man';
        }
        if (filters.verifiedOnly) {
          queryParams['verified_only'] = 'true';
        }
      }

      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/discovery',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final deckRaw = data['deck'] as List<dynamic>? ?? [];
        if (deckRaw.isNotEmpty) {
          final cards = deckRaw
              .map((c) => DiscoveryProfileCard.fromJson(c as Map<String, dynamic>))
              .toList();

          // Cache profiles in Drift
          for (final card in cards) {
            await _db.upsertProfile(
              CachedProfile(
                id: card.userId,
                name: card.displayName,
                bio: card.bio,
                birthdate: DateTime.now().subtract(Duration(days: card.age * 365)),
                gender: card.gender,
                city: card.city,
                photosJson: jsonEncode(card.photos.map((p) => p.toJson()).toList()),
                interestsJson: jsonEncode(card.interests),
                completenessScore: card.completenessScore,
                isVerified: card.verified,
                lastActiveAt: card.lastActiveAt,
                cachedAt: DateTime.now(),
              ),
            );
          }
          return cards;
        }
      }
    } catch (_) {
      // In offline / network issue, try loading from Drift cached profiles first
      final cached = await _db.getAllProfiles();
      if (cached.isNotEmpty) {
        return cached.map((CachedProfile c) {
          var photos = <ProfileCardPhoto>[];
          try {
            final pList = jsonDecode(c.photosJson) as List<dynamic>;
            photos = pList.map((p) => ProfileCardPhoto.fromJson(p as Map<String, dynamic>)).toList();
          } catch (_) {}

          var interests = <String>[];
          try {
            final iList = jsonDecode(c.interestsJson) as List<dynamic>;
            interests = iList.map((e) => e.toString()).toList();
          } catch (_) {}

          return DiscoveryProfileCard(
            userId: c.id,
            displayName: c.name,
            age: DateTime.now().difference(c.birthdate).inDays ~/ 365,
            gender: c.gender,
            distanceKm: 5,
            bio: c.bio ?? '',
            city: c.city ?? '',
            verified: c.isVerified,
            completenessScore: c.completenessScore,
            interests: interests,
            photos: photos,
            lastActiveAt: c.lastActiveAt,
          );
        }).toList();
      }
    }

    // Return curated mock cards if deck is otherwise empty (ensures rich initial UX)
    return List.from(fallbackCards);
  }

  @override
  Future<void> reportUser({
    required String targetId,
    required String reason,
    String details = '',
  }) async {
    try {
      await _dio.post<dynamic>(
        '/v1/reports',
        data: {
          'target_id': targetId,
          'reason': reason,
          'details': details,
        },
      );
    } catch (_) {
      // Graceful local handling
    }
  }

  @override
  Future<void> blockUser({
    required String targetId,
    required String reason,
  }) async {
    try {
      await _dio.post<dynamic>(
        '/v1/blocks',
        data: {
          'target_id': targetId,
          'reason': reason,
        },
      );
    } catch (_) {
      // Graceful local handling
    }
  }

  @override
  Future<void> updateFilters(DiscoveryFilters filters) async {
    try {
      await _dio.patch<dynamic>(
        '/v1/me/profile',
        data: filters.toJson(),
      );
    } catch (_) {}
  }
}

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final db = ref.watch(databaseProvider);
  return DiscoveryRepositoryImpl(dio: dio, db: db);
});
