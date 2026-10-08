import 'package:fikir/core/constants/ethiopian_data.dart';
import 'package:fikir/core/design/colors.dart';
import 'package:fikir/features/onboarding/data/onboarding_repository.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InterestsStep extends ConsumerWidget {
  const InterestsStep({super.key});

  static const int minInterests = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selectedInterests =
        ref.watch(onboardingStateNotifierProvider).interests;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.selectInterestsTitle ?? 'Your Interests',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.selectInterestsSubtitle ??
                'Select at least 3 interests to help us find people who share your passions.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),

          // Count indicator
          Row(
            children: [
              Icon(
                selectedInterests.length >= minInterests
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
                size: 16,
                color: selectedInterests.length >= minInterests
                    ? Colors.green
                    : FikirColors.primaryCoral,
              ),
              const SizedBox(width: 6),
              Text(
                'Selected: ${selectedInterests.length} (Min $minInterests)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: selectedInterests.length >= minInterests
                      ? Colors.green
                      : FikirColors.primaryCoral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Interests Wrap
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: EthiopianData.interests.map((interest) {
              final isSelected = selectedInterests.contains(interest);

              return FilterChip(
                label: Text(interest),
                selected: isSelected,
                selectedColor: FikirColors.primaryCoral.withValues(alpha: 0.15),
                checkmarkColor: FikirColors.primaryCoral,
                labelStyle: TextStyle(
                  color: isSelected ? FikirColors.primaryCoral : null,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? FikirColors.primaryCoral
                        : FikirColors.lightBorder,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                onSelected: (selected) {
                  final current = List<String>.from(selectedInterests);
                  if (selected) {
                    current.add(interest);
                  } else {
                    current.remove(interest);
                  }
                  ref
                      .read(onboardingStateNotifierProvider.notifier)
                      .updateState((s) => s.copyWith(interests: current));
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
