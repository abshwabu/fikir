import 'package:cached_network_image/cached_network_image.dart';
import 'package:fikir/core/utils/image_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

class FikirBlurHashImage extends StatelessWidget {
  const FikirBlurHashImage({
    required this.imageUrl, super.key,
    this.blurHash,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  final String imageUrl;
  final String? blurHash;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final int? memCacheWidth;
  final int? memCacheHeight;

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    final normalizedUrl = normalizeMediaUrl(imageUrl);

    if (normalizedUrl.isEmpty) {
      imageWidget = _buildPlaceholder();
    } else {
      imageWidget = CachedNetworkImage(
        imageUrl: normalizedUrl,
        cacheManager: FikirImageCacheManager.instance,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildErrorWidget(url, error),
        fadeInDuration: const Duration(milliseconds: 150),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildPlaceholder() {
    if (blurHash != null && blurHash!.isNotEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: BlurHash(
          hash: blurHash!,
          imageFit: fit,
        ),
      );
    }
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade300,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String url, Object? error) {
    debugPrint('[BlurHashImage] Failed to load image $url: $error');
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }
}
