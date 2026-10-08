import 'package:fikir/core/constants/ethiopian_data.dart';
import 'package:fikir/core/design/colors.dart';
import 'package:fikir/features/onboarding/data/onboarding_repository.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationStep extends ConsumerStatefulWidget {
  const LocationStep({super.key});

  @override
  ConsumerState<LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends ConsumerState<LocationStep> {
  bool _isRequestingPermission = false;

  Future<void> _requestLocationPermission() async {
    setState(() => _isRequestingPermission = true);
    try {
      final status = await Permission.locationWhenInUse.request();
      if (status.isGranted) {
        // Set coordinates (e.g. Addis Ababa center)
        ref.read(onboardingStateNotifierProvider.notifier).updateState((s) => s.copyWith(
              latitude: 9.010793,
              longitude: 38.761252,
            ),);
      }
    } catch (_) {
      // Platform fallback
    } finally {
      if (mounted) {
        setState(() => _isRequestingPermission = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedCity = ref.watch(onboardingStateNotifierProvider).city;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.enableLocationTitle ?? 'Where are you located?',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.enableLocationSubtitle ??
                'Fikir uses your location to discover matches nearby in Ethiopia.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),

          // Location Rationale Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  FikirColors.primaryCoral.withValues(alpha: 0.1),
                  FikirColors.primaryMagenta.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: FikirColors.primaryCoral.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 56,
                  color: FikirColors.primaryCoral,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Find People Nearby',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your exact GPS position is never shared. Only approximate distance is shown to other members.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FikirColors.primaryCoral,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: _isRequestingPermission
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(l10n?.allowLocation ?? 'Enable GPS Location'),
                  onPressed: _isRequestingPermission ? null : _requestLocationPermission,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          Text(
            l10n?.pickCityManually ?? 'Or choose your city manually',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),

          // City Dropdown Selector
          DropdownButtonFormField<String>(
            initialValue: selectedCity,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.location_city_rounded, color: FikirColors.primaryMagenta),
              labelText: l10n?.selectCity ?? 'Select City or Sub-city',
            ),
            items: EthiopianData.cities.map((city) {
              return DropdownMenuItem(
                value: city,
                child: Text(city),
              );
            }).toList(),
            onChanged: (newCity) {
              if (newCity != null) {
                ref
                    .read(onboardingStateNotifierProvider.notifier)
                    .updateState((s) => s.copyWith(city: newCity));
              }
            },
          ),
        ],
      ),
    );
  }
}
