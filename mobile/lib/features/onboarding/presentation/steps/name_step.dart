import 'package:fikir/features/onboarding/data/onboarding_repository.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NameStep extends ConsumerStatefulWidget {
  const NameStep({super.key});

  @override
  ConsumerState<NameStep> createState() => _NameStepState();
}

class _NameStepState extends ConsumerState<NameStep> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final current = ref.read(onboardingStateNotifierProvider).name;
    _controller = TextEditingController(text: current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.whatsYourName ?? "What's your name?",
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n?.nameNotice ?? 'This is how it will appear on your profile.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: l10n?.firstName ?? 'First name',
            prefixIcon: const Icon(Icons.person_outline),
          ),
          onChanged: (val) {
            ref
                .read(onboardingStateNotifierProvider.notifier)
                .updateState((s) => s.copyWith(name: val.trim()));
          },
        ),
      ],
    );
  }
}
