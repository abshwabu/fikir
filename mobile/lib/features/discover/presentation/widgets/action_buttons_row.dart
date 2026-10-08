import 'package:fikir/core/design/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ActionButtonsRow extends StatelessWidget {
  const ActionButtonsRow({
    required this.onRewind,
    required this.onNope,
    required this.onSuperLike,
    required this.onLike,
    required this.onBoost,
    this.canRewind = true,
    super.key,
  });

  final VoidCallback onRewind;
  final VoidCallback onNope;
  final VoidCallback onSuperLike;
  final VoidCallback onLike;
  final VoidCallback onBoost;
  final bool canRewind;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Rewind (Gold, small)
          _AnimatedActionButton(
            icon: Icons.replay_rounded,
            color: canRewind ? FikirColors.gold : Colors.grey.shade400,
            size: 46,
            iconSize: 24,
            onPressed: canRewind
                ? () {
                    HapticFeedback.lightImpact();
                    onRewind();
                  }
                : null,
          ),

          // Nope (Coral, large)
          _AnimatedActionButton(
            icon: Icons.close_rounded,
            color: FikirColors.dislike,
            size: 58,
            iconSize: 32,
            onPressed: () {
              HapticFeedback.mediumImpact();
              onNope();
            },
          ),

          // Super Like (Blue, medium)
          _AnimatedActionButton(
            icon: Icons.star_rounded,
            color: FikirColors.superLike,
            size: 48,
            iconSize: 28,
            onPressed: () {
              HapticFeedback.heavyImpact();
              onSuperLike();
            },
          ),

          // Like (Green, large)
          _AnimatedActionButton(
            icon: Icons.favorite_rounded,
            color: FikirColors.like,
            size: 58,
            iconSize: 32,
            onPressed: () {
              HapticFeedback.mediumImpact();
              onLike();
            },
          ),

          // Boost (Purple, small)
          _AnimatedActionButton(
            icon: Icons.bolt_rounded,
            color: FikirColors.boost,
            size: 46,
            iconSize: 24,
            onPressed: () {
              HapticFeedback.lightImpact();
              onBoost();
            },
          ),
        ],
      ),
    );
  }
}

class _AnimatedActionButton extends StatefulWidget {
  const _AnimatedActionButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.iconSize,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final VoidCallback? onPressed;

  @override
  State<_AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<_AnimatedActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.86).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed != null) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onPressed != null) {
      _controller.reverse();
      widget.onPressed?.call();
    }
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            color: widget.color,
            size: widget.iconSize,
          ),
        ),
      ),
    );
  }
}
