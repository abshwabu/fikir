import 'dart:async';

import 'package:fikir/core/database/app_database.dart';
import 'package:fikir/core/storage/shared_prefs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PushNotificationEvent {
  const PushNotificationEvent({
    required this.type,
    required this.targetRoute,
    this.title,
    this.body,
    this.matchId,
    this.senderName,
    this.badgeCount,
  });

  final String type; // 'new_message', 'new_match', 'super_like'
  final String targetRoute;
  final String? title;
  final String? body;
  final String? matchId;
  final String? senderName;
  final int? badgeCount;
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  final db = ref.watch(databaseProvider);
  return PushNotificationService(prefs: prefs, db: db);
});

class PushNotificationService {
  PushNotificationService({
    required PreferencesService prefs,
    required AppDatabase db,
  })  : _prefs = prefs,
        _db = db;

  final PreferencesService _prefs;
  final AppDatabase _db;

  final _eventController = StreamController<PushNotificationEvent>.broadcast();
  Stream<PushNotificationEvent> get onNotificationTapped => _eventController.stream;

  // Notification Channel Constants (Android)
  static const channelMessagesId = 'fikir_messages';
  static const channelMessagesName = 'Fikir Messages';
  static const channelMatchesId = 'fikir_matches';
  static const channelMatchesName = 'Fikir Matches';

  /// Parses incoming notification data from FCM/APNs.
  /// Returns a [PushNotificationEvent] if the notification should be shown, or null if filtered/muted.
  Future<PushNotificationEvent?> handleIncomingNotification(Map<String, dynamic> data) async {
    final type = data['type'] as String? ?? 'general';
    final matchId = data['match_id'] as String?;
    final senderName = data['sender_name'] as String?;
    final title = data['title'] as String?;
    final body = data['body'] as String?;

    // Check notification type preferences
    if (type == 'new_message') {
      if (!_prefs.getNotifyMessage()) {
        debugPrint('[Push] Message notifications disabled in settings');
        return null;
      }
      if (matchId != null && _prefs.isMatchMuted(matchId)) {
        debugPrint('[Push] Notification suppressed for muted match $matchId');
        return null;
      }
    } else if (type == 'new_match' && !_prefs.getNotifyMatch()) {
      debugPrint('[Push] Match notifications disabled in settings');
      return null;
    } else if (type == 'super_like' && !_prefs.getNotifySuperLike()) {
      debugPrint('[Push] Super like notifications disabled in settings');
      return null;
    }

    final targetRoute = _determineRoute(type, matchId);
    final badge = await getUnreadBadgeCount();

    final event = PushNotificationEvent(
      type: type,
      targetRoute: targetRoute,
      title: title,
      body: body,
      matchId: matchId,
      senderName: senderName,
      badgeCount: badge,
    );

    return event;
  }

  /// Triggers user tap navigation for deep linking.
  void onUserTappedNotification(PushNotificationEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  String _determineRoute(String type, String? matchId) {
    switch (type) {
      case 'new_message':
        return matchId != null ? '/chat/$matchId' : '/chat';
      case 'new_match':
        return matchId != null ? '/chat/$matchId' : '/matches';
      case 'super_like':
        return '/likes';
      default:
        return '/discover';
    }
  }

  /// Calculates total unread message badge count across all matches in local database.
  Future<int> getUnreadBadgeCount() async {
    try {
      final matches = await _db.getMatches();
      return matches.fold<int>(0, (sum, m) => sum + m.unreadCount);
    } catch (_) {
      return 0;
    }
  }

  void dispose() {
    _eventController.close();
  }
}
