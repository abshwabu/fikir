import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fikir/core/utils/image_cache_manager.dart';
import 'package:flutter/material.dart';

class FullScreenImageViewer extends StatefulWidget {
  const FullScreenImageViewer({
    super.key,
    this.imageUrl,
    this.imageFile,
    this.title,
    this.heroTag,
  }) : assert(imageUrl != null || imageFile != null, 'Either imageUrl or imageFile must be provided');

  final String? imageUrl;
  final File? imageFile;
  final String? title;
  final String? heroTag;

  static Future<void> open(
    BuildContext context, {
    String? imageUrl,
    File? imageFile,
    String? title,
    String? heroTag,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: const Color(0xF2000000),
        pageBuilder: (context, _, __) => FullScreenImageViewer(
          imageUrl: imageUrl,
          imageFile: imageFile,
          title: title,
          heroTag: heroTag,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  final TransformationController _transController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  void _handleDoubleTap() {
    if (_transController.value != Matrix4.identity()) {
      _transController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      _transController.value = Matrix4.identity()
        ..translateByDouble(-position.dx * 1.5, -position.dy * 1.5, 0, 1)
        ..scaleByDouble(2.5, 2.5, 1, 1);
    }
  }

  @override
  void dispose() {
    _transController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    final normalized = widget.imageUrl != null ? normalizeMediaUrl(widget.imageUrl) : '';

    if (widget.imageFile != null && widget.imageFile!.existsSync()) {
      imageWidget = Image.file(
        widget.imageFile!,
        fit: BoxFit.contain,
      );
    } else if (normalized.isNotEmpty) {
      imageWidget = CachedNetworkImage(
        imageUrl: normalized,
        cacheManager: FikirImageCacheManager.instance,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(color: Colors.white70),
        ),
        errorWidget: (context, url, error) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, color: Colors.white60, size: 48),
              SizedBox(height: 8),
              Text('Failed to load image', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    } else {
      imageWidget = const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.white60, size: 48),
      );
    }

    if (widget.heroTag != null) {
      imageWidget = Hero(
        tag: widget.heroTag!,
        child: imageWidget,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Pinch-to-zoom interactive viewer
          GestureDetector(
            onDoubleTapDown: (details) => _doubleTapDetails = details,
            onDoubleTap: _handleDoubleTap,
            child: InteractiveViewer(
              transformationController: _transController,
              minScale: 1,
              maxScale: 4,
              child: Center(child: imageWidget),
            ),
          ),
          // Top AppBar with dismiss button and title
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    if (widget.title != null && widget.title!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.title!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
