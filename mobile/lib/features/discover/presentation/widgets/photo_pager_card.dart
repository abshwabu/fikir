import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/design/widgets/blurhash_image.dart';
import 'package:fikir/core/design/widgets/fikir_card.dart';
import 'package:fikir/features/discover/domain/discovery_card.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class PhotoPagerCard extends StatefulWidget {
  const PhotoPagerCard({
    required this.candidate,
    required this.onInfoTap,
    super.key,
  });

  final DiscoveryProfileCard candidate;
  final VoidCallback onInfoTap;

  @override
  State<PhotoPagerCard> createState() => _PhotoPagerCardState();
}

class _PhotoPagerCardState extends State<PhotoPagerCard> {
  int _photoIndex = 0;

  @override
  void didUpdateWidget(PhotoPagerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candidate.userId != widget.candidate.userId) {
      _photoIndex = 0;
    }
  }

  void _previousPhoto() {
    if (_photoIndex > 0) {
      setState(() => _photoIndex--);
    }
  }

  void _nextPhoto() {
    if (_photoIndex < widget.candidate.photos.length - 1) {
      setState(() => _photoIndex++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final photos = widget.candidate.photos;
    final currentPhoto = photos.isNotEmpty && _photoIndex < photos.length
        ? photos[_photoIndex]
        : null;

    final photoUrl = currentPhoto?.url ?? widget.candidate.primaryPhotoUrl;
    final blurHash = currentPhoto?.blurhash ?? widget.candidate.primaryBlurhash;

    return FikirCard(
      elevation: 6,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Photo with BlurHash placeholder
          FikirBlurHashImage(
            imageUrl: photoUrl,
            blurHash: blurHash,
          ),

          // 2. Bottom shadow gradient for readability
          Container(
            decoration: const BoxDecoration(
              gradient: FikirColors.photoOverlayGradient,
            ),
          ),

          // 3. Top segmented indicators
          if (photos.length > 1)
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Row(
                children: List.generate(photos.length, (index) {
                  return Expanded(
                    child: Container(
                      height: 3.5,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index == _photoIndex
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),

          // 4. Tap gesture areas for photo pagination (Left 35% / Right 35%)
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _previousPhoto,
                  ),
                ),
                const Spacer(),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _nextPhoto,
                  ),
                ),
              ],
            ),
          ),

          // 5. Bottom profile details overlay
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name, Age, Verified badge, Info button
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${widget.candidate.displayName}, ${widget.candidate.age}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.candidate.verified) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.verified,
                              color: Colors.lightBlueAccent,
                              size: 24,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Info button to open full details sheet
                    InkWell(
                      onTap: widget.onInfoTap,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // City and distance
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.candidate.city.isNotEmpty
                          ? '${widget.candidate.city} • ${l10n?.distanceKmAway(widget.candidate.distanceKm.round()) ?? '${widget.candidate.distanceKm.round()} km away'}'
                          : l10n?.distanceKmAway(widget.candidate.distanceKm.round()) ??
                              '${widget.candidate.distanceKm.round()} km away',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                // Bio snippet (if present)
                if (widget.candidate.bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.candidate.bio,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.3,
                      shadows: [
                        Shadow(color: Colors.black45, blurRadius: 4),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Top Interests
                if (widget.candidate.interests.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: widget.candidate.interests.take(4).map((interest) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          interest,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
