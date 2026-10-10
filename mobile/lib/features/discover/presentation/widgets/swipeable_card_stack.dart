import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fikir/core/utils/image_cache_manager.dart';
import 'package:fikir/features/discover/domain/discovery_card.dart';
import 'package:fikir/features/discover/domain/swipe_action.dart';
import 'package:fikir/features/discover/domain/swipe_gesture_helper.dart';
import 'package:fikir/features/discover/presentation/widgets/photo_pager_card.dart';
import 'package:fikir/features/discover/presentation/widgets/swipe_stamp_overlay.dart';
import 'package:flutter/material.dart';

class SwipeableCardStack extends StatefulWidget {
  const SwipeableCardStack({
    required this.cards,
    required this.onSwipe,
    required this.onInfoTap,
    super.key,
  });

  final List<DiscoveryProfileCard> cards;
  final void Function(SwipeDirection direction) onSwipe;
  final void Function(DiscoveryProfileCard card) onInfoTap;

  @override
  SwipeableCardStackState createState() => SwipeableCardStackState();
}

class SwipeableCardStackState extends State<SwipeableCardStack>
    with SingleTickerProviderStateMixin {
  late final ValueNotifier<Offset> _dragOffsetNotifier;
  late final AnimationController _animationController;
  Animation<Offset>? _animation;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _dragOffsetNotifier = ValueNotifier<Offset>(Offset.zero);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        if (_animation != null) {
          _dragOffsetNotifier.value = _animation!.value;
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheNextCards();
  }

  @override
  void didUpdateWidget(SwipeableCardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cards.isNotEmpty &&
        (oldWidget.cards.isEmpty || oldWidget.cards.first.userId != widget.cards.first.userId)) {
      _precacheNextCards();
    }
  }

  void _precacheNextCards() {
    if (widget.cards.length > 1) {
      for (var i = 1; i < min(widget.cards.length, 3); i++) {
        final url = widget.cards[i].primaryPhotoUrl;
        if (url.isNotEmpty && mounted) {
          final normalized = normalizeMediaUrl(url);
          precacheImage(
            CachedNetworkImageProvider(
              normalized,
              cacheManager: FikirImageCacheManager.instance,
            ),
            context,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _dragOffsetNotifier.dispose();
    super.dispose();
  }

  /// Programmatic swipe action triggered by action buttons
  void triggerSwipe(SwipeDirection direction) {
    if (_isAnimating || widget.cards.isEmpty) return;
    final size = MediaQuery.of(context).size;
    final endOffset = _getOffscreenOffset(direction, size);
    _animateAndCommit(endOffset, direction);
  }

  Offset _getOffscreenOffset(SwipeDirection direction, Size size) {
    switch (direction) {
      case SwipeDirection.like:
        return Offset(size.width * 1.5, 0);
      case SwipeDirection.nope:
        return Offset(-size.width * 1.5, 0);
      case SwipeDirection.superLike:
        return Offset(0, -size.height * 1.2);
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (_isAnimating) return;
    _animationController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimating) return;
    // Isolate updates to ValueNotifier for 60fps performance without calling setState
    _dragOffsetNotifier.value = _dragOffsetNotifier.value + details.delta;
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isAnimating || widget.cards.isEmpty) return;

    final size = MediaQuery.of(context).size;
    final currentOffset = _dragOffsetNotifier.value;

    final swipeDecision = SwipeGestureHelper.decideSwipe(
      offset: currentOffset,
      velocity: details.velocity,
      screenWidth: size.width,
      screenHeight: size.height,
    );

    if (swipeDecision != null) {
      final endOffset = _getOffscreenOffset(swipeDecision, size);
      _animateAndCommit(endOffset, swipeDecision);
    } else {
      _springBack();
    }
  }

  void _animateAndCommit(Offset targetOffset, SwipeDirection direction) {
    _isAnimating = true;
    _animation = Tween<Offset>(
      begin: _dragOffsetNotifier.value,
      end: targetOffset,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutQuad,
      ),
    );

    _animationController.forward(from: 0).then((_) {
      _dragOffsetNotifier.value = Offset.zero;
      _isAnimating = false;
      widget.onSwipe(direction);
    });
  }

  void _springBack() {
    _isAnimating = true;
    _animation = Tween<Offset>(
      begin: _dragOffsetNotifier.value,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController.forward(from: 0).then((_) {
      _dragOffsetNotifier.value = Offset.zero;
      _isAnimating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 3rd Card in Deck (if available)
        if (widget.cards.length >= 3)
          RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 8),
              child: Transform.scale(
                scale: 0.90,
                alignment: Alignment.bottomCenter,
                child: PhotoPagerCard(
                  candidate: widget.cards[2],
                  onInfoTap: () => widget.onInfoTap(widget.cards[2]),
                ),
              ),
            ),
          ),

        // 2nd Card in Deck (dynamic scale as top card drags away)
        if (widget.cards.length >= 2)
          ValueListenableBuilder<Offset>(
            valueListenable: _dragOffsetNotifier,
            builder: (context, offset, child) {
              final dragFraction = (offset.distance / (screenWidth * 0.4)).clamp(0.0, 1.0);
              final scale = 0.95 + (0.05 * dragFraction);
              final topPadding = 12.0 * (1.0 - dragFraction);

              return RepaintBoundary(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: topPadding + 8,
                    left: 16,
                    right: 16,
                    bottom: 8,
                  ),
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.bottomCenter,
                    child: PhotoPagerCard(
                      candidate: widget.cards[1],
                      onInfoTap: () => widget.onInfoTap(widget.cards[1]),
                    ),
                  ),
                ),
              );
            },
          ),

        // Top Card (Interactive gesture target)
        ValueListenableBuilder<Offset>(
          valueListenable: _dragOffsetNotifier,
          builder: (context, offset, child) {
            // Rotation is proportional to horizontal drag offset
            final angle = SwipeGestureHelper.calculateRotationAngle(
              dx: offset.dx,
              screenWidth: screenWidth,
            );

            return RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Transform.translate(
                  offset: offset,
                  child: Transform.rotate(
                    angle: angle,
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          PhotoPagerCard(
                            candidate: widget.cards.first,
                            onInfoTap: () => widget.onInfoTap(widget.cards.first),
                          ),
                          SwipeStampOverlay(offset: offset),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
