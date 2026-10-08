import 'package:fikir/core/design/colors.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class SwipeStampOverlay extends StatelessWidget {
  const SwipeStampOverlay({
    required this.offset,
    super.key,
  });

  final Offset offset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dx = offset.dx;
    final dy = offset.dy;

    final isSuperLike = dy < -30 && dy.abs() > dx.abs() * 0.8;
    final isLike = dx > 20 && !isSuperLike;
    final isNope = dx < -20 && !isSuperLike;

    if (isSuperLike) {
      final opacity = (-dy / 100.0).clamp(0.0, 1.0);
      return Positioned(
        bottom: 120,
        left: 0,
        right: 0,
        child: Center(
          child: Opacity(
            opacity: opacity,
            child: _buildStamp(
              text: l10n?.superLikeStamp ?? 'SUPER LIKE',
              color: FikirColors.superLike,
              rotation: -0.1,
            ),
          ),
        ),
      );
    }

    if (isLike) {
      final opacity = (dx / 100.0).clamp(0.0, 1.0);
      return Positioned(
        top: 40,
        left: 30,
        child: Opacity(
          opacity: opacity,
          child: _buildStamp(
            text: l10n?.likeStamp ?? 'LIKE',
            color: FikirColors.like,
            rotation: -0.25,
          ),
        ),
      );
    }

    if (isNope) {
      final opacity = (-dx / 100.0).clamp(0.0, 1.0);
      return Positioned(
        top: 40,
        right: 30,
        child: Opacity(
          opacity: opacity,
          child: _buildStamp(
            text: l10n?.nopeStamp ?? 'NOPE',
            color: FikirColors.dislike,
            rotation: 0.25,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildStamp({
    required String text,
    required Color color,
    required double rotation,
  }) {
    return Transform.rotate(
      angle: rotation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 4),
          color: color.withValues(alpha: 0.15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
