import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/design/widgets/gradient_button.dart';
import 'package:fikir/core/utils/age_utils.dart';
import 'package:fikir/features/onboarding/data/onboarding_repository.dart';
import 'package:fikir/features/onboarding/domain/onboarding_state.dart';
import 'package:fikir/features/onboarding/presentation/steps/birthdate_step.dart';
import 'package:fikir/features/onboarding/presentation/steps/details_step.dart';
import 'package:fikir/features/onboarding/presentation/steps/gender_step.dart';
import 'package:fikir/features/onboarding/presentation/steps/interests_step.dart';
import 'package:fikir/features/onboarding/presentation/steps/location_step.dart';
import 'package:fikir/features/onboarding/presentation/steps/name_step.dart';
import 'package:fikir/features/onboarding/presentation/steps/photos_step.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() =>
      _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  bool _isSubmitting = false;
  String? _submitError;

  bool _isCurrentStepValid(OnboardingState state) {
    switch (state.currentStep) {
      case 0:
        return state.name.trim().isNotEmpty;
      case 1:
        return state.birthdate != null &&
            AgeUtils.isAtLeast18(state.birthdate!);
      case 2:
        return state.gender.isNotEmpty && state.interestedIn.isNotEmpty;
      case 3:
        return state.photoPaths.isNotEmpty;
      case 4:
        return state.interests.length >= 3;
      case 5:
        return state.city.isNotEmpty;
      case 6:
        return true;
      default:
        return true;
    }
  }

  Future<void> _handleNext() async {
    final notifier = ref.read(onboardingStateNotifierProvider.notifier);
    final state = ref.read(onboardingStateNotifierProvider);

    if (state.currentStep < OnboardingState.totalSteps - 1) {
      notifier.nextStep();
    } else {
      await _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    // Request Android 13+ Notification Permission
    try {
      await Permission.notification.request();
    } catch (_) {}

    final repo = ref.read(onboardingRepositoryProvider);
    final state = ref.read(onboardingStateNotifierProvider);
    final result = await repo.submitOnboarding(state);

    setState(() => _isSubmitting = false);

    result.when(
      success: (_) {
        context.go('/discover');
      },
      failure: (err) {
        setState(() => _submitError = err.message);
      },
    );
  }

  Widget _buildStepWidget(int step) {
    switch (step) {
      case 0:
        return const NameStep();
      case 1:
        return const BirthdateStep();
      case 2:
        return const GenderStep();
      case 3:
        return const PhotosStep();
      case 4:
        return const InterestsStep();
      case 5:
        return const LocationStep();
      case 6:
        return const DetailsStep();
      default:
        return const NameStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onboardingState = ref.watch(onboardingStateNotifierProvider);
    final currentStep = onboardingState.currentStep;
    final progress = (currentStep + 1) / OnboardingState.totalSteps;
    final isValid = _isCurrentStepValid(onboardingState);
    final isLastStep = currentStep == OnboardingState.totalSteps - 1;

    return Scaffold(
      appBar: AppBar(
        leading: currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () {
                  ref
                      .read(onboardingStateNotifierProvider.notifier)
                      .previousStep();
                },
              )
            : null,
        title: Text(
          l10n?.onboardingProgress(currentStep + 1, OnboardingState.totalSteps) ??
              'Step ${currentStep + 1} of ${OnboardingState.totalSteps}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: FikirColors.lightBorder,
            valueColor: const AlwaysStoppedAnimation<Color>(FikirColors.primaryCoral),
            minHeight: 4,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: ValueKey<int>(currentStep),
                    child: _buildStepWidget(currentStep),
                  ),
                ),
              ),

              if (_submitError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _submitError!,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Next / Finish Button
              GradientButton(
                text: isLastStep
                    ? (l10n?.finishOnboarding ?? 'Finish & Start Swiping')
                    : (l10n?.continueAction ?? 'Continue'),
                isLoading: _isSubmitting,
                onPressed: isValid && !_isSubmitting ? _handleNext : null,
              ),

              if (isLastStep) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isSubmitting ? null : _finishOnboarding,
                  child: Text(
                    l10n?.skipForNow ?? 'Skip for now',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
