import 'package:fikir/core/constants/ethiopian_data.dart';
import 'package:fikir/core/design/colors.dart';
import 'package:fikir/features/onboarding/data/onboarding_repository.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DetailsStep extends ConsumerStatefulWidget {
  const DetailsStep({super.key});

  @override
  ConsumerState<DetailsStep> createState() => _DetailsStepState();
}

class _DetailsStepState extends ConsumerState<DetailsStep> {
  late final TextEditingController _bioController;
  late final TextEditingController _jobController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(onboardingStateNotifierProvider);
    _bioController = TextEditingController(text: state.bio);
    _jobController = TextEditingController(text: state.jobTitle);
  }

  @override
  void dispose() {
    _bioController.dispose();
    _jobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onboardingState = ref.watch(onboardingStateNotifierProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.moreDetailsTitle ?? 'Tell us more (Optional)',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.moreDetailsSubtitle ??
                'Add final details to make your profile stand out.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          // Job Title Input
          TextField(
            controller: _jobController,
            decoration: InputDecoration(
              labelText: l10n?.jobTitle ?? 'Job Title',
              prefixIcon: const Icon(Icons.work_outline_rounded),
            ),
            onChanged: (val) {
              ref
                  .read(onboardingStateNotifierProvider.notifier)
                  .updateState((s) => s.copyWith(jobTitle: val.trim()));
            },
          ),
          const SizedBox(height: 16),

          // Religion Dropdown
          DropdownButtonFormField<String>(
            initialValue: onboardingState.religion,
            decoration: InputDecoration(
              labelText: l10n?.religion ?? 'Religion',
              prefixIcon: const Icon(Icons.temple_buddhist_outlined),
            ),
            items: EthiopianData.religions.map((r) {
              return DropdownMenuItem(value: r, child: Text(r));
            }).toList(),
            onChanged: (val) {
              ref
                  .read(onboardingStateNotifierProvider.notifier)
                  .updateState((s) => s.copyWith(religion: val));
            },
          ),
          const SizedBox(height: 16),

          // Languages Spoken Chips
          Text(
            l10n?.languages ?? 'Languages',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: EthiopianData.languages.map((lang) {
              final isSelected = onboardingState.languages.contains(lang);
              return FilterChip(
                label: Text(lang),
                selected: isSelected,
                selectedColor: FikirColors.primaryMagenta.withValues(alpha: 0.15),
                checkmarkColor: FikirColors.primaryMagenta,
                onSelected: (selected) {
                  final current = List<String>.from(onboardingState.languages);
                  if (selected) {
                    current.add(lang);
                  } else {
                    current.remove(lang);
                  }
                  ref
                      .read(onboardingStateNotifierProvider.notifier)
                      .updateState((s) => s.copyWith(languages: current));
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Bio Multi-line Input
          TextField(
            controller: _bioController,
            maxLines: 3,
            maxLength: 300,
            decoration: InputDecoration(
              labelText: l10n?.bio ?? 'Bio',
              hintText: l10n?.bioPlaceholder ??
                  'Write something sweet about yourself...',
              alignLabelWithHint: true,
            ),
            onChanged: (val) {
              ref
                  .read(onboardingStateNotifierProvider.notifier)
                  .updateState((s) => s.copyWith(bio: val.trim()));
            },
          ),
        ],
      ),
    );
  }
}
