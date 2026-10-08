import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/design/widgets/gradient_button.dart';
import 'package:fikir/core/storage/shared_prefs.dart';
import 'package:fikir/features/profile/presentation/profile_screen.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.watch(currentLocaleProvider);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Gradient & Pattern
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E112A), Color(0xFF0F0B14)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Subtle warm glow in center
          Positioned(
            top: MediaQuery.of(context).size.height * 0.25,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FikirColors.primaryMagenta.withValues(alpha: 0.18),
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Column(
                children: [
                  // Top bar: Language Selector
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: DropdownButton<String>(
                        value: currentLocale?.languageCode ?? 'en',
                        dropdownColor: const Color(0xFF20172B),
                        icon: const Icon(Icons.language_rounded, color: Colors.white, size: 18),
                        underline: const SizedBox.shrink(),
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text('English')),
                          DropdownMenuItem(value: 'am', child: Text('አማርኛ')),
                          DropdownMenuItem(value: 'om', child: Text('Afaan Oromoo')),
                          DropdownMenuItem(value: 'ti', child: Text('ትግርኛ')),
                        ],
                        onChanged: (langCode) {
                          if (langCode != null) {
                            final newLoc = Locale(langCode);
                            ref.read(currentLocaleProvider.notifier).state = newLoc;
                            ref.read(preferencesServiceProvider).setLocale(newLoc);
                          }
                        },
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Flame Logo
                  ShaderMask(
                    shaderCallback: (bounds) => FikirColors.primaryGradient.createShader(bounds),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      size: 96,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n?.appName ?? 'Fikir',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n?.tagline ?? 'Find your Ethiopian love',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),

                  const Spacer(),

                  // Terms & Privacy Notice
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      l10n?.termsNotice ??
                          'By continuing, you agree to our Terms. Learn how we process your data in our Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // "Continue with Phone" CTA
                  GradientButton(
                    text: l10n?.continueWithPhone ?? 'Continue with Phone',
                    icon: const Icon(Icons.phone_android_rounded, color: Colors.white, size: 20),
                    onPressed: () {
                      context.push('/phone');
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
