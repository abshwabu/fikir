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

  int? get _effectiveMemCacheWidth {
    if (memCacheWidth != null) return memCacheWidth;
    if (width != null && width! > 0) return (width! * 2).round().clamp(60, 1080);
    return 720;
  }

  int? get _effectiveMemCacheHeight {
    if (memCacheHeight != null) return memCacheHeight;
    if (height != null && height! > 0) return (height! * 2).round().clamp(60, 1440);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    final normalizedUrl = imageUrl.startsWith('http://localhost')
        ? imageUrl.replaceFirst('http://localhost', 'http://127.0.0.1')
        : imageUrl;

    if (normalizedUrl.isEmpty) {
      imageWidget = _buildPlaceholder();
    } else {
      imageWidget = CachedNetworkImage(
        imageUrl: normalizedUrl,
        cacheManager: FikirImageCacheManager.instance,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: _effectiveMemCacheWidth,
        memCacheHeight: _effectiveMemCacheHeight,
        maxWidthDiskCache: 1200,
        maxHeightDiskCache: 1200,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildErrorWidget(),
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

  Widget _buildErrorWidget() {
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
