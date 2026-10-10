import 'package:flutter_cache_manager/flutter_cache_manager.dart';

String normalizeMediaUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http://localhost:')) {
    return url.replaceFirst('http://localhost:', 'http://127.0.0.1:');
  }
  if (url.startsWith('http://localhost/')) {
    return url.replaceFirst('http://localhost/', 'http://127.0.0.1/');
  }
  if (url == 'http://localhost') {
    return 'http://127.0.0.1';
  }
  return url;
}

class FikirImageCacheManager extends CacheManager with ImageCacheManager {
  FikirImageCacheManager._()
      : super(
          Config(
            key,
            stalePeriod: const Duration(days: 30),
            maxNrOfCacheObjects: 1000,
            repo: JsonCacheInfoRepository(databaseName: key),
            fileService: HttpFileService(),
          ),
        );

  static const String key = 'fikir_image_cache';

  /// Custom CacheManager instance with 30-day stale duration and max 1000 objects (~300MB cap).
  static final FikirImageCacheManager instance = FikirImageCacheManager._();
}
