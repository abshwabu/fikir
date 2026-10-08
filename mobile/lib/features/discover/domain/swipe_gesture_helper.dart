import 'package:fikir/features/discover/domain/swipe_action.dart';
import 'package:flutter/gestures.dart';

class SwipeGestureHelper {
  const SwipeGestureHelper._();

  static const double horizontalThresholdRatio = 0.35;
  static const double verticalThresholdRatio = 0.20;
  static const double flingVelocityThreshold = 800;

  /// Decides if a drag or fling should commit to a swipe direction.
  /// Returns null if the gesture should spring back to center.
  static SwipeDirection? decideSwipe({
    required Offset offset,
    required Velocity velocity,
    required double screenWidth,
    required double screenHeight,
  }) {
    final v = velocity.pixelsPerSecond;
    final isRightFling = v.dx > flingVelocityThreshold;
    final isLeftFling = v.dx < -flingVelocityThreshold;
    final isUpFling = v.dy < -flingVelocityThreshold;

    final isRightDrag = offset.dx > screenWidth * horizontalThresholdRatio;
    final isLeftDrag = offset.dx < -screenWidth * horizontalThresholdRatio;
    final isUpDrag = offset.dy < -screenHeight * verticalThresholdRatio &&
        offset.dy.abs() > offset.dx.abs() * 0.8;

    if (isUpDrag || isUpFling) {
      return SwipeDirection.superLike;
    } else if (isRightDrag || isRightFling) {
      return SwipeDirection.like;
    } else if (isLeftDrag || isLeftFling) {
      return SwipeDirection.nope;
    }
    return null;
  }

  /// Calculates card rotation angle in radians proportional to horizontal displacement.
  static double calculateRotationAngle({
    required double dx,
    required double screenWidth,
  }) {
    if (screenWidth == 0) return 0;
    return (dx / screenWidth) * 0.35;
  }
}
