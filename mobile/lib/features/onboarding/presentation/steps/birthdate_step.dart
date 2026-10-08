import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/design/widgets/ethiopian_date_picker.dart';
import 'package:fikir/core/utils/age_utils.dart';
import 'package:fikir/core/utils/ethiopian_calendar.dart';
import 'package:fikir/core/utils/ethiopic_numerals.dart';
import 'package:fikir/features/onboarding/data/onboarding_repository.dart';
import 'package:fikir/features/profile/presentation/profile_screen.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BirthdateStep extends ConsumerWidget {
  const BirthdateStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final onboardingState = ref.watch(onboardingStateNotifierProvider);
    final useEthCal = ref.watch(useEthiopianCalendarProvider);
    final useEthNum = ref.watch(useEthiopicNumeralsProvider);

    final birthdate = onboardingState.birthdate;
    final is18 = birthdate != null && AgeUtils.isAtLeast18(birthdate);
    final isUnderage = birthdate != null && !is18;

    String formatDisplayDate(DateTime dt) {
      if (useEthCal) {
        final eth = EthiopianDate.fromGregorian(dt);
        final d = EthiopicNumerals.format(eth.day, useEthiopic: useEthNum);
        final y = EthiopicNumerals.format(eth.year, useEthiopic: useEthNum);
        return '${eth.monthNameAmharic} $d፣ $y ዓ.ም.';
      }
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }

    Future<void> pickDate() async {
      final initial = birthdate ?? AgeUtils.maxAllowedBirthdate();

      if (useEthCal) {
        final selected = await EthiopianDatePickerDialog.show(
          context,
          initialDate: initial,
          useEthiopicNumerals: useEthNum,
        );
        if (selected != null) {
          ref
              .read(onboardingStateNotifierProvider.notifier)
              .updateState((s) => s.copyWith(birthdate: selected));
        }
      } else {
        final selected = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: AgeUtils.minAllowedBirthdate(),
          lastDate: DateTime.now(),
        );
        if (selected != null) {
          ref
              .read(onboardingStateNotifierProvider.notifier)
              .updateState((s) => s.copyWith(birthdate: selected));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.whensYourBirthday ?? "When's your birthday?",
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n?.birthdayNotice ??
              'Your age will be public. You must be at least 18 years old to join Fikir.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 32),

        // Date selection card
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: pickDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUnderage
                    ? FikirColors.dislike
                    : (birthdate != null ? FikirColors.primaryCoral : FikirColors.lightBorder),
                width: birthdate != null ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  color: isUnderage ? FikirColors.dislike : FikirColors.primaryCoral,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        birthdate != null
                            ? formatDisplayDate(birthdate)
                            : (l10n?.selectBirthdate ?? 'Select Birthdate'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: birthdate == null ? Colors.grey : null,
                        ),
                      ),
                      if (birthdate != null && is18) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Age: ${AgeUtils.calculateAge(birthdate)} years old',
                          style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),

        // Underage Warning Banner
        if (isUnderage) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: FikirColors.dislike, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n?.underageError ??
                        'You must be at least 18 years old to use Fikir.',
                    style: TextStyle(color: Colors.red.shade900, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Ethiopian Calendar Toggle Switch
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              l10n?.useEthiopianCalendar ?? 'Use Ethiopian Calendar',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: const Text('Meskerem - Pagume (የኢትዮጵያ ቀን መቁጠሪያ)', style: TextStyle(fontSize: 12)),
            value: useEthCal,
            activeThumbColor: FikirColors.primaryCoral,
            onChanged: (val) {
              ref.read(useEthiopianCalendarProvider.notifier).state = val;
            },
          ),
        ),
      ],
    );
  }
}
