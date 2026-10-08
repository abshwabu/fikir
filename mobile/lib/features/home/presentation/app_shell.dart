import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/design/widgets/offline_banner.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    required this.navigationShell, super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        selectedItemColor: FikirColors.primaryMagenta,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.local_fire_department_rounded),
            label: l10n?.navDiscover ?? 'Discover',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.star_rounded),
            label: l10n?.navLikes ?? 'Likes',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.favorite_rounded),
            label: l10n?.navMatches ?? 'Matches',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_rounded),
            label: l10n?.navChat ?? 'Chat',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_rounded),
            label: l10n?.navProfile ?? 'Profile',
          ),
        ],
      ),
    );
  }
}
