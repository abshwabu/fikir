import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/design/widgets/blurhash_image.dart';
import 'package:fikir/features/discover/domain/discovery_card.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class CandidateDetailSheet extends StatefulWidget {
  const CandidateDetailSheet({
    required this.candidate,
    required this.onLike,
    required this.onNope,
    required this.onSuperLike,
    required this.onReport,
    required this.onBlock,
    super.key,
  });

  final DiscoveryProfileCard candidate;
  final VoidCallback onLike;
  final VoidCallback onNope;
  final VoidCallback onSuperLike;
  final void Function(String reason) onReport;
  final VoidCallback onBlock;

  static void show(
    BuildContext context, {
    required DiscoveryProfileCard candidate,
    required VoidCallback onLike,
    required VoidCallback onNope,
    required VoidCallback onSuperLike,
    required void Function(String reason) onReport,
    required VoidCallback onBlock,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CandidateDetailSheet(
        candidate: candidate,
        onLike: onLike,
        onNope: onNope,
        onSuperLike: onSuperLike,
        onReport: onReport,
        onBlock: onBlock,
      ),
    );
  }

  @override
  State<CandidateDetailSheet> createState() => _CandidateDetailSheetState();
}

class _CandidateDetailSheetState extends State<CandidateDetailSheet> {
  int _currentPhotoIndex = 0;

  void _showReportDialog() {
    final l10n = AppLocalizations.of(context);
    final reasons = [
      l10n?.reportReasonInappropriate ?? 'Inappropriate photos or bio',
      l10n?.reportReasonSpam ?? 'Spam or scam account',
      l10n?.reportReasonHarassment ?? 'Harassment or offensive behavior',
      l10n?.reportReasonFake ?? 'Fake profile or impersonation',
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.reportUser ?? 'Report User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((reason) {
            return ListTile(
              title: Text(reason),
              onTap: () {
                Navigator.of(ctx).pop();
                widget.onReport(reason);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      l10n?.reportSubmitted ?? 'Report submitted. Thank you.',
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.blockUser ?? 'Block User'),
        content: Text(
          'Are you sure you want to block ${widget.candidate.displayName}? You will no longer see each other.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: FikirColors.dislike,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onBlock();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n?.userBlocked ?? 'User blocked.'),
                ),
              );
            },
            child: Text(l10n?.blockUser ?? 'Block'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final photos = widget.candidate.photos;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Stack(
            children: [
              CustomScrollView(
                controller: scrollController,
                slivers: [
                  // Photo Carousel Header
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 420,
                      child: Stack(
                        children: [
                          PageView.builder(
                            itemCount: photos.isNotEmpty ? photos.length : 1,
                            onPageChanged: (i) => setState(() => _currentPhotoIndex = i),
                            itemBuilder: (context, index) {
                              final photo = photos.isNotEmpty ? photos[index] : null;
                              return FikirBlurHashImage(
                                imageUrl: photo?.url ?? widget.candidate.primaryPhotoUrl,
                                blurHash: photo?.blurhash ?? widget.candidate.primaryBlurhash,
                              );
                            },
                          ),
                          // Indicators
                          if (photos.length > 1)
                            Positioned(
                              bottom: 16,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(photos.length, (i) {
                                  return Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: i == _currentPhotoIndex
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.4),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          // Close button
                          Positioned(
                            top: 16,
                            right: 16,
                            child: InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_downward_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Main Content
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name, Age, Verified badge
                          Row(
                            children: [
                              Text(
                                '${widget.candidate.displayName}, ${widget.candidate.age}',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.candidate.verified) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.verified,
                                  color: Colors.lightBlueAccent,
                                  size: 26,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Location & Distance
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.candidate.city.isNotEmpty
                                    ? '${widget.candidate.city} • ${l10n?.distanceKmAway(widget.candidate.distanceKm.round()) ?? '${widget.candidate.distanceKm.round()} km away'}'
                                    : l10n?.distanceKmAway(widget.candidate.distanceKm.round()) ??
                                        '${widget.candidate.distanceKm.round()} km away',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Bio
                          if (widget.candidate.bio.isNotEmpty) ...[
                            Text(
                              l10n?.aboutMe ?? 'About Me',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.candidate.bio,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Details info cards
                          _buildDetailsGrid(theme, l10n),
                          const SizedBox(height: 20),

                          // Interests
                          if (widget.candidate.interests.isNotEmpty) ...[
                            Text(
                              l10n?.interests ?? 'Interests',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: widget.candidate.interests.map((interest) {
                                return Chip(
                                  label: Text(interest),
                                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),
                          ],

                          const Divider(),
                          const SizedBox(height: 12),

                          // Safety buttons: Report and Block
                          Center(
                            child: Column(
                              children: [
                                TextButton.icon(
                                  onPressed: _showReportDialog,
                                  icon: const Icon(
                                    Icons.flag_outlined,
                                    color: Colors.grey,
                                  ),
                                  label: Text(
                                    '${l10n?.reportUser ?? 'Report'} ${widget.candidate.displayName}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _showBlockDialog,
                                  icon: const Icon(
                                    Icons.block_outlined,
                                    color: Colors.redAccent,
                                  ),
                                  label: Text(
                                    '${l10n?.blockUser ?? 'Block'} ${widget.candidate.displayName}',
                                    style: const TextStyle(color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 80), // Padding for bottom actions
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Bottom floating actions
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildFloatingButton(
                        icon: Icons.close_rounded,
                        color: FikirColors.dislike,
                        size: 56,
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onNope();
                        },
                      ),
                      const SizedBox(width: 20),
                      _buildFloatingButton(
                        icon: Icons.star_rounded,
                        color: FikirColors.superLike,
                        size: 48,
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onSuperLike();
                        },
                      ),
                      const SizedBox(width: 20),
                      _buildFloatingButton(
                        icon: Icons.favorite_rounded,
                        color: FikirColors.like,
                        size: 56,
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onLike();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailsGrid(ThemeData theme, AppLocalizations? l10n) {
    final details = <Map<String, dynamic>>[];

    if (widget.candidate.jobTitle.isNotEmpty) {
      details.add({
        'icon': Icons.work_outline,
        'label': widget.candidate.jobTitle,
      });
    }
    if (widget.candidate.education.isNotEmpty) {
      details.add({
        'icon': Icons.school_outlined,
        'label': widget.candidate.education,
      });
    }
    if (widget.candidate.religion.isNotEmpty) {
      details.add({
        'icon': Icons.church_outlined,
        'label': widget.candidate.religion,
      });
    }
    if (widget.candidate.heightCm != null && widget.candidate.heightCm! > 0) {
      details.add({
        'icon': Icons.height_outlined,
        'label': '${widget.candidate.heightCm} cm',
      });
    }

    if (details.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: details.map((d) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(d['icon'] as IconData, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                d['label'] as String,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required Color color,
    required double size,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: size * 0.55),
        onPressed: onPressed,
      ),
    );
  }
}
