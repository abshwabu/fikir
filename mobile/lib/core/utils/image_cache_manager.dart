import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class FikirImageCacheManager {
  FikirImageCacheManager._();

  static const String key = 'fikir_image_cache';

  /// Custom CacheManager instance with 30-day stale duration and max 1000 objects (~300MB cap).
  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 1000,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}
