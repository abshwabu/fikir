import 'package:fikir/core/network/dio_client.dart';
import 'package:fikir/features/auth/presentation/otp_screen.dart';
import 'package:fikir/features/auth/presentation/phone_screen.dart';
import 'package:fikir/features/auth/presentation/welcome_screen.dart';
import 'package:fikir/features/chat/presentation/chat_detail_screen.dart';
import 'package:fikir/features/chat/presentation/chat_list_screen.dart';
import 'package:fikir/features/discover/presentation/discover_screen.dart';
import 'package:fikir/features/home/presentation/app_shell.dart';
import 'package:fikir/features/likes/presentation/likes_screen.dart';
import 'package:fikir/features/matches/presentation/matches_screen.dart';
import 'package:fikir/features/onboarding/data/onboarding_repository.dart';
import 'package:fikir/features/onboarding/presentation/onboarding_flow_screen.dart';
import 'package:fikir/features/premium/presentation/premium_screen.dart';
import 'package:fikir/features/profile/presentation/edit_profile_screen.dart';
import 'package:fikir/features/profile/presentation/profile_screen.dart';
import 'package:fikir/features/profile/presentation/verification_screen.dart';
import 'package:fikir/features/settings/presentation/privacy_policy_screen.dart';
import 'package:fikir/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ValueNotifier<bool>(ref.watch(authStateProvider));

  ref.listen<bool>(authStateProvider, (_, next) {
    authNotifier.value = next;
  });

  return GoRouter(
    initialLocation: '/discover',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isLoggedIn = authNotifier.value;
      final onboardingRepo = ref.read(onboardingRepositoryProvider);
      final isOnboardingComplete = onboardingRepo.isOnboardingComplete();

      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/welcome' || loc == '/phone' || loc == '/otp';
      final isOnboardingRoute = loc == '/onboarding';

      if (!isLoggedIn) {
        if (!isAuthRoute) {
          return '/welcome';
        }
        return null;
      }

      // Logged in
      if (!isOnboardingComplete) {
        if (!isOnboardingRoute) {
          return '/onboarding';
        }
        return null;
      }

      // Logged in and Onboarding Complete
      if (isAuthRoute || isOnboardingRoute) {
        return '/discover';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/phone',
        builder: (context, state) => const PhoneScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final phone = (state.extra as String?) ?? '+251911223344';
          return OtpScreen(phoneNumber: phone);
        },
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingFlowScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                builder: (context, state) => const DiscoverScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/likes',
                builder: (context, state) => const LikesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/matches',
                builder: (context, state) => const MatchesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const ChatListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/chat/:matchId',
        builder: (context, state) {
          final matchId = state.pathParameters['matchId'] ?? '';
          final matchedUserName = (state.extra as String?) ?? 'Chat';
          return ChatDetailScreen(
            matchId: matchId,
            matchedUserName: matchedUserName,
          );
        },
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/verify',
        builder: (context, state) => const SelfieVerificationScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/premium',
        builder: (context, state) {
          final tier = (state.extra as String?) ?? 'gold';
          return PremiumScreen(initialTier: tier);
        },
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
    ],
  );
});
