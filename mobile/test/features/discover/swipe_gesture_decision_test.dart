import 'package:fikir/features/discover/domain/swipe_action.dart';
import 'package:fikir/features/discover/domain/swipe_gesture_helper.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SwipeGestureHelper Tests', () {
    const screenWidth = 400.0;
    const screenHeight = 800.0;
    const zeroVelocity = Velocity.zero;

    test('horizontal drag right beyond 35% screen width triggers LIKE', () {
      final decision = SwipeGestureHelper.decideSwipe(
        offset: const Offset(150, 10), // 150 > 400 * 0.35 = 140
        velocity: zeroVelocity,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      expect(decision, equals(SwipeDirection.like));
    });

    test('horizontal drag left beyond -35% screen width triggers NOPE', () {
      final decision = SwipeGestureHelper.decideSwipe(
        offset: const Offset(-150, 10), // -150 < -140
        velocity: zeroVelocity,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      expect(decision, equals(SwipeDirection.nope));
    });

    test('upward drag beyond -20% screen height triggers SUPER LIKE', () {
      final decision = SwipeGestureHelper.decideSwipe(
        offset: const Offset(10, -180), // -180 < 800 * -0.20 = -160
        velocity: zeroVelocity,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      expect(decision, equals(SwipeDirection.superLike));
    });

    test('right fling with velocity > 800 px/s commits LIKE regardless of distance', () {
      final decision = SwipeGestureHelper.decideSwipe(
        offset: const Offset(20, 0), // Small distance
        velocity: const Velocity(pixelsPerSecond: Offset(950, 0)),
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      expect(decision, equals(SwipeDirection.like));
    });

    test('left fling with velocity < -800 px/s commits NOPE regardless of distance', () {
      final decision = SwipeGestureHelper.decideSwipe(
        offset: const Offset(-20, 0), // Small distance
        velocity: const Velocity(pixelsPerSecond: Offset(-900, 0)),
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      expect(decision, equals(SwipeDirection.nope));
    });

    test('upward fling with velocity dy < -800 px/s commits SUPER LIKE', () {
      final decision = SwipeGestureHelper.decideSwipe(
        offset: const Offset(0, -30),
        velocity: const Velocity(pixelsPerSecond: Offset(0, -1100)),
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      expect(decision, equals(SwipeDirection.superLike));
    });

    test('small displacement and low velocity returns null to trigger spring-back', () {
      final decision = SwipeGestureHelper.decideSwipe(
        offset: const Offset(50, -40),
        velocity: const Velocity(pixelsPerSecond: Offset(200, 100)),
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      expect(decision, isNull);
    });

    test('calculateRotationAngle returns linear proportional radians', () {
      final angleCenter = SwipeGestureHelper.calculateRotationAngle(
        dx: 0,
        screenWidth: screenWidth,
      );
      expect(angleCenter, equals(0.0));

      final angleRight = SwipeGestureHelper.calculateRotationAngle(
        dx: 200,
        screenWidth: 400,
      );
      expect(angleRight, closeTo(0.175, 0.001));

      final angleLeft = SwipeGestureHelper.calculateRotationAngle(
        dx: -200,
        screenWidth: 400,
      );
      expect(angleLeft, closeTo(-0.175, 0.001));
    });
  });
}
