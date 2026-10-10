import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fikir/core/database/app_database.dart';
import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/design/widgets/blurhash_image.dart';
import 'package:fikir/core/network/websocket_manager.dart';
import 'package:fikir/core/storage/shared_prefs.dart';
import 'package:fikir/core/utils/image_cache_manager.dart';
import 'package:fikir/features/chat/data/chat_repository.dart';
import 'package:fikir/features/matches/data/match_repository.dart';
import 'package:fikir/features/profile/data/profile_repository.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

final chatMessagesStreamProvider = StreamProvider.family<List<CachedMessage>, String>((ref, matchId) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.watchMessages(matchId);
});

class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({
    required this.matchId,
    required this.matchedUserName,
    this.matchedUserPhotoUrl,
    this.matchedUserId,
    super.key,
  });

  final String matchId;
  final String matchedUserName;
  final String? matchedUserPhotoUrl;
  final String? matchedUserId;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();

  bool _isTypingSent = false;
  Timer? _typingDebounce;
  bool _showSafetyBanner = true;
  CachedMessage? _replyingToMessage;

  // Voice recording state
  bool _isRecordingVoice = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  late AnimationController _waveformAnimController;

  // Audio playback simulation state (messageId -> isPlaying)
  final Map<String, bool> _playingAudioMap = {};
  int _lastMarkedReadId = 0;

  int? _getHighestPartnerMsgId(List<CachedMessage> messages) {
    int? highest;
    for (final m in messages) {
      if (m.senderId != 'me') {
        final id = int.tryParse(m.id);
        if (id != null && (highest == null || id > highest)) {
          highest = id;
        }
      }
    }
    return highest;
  }

  @override
  void initState() {
    super.initState();
    _waveformAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _messageController.addListener(_onTextChanged);

    // Initial mark as read, replay missed messages, and ensure WS connected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(webSocketManagerProvider).connect();
      ref.read(chatRepositoryProvider).markAsRead(widget.matchId);
      ref.read(chatRepositoryProvider).replayMissed(widget.matchId);
    });
  }

  void _toggleAudioPlay(String msgId) {
    setState(() {
      final wasPlaying = _playingAudioMap[msgId] ?? false;
      _playingAudioMap[msgId] = !wasPlaying;
      final anyPlaying = _playingAudioMap.values.any((p) => p == true);
      if (anyPlaying) {
        if (!_waveformAnimController.isAnimating) {
          _waveformAnimController.repeat(reverse: true);
        }
      } else {
        _waveformAnimController.stop();
      }
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _typingDebounce?.cancel();
    _recordingTimer?.cancel();
    _waveformAnimController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _messageController.text;
    if (text.isNotEmpty && !_isTypingSent) {
      _isTypingSent = true;
      ref.read(chatRepositoryProvider).sendTyping(widget.matchId, isTyping: true);
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      if (_isTypingSent) {
        _isTypingSent = false;
        ref.read(chatRepositoryProvider).sendTyping(widget.matchId, isTyping: false);
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage({String type = 'text', String? mediaUrl, int? mediaDuration}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && type == 'text') return;

    var content = text;
    if (_replyingToMessage != null) {
      content = 'Replying to "${_replyingToMessage!.content}":\n$content';
    }

    _messageController.clear();
    setState(() {
      _replyingToMessage = null;
    });

    final repo = ref.read(chatRepositoryProvider);
    await repo.sendMessage(
      matchId: widget.matchId,
      senderId: 'me',
      content: content,
      type: type,
      mediaUrl: mediaUrl,
      mediaDuration: mediaDuration,
    );

    _scrollToBottom();
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(source: source);
      if (picked != null) {
        final repo = ref.read(chatRepositoryProvider);
        await repo.sendImageMessage(
          matchId: widget.matchId,
          senderId: 'me',
          filePath: picked.path,
        );
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('[Chat] Image pick error: $e');
    }
  }

  void _startVoiceRecording() {
    setState(() {
      _isRecordingVoice = true;
      _recordingSeconds = 0;
    });

    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_recordingSeconds >= 60) {
        _stopAndSendVoiceRecording();
      } else {
        setState(() {
          _recordingSeconds++;
        });
      }
    });
  }

  Future<void> _stopAndSendVoiceRecording() async {
    _recordingTimer?.cancel();
    final duration = _recordingSeconds;
    setState(() {
      _isRecordingVoice = false;
      _recordingSeconds = 0;
    });

    if (duration > 0) {
      final repo = ref.read(chatRepositoryProvider);
      await repo.sendVoiceMessage(
        matchId: widget.matchId,
        senderId: 'me',
        filePath: 'voice_note_${DateTime.now().millisecondsSinceEpoch}.wav',
        durationSec: duration,
      );
      _scrollToBottom();
    }
  }

  void _cancelVoiceRecording() {
    _recordingTimer?.cancel();
    setState(() {
      _isRecordingVoice = false;
      _recordingSeconds = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final messagesAsync = ref.watch(chatMessagesStreamProvider(widget.matchId));
    final isTyping = ref.watch(typingIndicatorProvider(widget.matchId)).value ?? false;
    final prefs = ref.watch(preferencesServiceProvider);
    final isMuted = prefs.isMatchMuted(widget.matchId);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.matchedUserPhotoUrl != null && widget.matchedUserPhotoUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(
                      normalizeMediaUrl(widget.matchedUserPhotoUrl),
                      cacheManager: FikirImageCacheManager.instance,
                    )
                  : null,
              child: (widget.matchedUserPhotoUrl == null || widget.matchedUserPhotoUrl!.isEmpty)
                  ? Text(widget.matchedUserName.isNotEmpty ? widget.matchedUserName[0] : 'U')
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.matchedUserName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    isTyping ? (l10n?.typing ?? 'typing...') : (l10n?.online ?? 'Online'),
                    style: TextStyle(
                      fontSize: 12,
                      color: isTyping ? FikirColors.primaryCoral : Colors.greenAccent.shade700,
                      fontStyle: isTyping ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isMuted ? Icons.notifications_off_rounded : Icons.notifications_outlined,
              color: isMuted ? Colors.amber : null,
            ),
            tooltip: isMuted
                ? (l10n?.unmuteMatch ?? 'Unmute')
                : (l10n?.muteMatch ?? 'Mute Notifications'),
            onPressed: () async {
              await prefs.setMatchMuted(widget.matchId, !isMuted);
              setState(() {});
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      !isMuted
                          ? (l10n?.muteMatch ?? 'Notifications muted')
                          : (l10n?.unmuteMatch ?? 'Notifications unmuted'),
                    ),
                  ),
                );
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (val) async {
              if (val == 'unmatch') {
                await ref.read(matchRepositoryProvider).unmatch(widget.matchId);
                if (context.mounted) Navigator.of(context).pop();
              } else if (val == 'report') {
                if (widget.matchedUserId != null) {
                  await ref.read(matchRepositoryProvider).reportUser(
                        reportedUserId: widget.matchedUserId!,
                        reason: 'Inappropriate chat behavior',
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n?.reportSubmitted ?? 'Report submitted.')),
                    );
                  }
                }
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'unmatch',
                child: Text(l10n?.unmatch ?? 'Unmatch'),
              ),
              PopupMenuItem(
                value: 'report',
                child: Text(l10n?.reportUser ?? 'Report User'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // First-time Chat Safety Warning Banner
            if (_showSafetyBanner)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_rounded, color: Colors.amber, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n?.safetyBannerTitle ?? 'Fikir Safety Tips',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.amber.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n?.safetyBannerText ??
                                'Never send money or share bank/CBE account numbers. Report suspicious accounts immediately.',
                            style: TextStyle(fontSize: 11.5, color: Colors.amber.shade900),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: Colors.amber.shade800,
                      onPressed: () => setState(() => _showSafetyBanner = false),
                    ),
                  ],
                ),
              ),

            // Message Stream List
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  // Defensive in-memory deduplication:
                  // 1) Collect server message IDs and signatures
                  final serverSignatures = <String>{};
                  for (final msg in messages) {
                    if (!msg.id.startsWith('msg_')) {
                      serverSignatures.add('${msg.matchId}_${msg.content}');
                    }
                  }

                  // 2) Deduplicate: keep all server messages; if an optimistic message has matching content, drop it
                  final seenIds = <String>{};
                  final dedupedMessages = <CachedMessage>[];
                  for (final msg in messages) {
                    if (!seenIds.add(msg.id)) continue;
                    if (msg.id.startsWith('msg_') &&
                        serverSignatures.contains('${msg.matchId}_${msg.content}')) {
                      continue;
                    }
                    dedupedMessages.add(msg);
                  }

                  if (dedupedMessages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Say hi to ${widget.matchedUserName}! 👋',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }

                  // Auto mark unread partner messages as read
                  final highestPartnerMsgId = _getHighestPartnerMsgId(dedupedMessages);
                  if (highestPartnerMsgId != null && highestPartnerMsgId > _lastMarkedReadId) {
                    _lastMarkedReadId = highestPartnerMsgId;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ref.read(chatRepositoryProvider).markAsRead(widget.matchId, upToId: highestPartnerMsgId);
                    });
                  }

                  final currentUserId = ref.watch(myUserProfileProvider).valueOrNull?.id;

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: dedupedMessages.length,
                    addAutomaticKeepAlives: false,
                    findChildIndexCallback: (Key key) {
                      if (key is ValueKey<String>) {
                        final idx = dedupedMessages.indexWhere((m) => m.id == key.value);
                        if (idx != -1) return idx;
                      }
                      return null;
                    },
                    itemBuilder: (context, index) {
                      final msg = dedupedMessages[index];
                      final isMe = msg.senderId == 'me' ||
                          (currentUserId != null && msg.senderId == currentUserId) ||
                          (widget.matchedUserId != null &&
                              widget.matchedUserId!.isNotEmpty &&
                              msg.senderId != widget.matchedUserId);

                      // Date separator check
                      final showDateSeparator = index == 0 ||
                          !_isSameDay(dedupedMessages[index - 1].createdAt, msg.createdAt);

                      return RepaintBoundary(
                        key: ValueKey(msg.id),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDateSeparator) _buildDateHeader(msg.createdAt),
                            _buildMessageBubble(msg, isMe),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),

            // Typing Indicator
            if (isTyping)
              Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(
                  '${widget.matchedUserName} ${l10n?.typing ?? "is typing..."}',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                    color: FikirColors.primaryCoral,
                  ),
                ),
              ),

            // Replying Banner
            if (_replyingToMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Theme.of(context).cardColor,
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded, color: FikirColors.primaryMagenta, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n?.replyingTo(widget.matchedUserName) ??
                                'Replying to ${widget.matchedUserName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: FikirColors.primaryMagenta,
                            ),
                          ),
                          Text(
                            _replyingToMessage!.content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => _replyingToMessage = null),
                    ),
                  ],
                ),
              ),

            // Bottom Input Row
            if (_isRecordingVoice) _buildVoiceRecordingBar() else _buildTextInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    String label;
    if (_isSameDay(now, date)) {
      label = 'Today';
    } else if (_isSameDay(now.subtract(const Duration(days: 1)), date)) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMMM d, y').format(date);
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildMessageBubble(CachedMessage msg, bool isMe) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        // Swipe right to reply
        if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
          setState(() {
            _replyingToMessage = msg;
          });
        }
      },
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.76,
          ),
          decoration: BoxDecoration(
            color: isMe ? FikirColors.primaryCoral : Theme.of(context).cardColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Content by type
              if (msg.type == 'image' && msg.mediaUrl != null)
                _buildImageContent(msg.mediaUrl!, isMe)
              else if (msg.type == 'voice')
                _buildVoiceContent(msg, isMe)
              else
                Text(
                  msg.content,
                  style: TextStyle(
                    color: isMe ? Colors.white : null,
                    fontSize: 15,
                  ),
                ),

              const SizedBox(height: 4),

              // Time and Delivery Status
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat.jm().format(msg.createdAt),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isMe ? Colors.white70 : Colors.grey.shade500,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildStatusIcon(msg),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageContent(String mediaUrl, bool isMe) {
    final normalized = normalizeMediaUrl(mediaUrl);
    final isLocal = !normalized.startsWith('http') && File(normalized).existsSync();
    final isHttp = normalized.startsWith('http');

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: isLocal
          ? Image.file(
              File(normalized),
              width: 220,
              height: 220,
              fit: BoxFit.cover,
            )
          : (isHttp
              ? FikirBlurHashImage(
                  imageUrl: normalized,
                  width: 220,
                  height: 220,
                )
              : Container(
                  width: 220,
                  height: 220,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 32),
                  ),
                )),
    );
  }

  Widget _buildVoiceContent(CachedMessage msg, bool isMe) {
    final isPlaying = _playingAudioMap[msg.id] ?? false;
    final duration = msg.mediaDuration ?? 10;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
            color: isMe ? Colors.white : FikirColors.primaryCoral,
            size: 32,
          ),
          onPressed: () => _toggleAudioPlay(msg.id),
        ),
        const SizedBox(width: 8),
        // Waveform Visualizer simulation
        Row(
          children: List.generate(12, (index) {
            final heights = [10.0, 18.0, 24.0, 14.0, 28.0, 20.0, 16.0, 26.0, 22.0, 12.0, 18.0, 14.0];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: isPlaying ? heights[index] * _waveformAnimController.value : heights[index] * 0.7,
              decoration: BoxDecoration(
                color: isMe ? Colors.white70 : FikirColors.primaryCoral.withAlpha(178),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
        const SizedBox(width: 10),
        Text(
          '0:${duration.toString().padLeft(2, '0')}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isMe ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIcon(CachedMessage msg) {
    switch (msg.status) {
      case 'pending':
        return const Icon(Icons.access_time_rounded, size: 12, color: Colors.white70);
      case 'sent':
        return const Icon(Icons.check_rounded, size: 14, color: Colors.white70);
      case 'delivered':
        return const Icon(Icons.done_all_rounded, size: 14, color: Colors.white70);
      case 'read':
        return const Icon(Icons.done_all_rounded, size: 14, color: Colors.lightBlueAccent);
      case 'failed':
      default:
        return GestureDetector(
          onTap: () {
            ref.read(chatRepositoryProvider).retryMessage(msg);
          },
          child: const Icon(Icons.error_outline_rounded, size: 14, color: Colors.yellowAccent),
        );
    }
  }

  Widget _buildTextInputBar() {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick Emoji Bar
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['❤️', '😍', '👋', '😂', '🔥', '✨', '☕️', '🌹'].map((emoji) {
                return GestureDetector(
                  onTap: () {
                    _messageController.text = '${_messageController.text}$emoji';
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Text(emoji, style: const TextStyle(fontSize: 18)),
                  ),
                );
              }).toList(),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _messageController,
            builder: (context, value, _) {
              final hasText = value.text.trim().isNotEmpty;
              return Row(
                children: [
                  // Photo attachment button
                  IconButton(
                    icon: const Icon(Icons.photo_camera_rounded, color: FikirColors.primaryMagenta),
                    onPressed: () {
                      _pickAndSendImage(ImageSource.gallery);
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: l10n?.typeMessage ?? 'Type a message...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Mic / Voice Button or Prominent Send Button
                  if (hasText)
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: FikirColors.primaryCoral,
                      ),
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.mic_rounded, color: FikirColors.primaryCoral, size: 26),
                      onPressed: _startVoiceRecording,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceRecordingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          // Flashing Recording Indicator
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: FikirColors.dislike,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Recording 0:${_recordingSeconds.toString().padLeft(2, '0')} / 1:00',
            style: const TextStyle(fontWeight: FontWeight.bold, color: FikirColors.dislike),
          ),
          const Spacer(),
          TextButton(
            onPressed: _cancelVoiceRecording,
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: FikirColors.primaryCoral),
            icon: const Icon(Icons.send_rounded, color: Colors.white),
            onPressed: _stopAndSendVoiceRecording,
          ),
        ],
      ),
    );
  }
}
