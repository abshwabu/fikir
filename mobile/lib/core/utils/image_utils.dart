import 'package:cached_network_image/cached_network_image.dart';
import 'package:fikir/core/utils/image_cache_manager.dart';
import 'package:flutter/material.dart';

enum PhotoVariantType {
  thumb,
  card,
  full,
}

class ImageUtils {
  ImageUtils._();

  /// Determines the ideal variant name given widget logical dimensions and device pixel ratio.
  static PhotoVariantType pickVariant({
    required double width,
    required double height,
    double dpr = 2.0,
  }) {
    final physicalDimension = (width > height ? width : height) * dpr;
    if (physicalDimension <= 200) {
      return PhotoVariantType.thumb;
    } else if (physicalDimension <= 600) {
      return PhotoVariantType.card;
    } else {
      return PhotoVariantType.full;
    }
  }

  /// Extracts the optimal image URL from a variants map.
  /// Prefers AVIF -> WebP -> JPEG fallback.
  static String? selectBestUrl(Map<String, dynamic>? variants, PhotoVariantType preferredVariant) {
    if (variants == null || variants.isEmpty) return null;

    final variantKey = preferredVariant.name;
    final variantData = variants[variantKey] as Map<String, dynamic>?;

    if (variantData != null) {
      return (variantData['avif'] as String?) ??
          (variantData['webp'] as String?) ??
          (variantData['jpeg'] as String?);
    }

    // Fallbacks if requested variant doesn't exist
    for (final key in ['card', 'full', 'thumb']) {
      final fallback = variants[key] as Map<String, dynamic>?;
      if (fallback != null) {
        final url = (fallback['avif'] as String?) ??
            (fallback['webp'] as String?) ??
            (fallback['jpeg'] as String?);
        if (url != null) return url;
      }
    }

    return null;
  }

  /// Resolves image URL with lower resolution and aggressive compression in data-saver mode.
  static String resolveDataSaverUrl(String originalUrl, {bool isDataSaver = false}) {
    if (!isDataSaver || originalUrl.isEmpty) return originalUrl;
    if (originalUrl.contains('w=')) {
      return originalUrl.replaceAll(RegExp(r'w=\d+'), 'w=360&q=50');
    }
    return originalUrl.contains('?') ? '$originalUrl&w=360&q=50' : '$originalUrl?w=360&q=50';
  }

  /// Precaches a remote image into the custom Fikir cache.
  static Future<void> precacheFikirImage(
    BuildContext context,
    String imageUrl,
  ) {
    final provider = CachedNetworkImageProvider(
      imageUrl,
      cacheManager: FikirImageCacheManager.instance,
    );
    return precacheImage(provider, context);
  }
}
