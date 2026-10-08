import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/design/widgets/blurhash_image.dart';
import 'package:fikir/core/design/widgets/gradient_button.dart';
import 'package:fikir/features/discover/domain/discovery_card.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class MatchCelebrationDialog extends StatefulWidget {
  const MatchCelebrationDialog({
    required this.matchedCandidate,
    required this.onKeepSwiping,
    this.matchId,
    this.currentUserPhotoUrl,
    super.key,
  });

  final DiscoveryProfileCard matchedCandidate;
  final String? matchId;
  final String? currentUserPhotoUrl;
  final VoidCallback onKeepSwiping;

  static void show(
    BuildContext context, {
    required DiscoveryProfileCard matchedCandidate,
    required VoidCallback onKeepSwiping,
    String? matchId,
    String? currentUserPhotoUrl,
  }) {
    showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      pageBuilder: (ctx, anim1, anim2) {
        return MatchCelebrationDialog(
          matchedCandidate: matchedCandidate,
          matchId: matchId,
          currentUserPhotoUrl: currentUserPhotoUrl,
          onKeepSwiping: onKeepSwiping,
        );
      },
    );
  }

  @override
  State<MatchCelebrationDialog> createState() => _MatchCelebrationDialogState();
}

class _MatchCelebrationDialogState extends State<MatchCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _heartBounceAnimation;
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    // Celebratory Haptic Feedback
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 150), HapticFeedback.mediumImpact);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );

    _heartBounceAnimation = Tween<double>(begin: 0.7, end: 1.15).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOut,
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onSendMessage() {
    Navigator.of(context).pop();
    widget.onKeepSwiping();
    // Navigate to chat
    if (widget.matchId != null && widget.matchId!.isNotEmpty) {
      context.go('/chat/${widget.matchId}');
    } else {
      context.go('/chat');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final matchName = widget.matchedCandidate.displayName;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Sound toggle button at top right
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(
                      _soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                      color: Colors.white70,
                      size: 26,
                    ),
                    onPressed: () {
                      setState(() => _soundEnabled = !_soundEnabled);
                    },
                    tooltip: _soundEnabled
                        ? (l10n?.soundEnabled ?? 'Sound On')
                        : (l10n?.soundDisabled ?? 'Sound Off'),
                  ),
                ),
                const Spacer(),

                // Festive Title
                ShaderMask(
                  shaderCallback: (bounds) => FikirColors.primaryGradient.createShader(bounds),
                  child: Text(
                    l10n?.matchCelebrationTitle ?? "It's a Match! 🎉",
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle
                Text(
                  l10n?.matchSubtitle(matchName) ?? 'You and $matchName liked each other.',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Overlapping Avatars with Center Heart
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: SizedBox(
                    height: 160,
                    width: 270,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Left Avatar (Current User)
                        Positioned(
                          left: 10,
                          child: _buildAvatarCircle(
                            url: widget.currentUserPhotoUrl ??
                                'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
                          ),
                        ),

                        // Right Avatar (Matched User)
                        Positioned(
                          right: 10,
                          child: _buildAvatarCircle(
                            url: widget.matchedCandidate.primaryPhotoUrl,
                            blurHash: widget.matchedCandidate.primaryBlurhash,
                          ),
                        ),

                        // Center Animated Heart
                        ScaleTransition(
                          scale: _heartBounceAnimation,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: FikirColors.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: FikirColors.primaryCoral.withValues(alpha: 0.6),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(flex: 2),

                // Action 1: Send Message
                GradientButton(
                  text: l10n?.sendMessage ?? 'Send Message',
                  icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
                  onPressed: _onSendMessage,
                ),
                const SizedBox(height: 16),

                // Action 2: Keep Swiping
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54, width: 1.5),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onKeepSwiping();
                  },
                  child: Text(
                    l10n?.keepSwiping ?? 'Keep Swiping',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarCircle({required String url, String? blurHash}) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: FikirBlurHashImage(
          imageUrl: url,
          blurHash: blurHash,
        ),
      ),
    );
  }
}
