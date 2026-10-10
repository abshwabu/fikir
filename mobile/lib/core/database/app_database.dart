import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_database.g.dart';

class CachedProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get bio => text().nullable()();
  DateTimeColumn get birthdate => dateTime()();
  TextColumn get gender => text()();
  TextColumn get city => text().nullable()();
  TextColumn get photosJson => text()();
  TextColumn get interestsJson => text()();
  IntColumn get completenessScore => integer().withDefault(const Constant(0))();
  BoolColumn get isVerified => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastActiveAt => dateTime().nullable()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CachedMatch')
class CachedMatches extends Table {
  TextColumn get id => text()();
  TextColumn get matchedUserId => text()();
  TextColumn get matchedUserName => text()();
  TextColumn get matchedUserPhotoUrl => text().nullable()();
  TextColumn get matchedUserBlurhash => text().nullable()();
  TextColumn get lastMessageText => text().nullable()();
  DateTimeColumn get lastMessageAt => dateTime().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class CachedMessages extends Table {
  TextColumn get id => text()();
  TextColumn get matchId => text()();
  TextColumn get senderId => text()();
  TextColumn get type => text()(); // text, image, voice
  TextColumn get content => text()();
  TextColumn get mediaUrl => text().nullable()();
  IntColumn get mediaDuration => integer().nullable()();
  TextColumn get status => text()(); // pending, sent, delivered, read
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SwipeOutboxEntry')
class SwipeOutbox extends Table {
  TextColumn get id => text()();
  TextColumn get targetUserId => text()();
  TextColumn get direction => text()(); // like, nope, super
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, syncing, synced, failed
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [CachedProfiles, CachedMatches, CachedMessages, SwipeOutbox])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'fikir_cache_db');
  }

  // --- Profile Operations ---
  Future<void> upsertProfile(CachedProfile profile) {
    return into(cachedProfiles).insertOnConflictUpdate(profile);
  }

  Future<CachedProfile?> getProfile(String id) {
    return (select(cachedProfiles)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Stream<CachedProfile?> watchProfile(String id) {
    return (select(cachedProfiles)..where((tbl) => tbl.id.equals(id))).watchSingleOrNull();
  }

  Stream<List<CachedProfile>> watchAllProfiles() {
    return select(cachedProfiles).watch();
  }

  Future<List<CachedProfile>> getAllProfiles() {
    return select(cachedProfiles).get();
  }

  Future<void> clearProfiles() {
    return delete(cachedProfiles).go();
  }

  // --- Match Operations ---
  Future<void> upsertMatch(CachedMatch match) {
    return into(cachedMatches).insertOnConflictUpdate(match);
  }

  Stream<List<CachedMatch>> watchMatches() {
    return (select(cachedMatches)
          ..orderBy([
            (tbl) => OrderingTerm(
                  expression: tbl.lastMessageAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }

  Future<List<CachedMatch>> getMatches() {
    return (select(cachedMatches)
          ..orderBy([
            (tbl) => OrderingTerm(
                  expression: tbl.lastMessageAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  Future<void> deleteMatch(String id) async {
    await (delete(cachedMatches)..where((tbl) => tbl.id.equals(id))).go();
    await (delete(cachedMessages)..where((tbl) => tbl.matchId.equals(id))).go();
  }

  Future<void> updateMatchLastMessage(
    String matchId,
    String text,
    DateTime at, {
    bool incrementUnread = false,
    int? resetUnread,
  }) async {
    final match = await (select(cachedMatches)..where((tbl) => tbl.id.equals(matchId))).getSingleOrNull();
    if (match != null) {
      final unread = resetUnread ?? (incrementUnread ? match.unreadCount + 1 : match.unreadCount);
      await (update(cachedMatches)..where((tbl) => tbl.id.equals(matchId))).write(
        CachedMatchesCompanion(
          lastMessageText: Value(text),
          lastMessageAt: Value(at),
          unreadCount: Value(unread),
        ),
      );
    }
  }

  Future<void> markMatchRead(String matchId) {
    return (update(cachedMatches)..where((tbl) => tbl.id.equals(matchId)))
        .write(const CachedMatchesCompanion(unreadCount: Value(0)));
  }

  Future<void> clearMatches() {
    return delete(cachedMatches).go();
  }

  // --- Message Operations ---
  Future<void> upsertMessage(CachedMessage message) {
    return into(cachedMessages).insertOnConflictUpdate(message);
  }

  Stream<List<CachedMessage>> watchMessagesForMatch(String matchId) {
    return (select(cachedMessages)
          ..where((tbl) => tbl.matchId.equals(matchId))
          ..orderBy([
            (tbl) => OrderingTerm(
                  expression: tbl.createdAt,
                ),
          ]))
        .watch();
  }

  Future<List<CachedMessage>> getMessagesForMatch(String matchId, {int limit = 50}) {
    return (select(cachedMessages)
          ..where((tbl) => tbl.matchId.equals(matchId))
          ..orderBy([
            (tbl) => OrderingTerm(
                  expression: tbl.createdAt,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(limit))
        .get();
  }

  Future<void> updateMessageStatus(String id, String status) {
    return (update(cachedMessages)..where((tbl) => tbl.id.equals(id)))
        .write(CachedMessagesCompanion(status: Value(status)));
  }

  Future<void> clearMessagesForMatch(String matchId) {
    return (delete(cachedMessages)..where((tbl) => tbl.matchId.equals(matchId))).go();
  }

  // --- Swipe Outbox Operations ---
  Future<void> insertSwipeOutbox(SwipeOutboxEntry entry) {
    return into(swipeOutbox).insertOnConflictUpdate(entry);
  }

  Future<List<SwipeOutboxEntry>> getPendingSwipes() {
    return (select(swipeOutbox)
          ..where((tbl) => tbl.status.equals('pending') | tbl.status.equals('failed'))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt)]))
        .get();
  }

  Future<void> markSwipeSynced(String id) {
    return (update(swipeOutbox)..where((tbl) => tbl.id.equals(id))).write(
      const SwipeOutboxCompanion(
        status: Value('synced'),
      ),
    );
  }

  Future<void> markSwipeFailed(String id, String error) async {
    final entry = await (select(swipeOutbox)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (entry != null) {
      await (update(swipeOutbox)..where((tbl) => tbl.id.equals(id))).write(
        SwipeOutboxCompanion(
          status: const Value('failed'),
          lastError: Value(error),
          retryCount: Value(entry.retryCount + 1),
        ),
      );
    }
  }

  Future<void> deleteSwipeOutbox(String id) {
    return (delete(swipeOutbox)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<void> deleteSwipeByTargetUserId(String targetUserId) {
    return (delete(swipeOutbox)..where((tbl) => tbl.targetUserId.equals(targetUserId))).go();
  }

  Future<Set<String>> getAllSwipedUserIds() async {
    final entries = await select(swipeOutbox).get();
    return entries.map((e) => e.targetUserId).toSet();
  }

  Future<void> clearSwipeOutbox() {
    return delete(swipeOutbox).go();
  }

  Future<void> clearAll() async {
    await clearMessages();
    await clearMatches();
    await clearProfiles();
    await clearSwipeOutbox();
  }

  Future<void> clearMessages() {
    return delete(cachedMessages).go();
  }
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
