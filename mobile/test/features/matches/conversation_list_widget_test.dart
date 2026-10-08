import 'package:drift/native.dart';
import 'package:fikir/core/config/flavor.dart';
import 'package:fikir/core/database/app_database.dart';
import 'package:fikir/core/storage/shared_prefs.dart';
import 'package:fikir/features/matches/presentation/matches_screen.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPreferencesService extends Mock implements PreferencesService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    AppConfig.initialize(
      const AppConfig(
        flavor: AppFlavor.dev,
        appName: 'Fikir Test',
        apiBaseUrl: 'http://localhost:8080',
        wsBaseUrl: 'ws://localhost:8080/ws',
        cdnBaseUrl: 'http://localhost:9000/public',
        enableLogging: false,
      ),
    );

    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestWidget({required List<CachedMatch> initialMatches}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        matchesStreamProvider.overrideWith((ref) => Stream.value(initialMatches)),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MatchesScreen(),
      ),
    );
  }

  group('Conversation List & MatchesScreen Widget Tests', () {
    testWidgets('Renders empty state when matches list is empty', (tester) async {
      await tester.pumpWidget(buildTestWidget(initialMatches: []));
      await tester.pumpAndSettle();

      expect(find.text('No matches yet'), findsOneWidget);
      expect(find.text('Keep swiping to find someone special!'), findsOneWidget);
    });

    testWidgets('Renders horizontal New Matches row and active conversation tile with unread badge',
        (tester) async {
      final sampleMatches = [
        // New match without messages
        CachedMatch(
          id: 'match-new-1',
          matchedUserId: 'user-helen',
          matchedUserName: 'Helen',
          unreadCount: 0,
          createdAt: DateTime.now(),
          cachedAt: DateTime.now(),
        ),
        // Active conversation with last message and unread count
        CachedMatch(
          id: 'match-active-2',
          matchedUserId: 'user-selam',
          matchedUserName: 'Selam',
          lastMessageText: 'Meet you at Edna Mall! 🎬',
          lastMessageAt: DateTime.now().subtract(const Duration(minutes: 5)),
          unreadCount: 3,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          cachedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(buildTestWidget(initialMatches: sampleMatches));
      await tester.pumpAndSettle();

      // Check "New Matches" section and avatar name
      expect(find.text('New Matches'), findsOneWidget);
      expect(find.text('Helen'), findsOneWidget);

      // Check "Messages" section
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Selam'), findsOneWidget);
      expect(find.text('Meet you at Edna Mall! 🎬'), findsOneWidget);

      // Check unread badge count
      expect(find.text('3'), findsOneWidget);
    });
  });
}
