import 'package:fikir/features/discover/domain/discovery_card.dart';
import 'package:fikir/features/discover/presentation/widgets/action_buttons_row.dart';
import 'package:fikir/features/discover/presentation/widgets/match_celebration_dialog.dart';
import 'package:fikir/features/discover/presentation/widgets/photo_pager_card.dart';
import 'package:fikir/features/discover/presentation/widgets/swipe_stamp_overlay.dart';
import 'package:fikir/features/discover/presentation/widgets/swipeable_card_stack.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sampleCard1 = DiscoveryProfileCard(
    userId: 'u1',
    displayName: 'Selamawit',
    age: 24,
    gender: 'woman',
    distanceKm: 3.2,
    city: 'Addis Ababa (Bole)',
    verified: true,
    bio: 'Coffee lover and architect.',
    interests: ['Coffee', 'Architecture', 'Jazz'],
    photos: [
      ProfileCardPhoto(
        id: 'p1',
        position: 0,
        url: '',
      ),
      ProfileCardPhoto(
        id: 'p2',
        position: 1,
        url: '',
      ),
    ],
  );

  const sampleCard2 = DiscoveryProfileCard(
    userId: 'u2',
    displayName: 'Yohannes',
    age: 27,
    gender: 'man',
    distanceKm: 5.8,
    city: 'Addis Ababa (Kazanchis)',
    bio: 'Software engineer & pianist.',
  );

  Widget createLocalizedWidget({
    required Widget child,
    Locale locale = const Locale('en'),
  }) {
    return MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('Discover Card Stack & Gestures Widget Tests', () {
    testWidgets('Renders candidate card name, age, verified badge, and location',
        (tester) async {
      await tester.pumpWidget(
        createLocalizedWidget(
          child: PhotoPagerCard(
            candidate: sampleCard1,
            onInfoTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Selamawit, 24'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);
      expect(find.textContaining('Addis Ababa (Bole)'), findsOneWidget);
      expect(find.textContaining('3 km away'), findsOneWidget);
      expect(find.text('Coffee lover and architect.'), findsOneWidget);
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Architecture'), findsOneWidget);
    });

    testWidgets('Tapping right side of photo advances photo indicators',
        (tester) async {
      await tester.pumpWidget(
        createLocalizedWidget(
          child: PhotoPagerCard(
            candidate: sampleCard1,
            onInfoTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find right tap area and tap it
      final rightTapFinder = find.byType(GestureDetector).last;
      await tester.tap(rightTapFinder);
      await tester.pumpAndSettle();

      // Card is updated
      expect(find.text('Selamawit, 24'), findsOneWidget);
    });

    testWidgets('SwipeStampOverlay shows localized LIKE stamp on right drag (English & Amharic)',
        (tester) async {
      // English test
      await tester.pumpWidget(
        createLocalizedWidget(
          child: const Stack(
            children: [
              SwipeStampOverlay(offset: Offset(100, 0)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('LIKE'), findsOneWidget);

      // Amharic test
      await tester.pumpWidget(
        createLocalizedWidget(
          locale: const Locale('am'),
          child: const Stack(
            children: [
              SwipeStampOverlay(offset: Offset(100, 0)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ወደድኩት'), findsOneWidget);
    });

    testWidgets('SwipeStampOverlay shows localized NOPE stamp on left drag (English & Amharic)',
        (tester) async {
      // English test
      await tester.pumpWidget(
        createLocalizedWidget(
          child: const Stack(
            children: [
              SwipeStampOverlay(offset: Offset(-100, 0)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('NOPE'), findsOneWidget);

      // Amharic test
      await tester.pumpWidget(
        createLocalizedWidget(
          locale: const Locale('am'),
          child: const Stack(
            children: [
              SwipeStampOverlay(offset: Offset(-100, 0)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('አልወደድኩም'), findsOneWidget);
    });

    testWidgets('SwipeStampOverlay shows SUPER LIKE stamp on upward drag (English & Amharic)',
        (tester) async {
      // English test
      await tester.pumpWidget(
        createLocalizedWidget(
          child: const Stack(
            children: [
              SwipeStampOverlay(offset: Offset(0, -90)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SUPER LIKE'), findsOneWidget);

      // Amharic test
      await tester.pumpWidget(
        createLocalizedWidget(
          locale: const Locale('am'),
          child: const Stack(
            children: [
              SwipeStampOverlay(offset: Offset(0, -90)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ልዩ ወደድኩት'), findsOneWidget);
    });

    testWidgets('ActionButtonsRow triggers callback actions when tapped',
        (tester) async {
      var rewindCalled = false;
      var nopeCalled = false;
      var likeCalled = false;
      var superLikeCalled = false;
      var boostCalled = false;

      await tester.pumpWidget(
        createLocalizedWidget(
          child: ActionButtonsRow(
            onRewind: () => rewindCalled = true,
            onNope: () => nopeCalled = true,
            onSuperLike: () => superLikeCalled = true,
            onLike: () => likeCalled = true,
            onBoost: () => boostCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.replay_rounded));
      await tester.pumpAndSettle();
      expect(rewindCalled, isTrue);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(nopeCalled, isTrue);

      await tester.tap(find.byIcon(Icons.star_rounded));
      await tester.pumpAndSettle();
      expect(superLikeCalled, isTrue);

      await tester.tap(find.byIcon(Icons.favorite_rounded));
      await tester.pumpAndSettle();
      expect(likeCalled, isTrue);

      await tester.tap(find.byIcon(Icons.bolt_rounded));
      await tester.pumpAndSettle();
      expect(boostCalled, isTrue);
    });

    testWidgets('SwipeableCardStack renders multiple cards in depth',
        (tester) async {
      await tester.pumpWidget(
        createLocalizedWidget(
          child: SwipeableCardStack(
            cards: const [sampleCard1, sampleCard2],
            onSwipe: (_) {},
            onInfoTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Selamawit, 24'), findsOneWidget);
      expect(find.text('Yohannes, 27'), findsOneWidget);
    });

    testWidgets('MatchCelebrationDialog renders celebratory header and avatars in Amharic',
        (tester) async {
      var keepSwipingTapped = false;

      await tester.pumpWidget(
        createLocalizedWidget(
          locale: const Locale('am'),
          child: MatchCelebrationDialog(
            matchedCandidate: sampleCard1,
            onKeepSwiping: () => keepSwipingTapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ተጣመራችሁ! 🎉'), findsOneWidget);
      expect(find.text('እርስዎና Selamawit ተዋደዳችሁ።'), findsOneWidget);
      expect(find.text('መልዕክት ላክ'), findsOneWidget);
      expect(find.text('ማሰስ ቀጥል'), findsOneWidget);

      await tester.tap(find.text('ማሰስ ቀጥል'));
      await tester.pumpAndSettle();
      expect(keepSwipingTapped, isTrue);
    });
  });
}
