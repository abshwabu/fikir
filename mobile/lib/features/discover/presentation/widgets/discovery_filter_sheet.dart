import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/design/widgets/gradient_button.dart';
import 'package:fikir/features/discover/domain/discovery_filters.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class DiscoveryFilterSheet extends StatefulWidget {
  const DiscoveryFilterSheet({
    required this.initialFilters,
    required this.onApply,
    super.key,
  });

  final DiscoveryFilters initialFilters;
  final void Function(DiscoveryFilters filters) onApply;

  static void show(
    BuildContext context, {
    required DiscoveryFilters initialFilters,
    required void Function(DiscoveryFilters filters) onApply,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DiscoveryFilterSheet(
        initialFilters: initialFilters,
        onApply: onApply,
      ),
    );
  }

  @override
  State<DiscoveryFilterSheet> createState() => _DiscoveryFilterSheetState();
}

class _DiscoveryFilterSheetState extends State<DiscoveryFilterSheet> {
  late double _distance;
  late RangeValues _ageRange;
  late String _genderPreference;
  late bool _verifiedOnly;

  @override
  void initState() {
    super.initState();
    _distance = widget.initialFilters.maxDistanceKm.toDouble().clamp(2.0, 150.0);
    _ageRange = RangeValues(
      widget.initialFilters.minAge.toDouble().clamp(18.0, 60.0),
      widget.initialFilters.maxAge.toDouble().clamp(18.0, 60.0),
    );
    _genderPreference = widget.initialFilters.genderPreference;
    _verifiedOnly = widget.initialFilters.verifiedOnly;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n?.discoverySettings ?? 'Discovery Settings',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Maximum Distance Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n?.maximumDistance(_distance.round()) ??
                      'Maximum Distance: ${_distance.round()} km',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Slider(
              value: _distance,
              min: 2,
              max: 150,
              divisions: 74,
              activeColor: FikirColors.primaryCoral,
              onChanged: (val) => setState(() => _distance = val),
            ),
            const SizedBox(height: 16),

            // Age Range Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n?.ageRangePreference(_ageRange.start.round(), _ageRange.end.round()) ??
                      'Age Range: ${_ageRange.start.round()} - ${_ageRange.end.round()}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            RangeSlider(
              values: _ageRange,
              min: 18,
              max: 60,
              divisions: 42,
              activeColor: FikirColors.primaryCoral,
              onChanged: (vals) => setState(() => _ageRange = vals),
            ),
            const SizedBox(height: 16),

            // Interested in (Show Me)
            Text(
              l10n?.showMe ?? 'Show Me',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildGenderChip('women', l10n?.women ?? 'Women'),
                const SizedBox(width: 8),
                _buildGenderChip('men', l10n?.men ?? 'Men'),
                const SizedBox(width: 8),
                _buildGenderChip('everyone', l10n?.everyone ?? 'Everyone'),
              ],
            ),
            const SizedBox(height: 16),

            // Verified Only Switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n?.verifiedProfilesOnly ?? 'Verified Profiles Only',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text('Only show profiles with verified photo badge'),
              value: _verifiedOnly,
              activeThumbColor: FikirColors.primaryCoral,
              onChanged: (val) => setState(() => _verifiedOnly = val),
            ),
            const SizedBox(height: 24),

            // Apply Button
            GradientButton(
              text: l10n?.applyFilters ?? 'Apply',
              onPressed: () {
                final newFilters = DiscoveryFilters(
                  minAge: _ageRange.start.round(),
                  maxAge: _ageRange.end.round(),
                  maxDistanceKm: _distance.round(),
                  genderPreference: _genderPreference,
                  verifiedOnly: _verifiedOnly,
                );
                widget.onApply(newFilters);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderChip(String value, String label) {
    final isSelected = _genderPreference == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: FikirColors.primaryCoral.withValues(alpha: 0.2),
      side: BorderSide(
        color: isSelected ? FikirColors.primaryCoral : Colors.grey.shade400,
      ),
      labelStyle: TextStyle(
        color: isSelected ? FikirColors.primaryCoral : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => setState(() => _genderPreference = value),
    );
  }
}
