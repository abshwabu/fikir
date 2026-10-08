import 'dart:ui';

import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/design/widgets/blurhash_image.dart';
import 'package:fikir/core/design/widgets/fikir_card.dart';
import 'package:fikir/core/design/widgets/gradient_button.dart';
import 'package:fikir/features/likes/data/likes_repository.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final likesStreamProvider = FutureProvider<LikesResponse>((ref) async {
  final isPremium = ref.watch(isPremiumProvider);
  final repo = ref.watch(likesRepositoryProvider);
  return repo.fetchLikes(isPremium: isPremium);
});

class LikesScreen extends ConsumerWidget {
  const LikesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isPremium = ref.watch(isPremiumProvider);
    final likesAsync = ref.watch(likesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.likesYouTitle ?? 'Likes You'),
        actions: [
          TextButton.icon(
            icon: Icon(
              isPremium ? Icons.star_rounded : Icons.star_outline_rounded,
              color: isPremium ? const Color(0xFFFFD700) : null,
              size: 20,
            ),
            label: Text(
              isPremium ? 'Gold Active' : 'Gold',
              style: TextStyle(
                color: isPremium ? const Color(0xFFFFD700) : null,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () {
              ref.read(isPremiumProvider.notifier).state = !isPremium;
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(likesStreamProvider.future),
        child: likesAsync.when(
          data: (response) {
            final profiles = response.profiles;

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Fikir Gold Upsell Banner (if free user)
                if (!isPremium)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF9D423), Color(0xFFFF4E50)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF4E50).withAlpha(76),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.white24,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.star_rounded, color: Colors.white, size: 32),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n?.seeWhoLikesYou ?? 'See Who Likes You',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      l10n?.upgradeToGoldLikes ??
                                          'Upgrade to Fikir Gold to see everyone who likes you',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFFF4E50),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () {
                                _showFikirGoldDialog(context, ref);
                              },
                              child: Text(
                                l10n?.getFikirGold ?? 'Get Fikir Gold',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Likes Count Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          '${profiles.length} ${l10n?.likesYouTitle ?? "Likes"}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const Spacer(),
                        if (!isPremium)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.lock_rounded, size: 14, color: Colors.amber.shade900),
                                const SizedBox(width: 4),
                                Text(
                                  'Blurred',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Grid of profiles
                if (profiles.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.favorite_border_rounded, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            l10n?.noLikesYet ?? 'No likes yet',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n?.noLikesDesc ?? 'Keep your profile active and updated to get noticed!',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.72,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final profile = profiles[index];
                          return _buildLikeCard(
                            context: context,
                            ref: ref,
                            profile: profile,
                            isPremium: isPremium,
                          );
                        },
                        childCount: profiles.length,
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  Widget _buildLikeCard({
    required BuildContext context,
    required WidgetRef ref,
    required LikedUserProfile profile,
    required bool isPremium,
  }) {
    return GestureDetector(
      onTap: () {
        if (!isPremium) {
          _showFikirGoldDialog(context, ref);
        } else {
          _openProfileModal(context, ref, profile);
        }
      },
      child: FikirCard(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo with optional blur
            FikirBlurHashImage(
              imageUrl: isPremium ? profile.photoUrl : (profile.blurredPhotoUrl ?? profile.photoUrl),
              blurHash: profile.blurhash,
            ),

            // If not premium, apply heavy frosted blur
            if (!isPremium)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: ColoredBox(
                    color: Colors.black.withAlpha(51),
                    child: const Center(
                      child: Icon(Icons.lock_rounded, color: Colors.white70, size: 36),
                    ),
                  ),
                ),
              ),

            // Gradient Overlay
            Container(
              decoration: const BoxDecoration(
                gradient: FikirColors.photoOverlayGradient,
              ),
            ),

            // Information
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          isPremium ? '${profile.name}, ${profile.age}' : '${profile.name[0]}***, ${profile.age}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (profile.isVerified && isPremium) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: Colors.lightBlueAccent, size: 16),
                      ],
                    ],
                  ),
                  Text(
                    profile.city,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFikirGoldDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 28),
            const SizedBox(width: 8),
            Text(l10n?.getFikirGold ?? 'Fikir Gold'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.upgradeToGoldLikes ?? 'Upgrade to Fikir Gold to see everyone who likes you',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.visibility_rounded, color: FikirColors.primaryCoral),
              title: Text('See who liked you instantly'),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.refresh_rounded, color: Colors.amber),
              title: Text('Unlimited Rewinds'),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.bolt_rounded, color: Colors.purpleAccent),
              title: Text('1 Free Boost per week'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          GradientButton(
            text: 'Activate Gold (Demo)',
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(isPremiumProvider.notifier).state = true;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fikir Gold unlocked! Photos unblurred.')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openProfileModal(BuildContext context, WidgetRef ref, LikedUserProfile profile) {
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Sheet Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Scrollable Details
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Main Photo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: FikirBlurHashImage(
                        imageUrl: profile.photoUrl,
                        blurHash: profile.blurhash,
                        height: 380,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name and Age
                    Row(
                      children: [
                        Text(
                          '${profile.name}, ${profile.age}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        if (profile.isVerified) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.verified, color: Colors.lightBlueAccent, size: 22),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.city,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                    ),
                    const SizedBox(height: 16),

                    // Bio
                    if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                      Text(
                        l10n?.bio ?? 'Bio',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        profile.bio!,
                        style: const TextStyle(fontSize: 15, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),

              // Action Buttons Row (Nope / Like)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Nope button
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: FikirColors.dislike,
                        elevation: 4,
                        padding: const EdgeInsets.all(16),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 32),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await ref.read(likesRepositoryProvider).pass(profile.id);
                        ref.invalidate(likesStreamProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Passed on ${profile.name}')),
                          );
                        }
                      },
                    ),

                    // Like-back button
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: FikirColors.like,
                        elevation: 4,
                        padding: const EdgeInsets.all(16),
                      ),
                      icon: const Icon(Icons.favorite_rounded, size: 32),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await ref.read(likesRepositoryProvider).likeBack(profile.id);
                        ref.invalidate(likesStreamProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("It's a Match with ${profile.name}! 🎉"),
                              backgroundColor: FikirColors.like,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
