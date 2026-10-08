import 'package:fikir/core/database/app_database.dart';
import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/design/widgets/blurhash_image.dart';
import 'package:fikir/core/network/websocket_manager.dart';
import 'package:fikir/features/matches/data/match_repository.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

final matchesStreamProvider = StreamProvider<List<CachedMatch>>((ref) {
  final repo = ref.watch(matchRepositoryProvider);
  return repo.watchMatches();
});

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final matchesAsync = ref.watch(matchesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.navMatches ?? 'Matches'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(matchRepositoryProvider).refreshMatches(),
        child: matchesAsync.when(
          data: (matches) {
            if (matches.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_border_rounded, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      l10n?.noMatchesYet ?? 'No matches yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n?.noMatchesDesc ?? 'Keep swiping to find someone special!',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final newMatches = matches.where((m) => m.lastMessageText == null || m.lastMessageText!.isEmpty).toList();
            final activeConversations = matches.where((m) => m.lastMessageText != null && m.lastMessageText!.isNotEmpty).toList();

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // 1. Horizontal "New Matches" Row
                if (newMatches.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        l10n?.newMatches ?? 'New Matches',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 104,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: newMatches.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final match = newMatches[index];
                          return _buildNewMatchBubble(context, ref, match);
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: Divider(height: 24)),
                ],

                // 2. Messages Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      l10n?.messages ?? 'Messages',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),

                // 3. Conversation List with Swipe Actions
                if (activeConversations.isEmpty && newMatches.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'Tap a new match above to start chatting!',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final match = activeConversations[index];
                        return _buildConversationTile(context, ref, match);
                      },
                      childCount: activeConversations.length,
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading matches: $err')),
        ),
      ),
    );
  }

  Widget _buildNewMatchBubble(BuildContext context, WidgetRef ref, CachedMatch match) {
    final isOnline = ref.watch(userPresenceProvider(match.matchedUserId)).value ?? false;

    return GestureDetector(
      onTap: () {
        context.push(
          '/chat/${match.id}',
          extra: {
            'name': match.matchedUserName,
            'photo_url': match.matchedUserPhotoUrl,
            'user_id': match.matchedUserId,
          },
        );
      },
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: FikirColors.primaryGradient,
                ),
                padding: const EdgeInsets.all(2.5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(34),
                  child: FikirBlurHashImage(
                    imageUrl: match.matchedUserPhotoUrl ?? '',
                    blurHash: match.matchedUserBlurhash,
                    width: 64,
                    height: 64,
                  ),
                ),
              ),
              if (isOnline)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.shade700,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 72,
            child: Text(
              match.matchedUserName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(BuildContext context, WidgetRef ref, CachedMatch match) {
    final l10n = AppLocalizations.of(context);
    final isTyping = ref.watch(typingIndicatorProvider(match.id)).value ?? false;
    final isOnline = ref.watch(userPresenceProvider(match.matchedUserId)).value ?? false;

    return Dismissible(
      key: Key('match_${match.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: FikirColors.dislike,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.heart_broken_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Unmatch',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return _showActionDialog(context, ref, match);
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: FikirBlurHashImage(
                imageUrl: match.matchedUserPhotoUrl ?? '',
                blurHash: match.matchedUserBlurhash,
                width: 56,
                height: 56,
              ),
            ),
            if (isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.shade700,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                match.matchedUserName,
                style: TextStyle(
                  fontWeight: match.unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (match.lastMessageAt != null)
              Text(
                _formatTimestamp(match.lastMessageAt!),
                style: TextStyle(
                  fontSize: 12,
                  color: match.unreadCount > 0 ? FikirColors.primaryMagenta : Colors.grey.shade500,
                ),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                isTyping ? (l10n?.typing ?? 'typing...') : (match.lastMessageText ?? ''),
                style: TextStyle(
                  color: isTyping
                      ? FikirColors.primaryCoral
                      : (match.unreadCount > 0 ? Colors.black87 : Colors.grey.shade600),
                  fontStyle: isTyping ? FontStyle.italic : FontStyle.normal,
                  fontWeight: match.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (match.unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: const BoxDecoration(
                  gradient: FikirColors.primaryGradient,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: Text(
                  '${match.unreadCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        onTap: () {
          context.push(
            '/chat/${match.id}',
            extra: {
              'name': match.matchedUserName,
              'photo_url': match.matchedUserPhotoUrl,
              'user_id': match.matchedUserId,
            },
          );
        },
        onLongPress: () {
          _showActionDialog(context, ref, match);
        },
      ),
    );
  }

  String _formatTimestamp(DateTime at) {
    final now = DateTime.now();
    final diff = now.difference(at);
    if (diff.inDays == 0) {
      return DateFormat.jm().format(at);
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat.E().format(at);
    } else {
      return DateFormat('MMM d').format(at);
    }
  }

  Future<bool> _showActionDialog(BuildContext context, WidgetRef ref, CachedMatch match) async {
    final l10n = AppLocalizations.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.heart_broken_rounded, color: FikirColors.dislike),
              title: Text(l10n?.unmatch ?? 'Unmatch ${match.matchedUserName}'),
              onTap: () => Navigator.of(ctx).pop('unmatch'),
            ),
            ListTile(
              leading: const Icon(Icons.report_problem_outlined, color: Colors.amber),
              title: Text(l10n?.reportUser ?? 'Report User'),
              onTap: () => Navigator.of(ctx).pop('report'),
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: Colors.grey),
              title: Text(l10n?.blockUser ?? 'Block User'),
              onTap: () => Navigator.of(ctx).pop('block'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return false;

    if (action == 'unmatch') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n?.unmatch ?? 'Unmatch'),
          content: Text(
            l10n?.unmatchConfirm(match.matchedUserName) ??
                'Are you sure you want to unmatch ${match.matchedUserName}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: FikirColors.dislike,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n?.unmatch ?? 'Unmatch'),
            ),
          ],
        ),
      );

      if (confirmed ?? false) {
        await ref.read(matchRepositoryProvider).unmatch(match.id);
        return true;
      }
    } else if (action == 'report') {
      _showReportSheet(context, ref, match);
    } else if (action == 'block') {
      await ref.read(matchRepositoryProvider).blockUser(match.matchedUserId, matchId: match.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.userBlocked ?? 'User blocked.')),
        );
      }
      return true;
    }

    return false;
  }

  void _showReportSheet(BuildContext context, WidgetRef ref, CachedMatch match) {
    final l10n = AppLocalizations.of(context);
    final reasons = [
      l10n?.reportReasonInappropriate ?? 'Inappropriate photos or bio',
      l10n?.reportReasonSpam ?? 'Spam or scam account',
      l10n?.reportReasonHarassment ?? 'Harassment or offensive behavior',
      l10n?.reportReasonFake ?? 'Fake profile or impersonation',
    ];

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  l10n?.reportUser ?? 'Report User',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const SizedBox(height: 12),
              ...reasons.map(
                (reason) => ListTile(
                  title: Text(reason),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await ref.read(matchRepositoryProvider).reportUser(
                          reportedUserId: match.matchedUserId,
                          reason: reason,
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n?.reportSubmitted ?? 'Report submitted. Thank you for keeping Fikir safe.',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
