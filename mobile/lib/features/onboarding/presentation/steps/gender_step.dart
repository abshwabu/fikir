import 'package:fikir/core/design/colors.dart';
import 'package:fikir/features/onboarding/data/onboarding_repository.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GenderStep extends ConsumerWidget {
  const GenderStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final onboardingState = ref.watch(onboardingStateNotifierProvider);

    final selectedGender = onboardingState.gender;
    final interestedIn = onboardingState.interestedIn;

    final genders = [
      {'key': 'woman', 'label': l10n?.woman ?? 'Woman'},
      {'key': 'man', 'label': l10n?.man ?? 'Man'},
      {'key': 'other', 'label': l10n?.otherGender ?? 'More'},
    ];

    final interests = [
      {'key': 'women', 'label': l10n?.women ?? 'Women'},
      {'key': 'men', 'label': l10n?.men ?? 'Men'},
      {'key': 'everyone', 'label': l10n?.everyone ?? 'Everyone'},
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.iAmA ?? 'I am a...',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          // Gender options
          ...genders.map((g) {
            final isSelected = selectedGender == g['key'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  ref
                      .read(onboardingStateNotifierProvider.notifier)
                      .updateState((s) => s.copyWith(gender: g['key']));
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? FikirColors.primaryCoral : FikirColors.lightBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        g['label']!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? FikirColors.primaryCoral : null,
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: FikirColors.primaryCoral),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 24),
          Text(
            l10n?.interestedIn ?? 'Interested in...',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          // Interested-in multi-select options
          ...interests.map((target) {
            final isSelected = interestedIn.contains(target['key']);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  final key = target['key']!;
                  final current = List<String>.from(interestedIn);
                  if (isSelected) {
                    if (current.length > 1) {
                      current.remove(key);
                    }
                  } else {
                    current.add(key);
                  }
                  ref
                      .read(onboardingStateNotifierProvider.notifier)
                      .updateState((s) => s.copyWith(interestedIn: current));
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? FikirColors.primaryMagenta : FikirColors.lightBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        target['label']!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? FikirColors.primaryMagenta : null,
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: FikirColors.primaryMagenta),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
