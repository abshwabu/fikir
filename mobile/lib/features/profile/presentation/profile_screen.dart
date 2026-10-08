import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/design/widgets/ethiopian_date_picker.dart';
import 'package:fikir/core/design/widgets/fikir_card.dart';
import 'package:fikir/core/storage/shared_prefs.dart';
import 'package:fikir/core/utils/ethiopian_calendar.dart';
import 'package:fikir/core/utils/ethiopic_numerals.dart';
import 'package:fikir/features/auth/data/auth_repository.dart';
import 'package:fikir/features/profile/data/profile_repository.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final currentLocaleProvider = StateProvider<Locale?>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return prefs.getLocale();
});

final currentThemeModeProvider = StateProvider<ThemeMode>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return prefs.getThemeMode();
});

final useEthiopianCalendarProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return prefs.getUseEthiopianCalendar();
});

final useEthiopicNumeralsProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return prefs.getUseEthiopicNumerals();
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  DateTime? _birthdate;

  Future<void> _pickBirthdate(DateTime currentBirthdate) async {
    final useEthCal = ref.read(useEthiopianCalendarProvider);
    final useEthNum = ref.read(useEthiopicNumeralsProvider);

    DateTime? selected;
    if (useEthCal) {
      selected = await EthiopianDatePickerDialog.show(
        context,
        initialDate: _birthdate ?? currentBirthdate,
        useEthiopicNumerals: useEthNum,
      );
    } else {
      selected = await showDatePicker(
        context: context,
        initialDate: _birthdate ?? currentBirthdate,
        firstDate: DateTime(1940),
        lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      );
    }

    if (selected != null) {
      setState(() => _birthdate = selected);
      final repo = ref.read(profileRepositoryProvider);
      await repo.updateProfile(birthdate: selected);
    }
  }

  String _formatBirthdate(DateTime bdate) {
    final useEthCal = ref.read(useEthiopianCalendarProvider);
    final useEthNum = ref.read(useEthiopicNumeralsProvider);

    if (useEthCal) {
      final eth = EthiopianDate.fromGregorian(bdate);
      final dayStr = EthiopicNumerals.format(eth.day, useEthiopic: useEthNum);
      final yearStr = EthiopicNumerals.format(eth.year, useEthiopic: useEthNum);
      return '${eth.monthNameAmharic} $dayStr፣ $yearStr ዓ.ም.';
    }
    return '${bdate.year}-${bdate.month.toString().padLeft(2, '0')}-${bdate.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.watch(currentLocaleProvider);
    final currentTheme = ref.watch(currentThemeModeProvider);
    final useEthCal = ref.watch(useEthiopianCalendarProvider);
    final useEthNum = ref.watch(useEthiopicNumeralsProvider);
    final profileAsync = ref.watch(myUserProfileProvider);

    final profile = profileAsync.valueOrNull;
    final birthdateToDisplay = _birthdate ?? profile?.birthdate ?? DateTime(1998, 5, 14);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.navProfile ?? 'Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              context.push('/settings');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: FikirColors.dislike),
            onPressed: () {
              ref.read(authRepositoryProvider).logout();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            // Avatar & Name Header
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 106,
                    height: 106,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: FikirColors.primaryGradient,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: CircleAvatar(
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: (profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty)
                          ? NetworkImage(profile.avatarUrl!)
                          : null,
                      child: (profile?.avatarUrl == null || profile!.avatarUrl!.isEmpty)
                          ? Text(
                              (profile?.name.isNotEmpty ?? false ? profile!.name[0].toUpperCase() : 'U'),
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: FikirColors.primaryCoral),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => context.push('/profile/edit'),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: FikirColors.primaryCoral,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(7),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  profile?.name ?? 'User',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                if (profile?.isVerified ?? false) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified, color: Colors.lightBlueAccent, size: 20),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              (profile?.city?.isNotEmpty ?? false) ? profile!.city! : 'Addis Ababa, Ethiopia',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 14),

            // Quick action buttons: Edit Profile & Get Verified
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 16, color: FikirColors.primaryCoral),
                  label: const Text('Edit Profile'),
                  onPressed: () => context.push('/profile/edit'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (profile?.isVerified ?? false) ? Colors.green.shade50 : Colors.blue.shade50,
                    foregroundColor: (profile?.isVerified ?? false) ? Colors.green : Colors.blueAccent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  icon: Icon((profile?.isVerified ?? false) ? Icons.check_circle_rounded : Icons.verified_rounded, size: 16),
                  label: Text((profile?.isVerified ?? false) ? 'Verified' : (l10n?.verifyProfile ?? 'Get Verified')),
                  onPressed: () => context.push('/profile/verify'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Profile Completeness Bar
            FikirCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Profile Completeness',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${profile?.completenessScore ?? 0}%',
                        style: const TextStyle(
                          color: FikirColors.primaryCoral,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: ((profile?.completenessScore ?? 0) / 100.0).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.black12,
                      valueColor: const AlwaysStoppedAnimation<Color>(FikirColors.primaryCoral),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // About Me & Details Section
            if (profile != null &&
                ((profile.bio?.isNotEmpty ?? false) ||
                    (profile.jobTitle?.isNotEmpty ?? false) ||
                    profile.interests.isNotEmpty ||
                    profile.languages.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FikirCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'About Me',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          profile.bio!,
                          style: TextStyle(color: Colors.grey.shade800, fontSize: 14, height: 1.4),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (profile.jobTitle != null && profile.jobTitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.work_outline, size: 18, color: FikirColors.primaryCoral),
                              const SizedBox(width: 8),
                              Expanded(child: Text(profile.jobTitle!, style: const TextStyle(fontSize: 14))),
                            ],
                          ),
                        ),
                      if (profile.education != null && profile.education!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.school_outlined, size: 18, color: FikirColors.primaryCoral),
                              const SizedBox(width: 8),
                              Expanded(child: Text(profile.education!, style: const TextStyle(fontSize: 14))),
                            ],
                          ),
                        ),
                      if (profile.religion != null && profile.religion!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.temple_buddhist_outlined, size: 18, color: FikirColors.primaryCoral),
                              const SizedBox(width: 8),
                              Expanded(child: Text(profile.religion!, style: const TextStyle(fontSize: 14))),
                            ],
                          ),
                        ),
                      if (profile.languages.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text('Languages', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: profile.languages
                              .map(
                                (l) => Chip(
                                  label: Text(l, style: const TextStyle(fontSize: 12)),
                                  backgroundColor: Colors.grey.shade100,
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      if (profile.interests.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text('Interests', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: profile.interests
                              .map(
                                (interest) => Chip(
                                  label: Text(interest, style: const TextStyle(fontSize: 12)),
                                  backgroundColor: FikirColors.primaryCoral.withAlpha(25),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // Birthdate & Ethiopian Calendar Section
            FikirCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.birthdate ?? 'Birthdate',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_formatBirthdate(birthdateToDisplay)),
                    subtitle: Text(
                      useEthCal ? 'Ethiopian Calendar (የኢትዮጵያ ቀን)' : 'Gregorian Calendar',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.edit_calendar_rounded, color: FikirColors.primaryCoral),
                    onTap: () => _pickBirthdate(birthdateToDisplay),
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n?.useEthiopianCalendar ?? 'Use Ethiopian Calendar'),
                    subtitle: const Text('Display dates in Meskerem-Pagume'),
                    value: useEthCal,
                    activeThumbColor: FikirColors.primaryCoral,
                    onChanged: (val) {
                      ref.read(useEthiopianCalendarProvider.notifier).state = val;
                      ref.read(preferencesServiceProvider).setUseEthiopianCalendar(val);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n?.useEthiopicNumerals ?? 'Use Ethiopic Numerals'),
                    subtitle: const Text("Convert numbers to Ge'ez (፩, ፪, ፫...)"),
                    value: useEthNum,
                    activeThumbColor: FikirColors.primaryCoral,
                    onChanged: (val) {
                      ref.read(useEthiopicNumeralsProvider.notifier).state = val;
                      ref.read(preferencesServiceProvider).setUseEthiopicNumerals(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Settings: Language & Theme
            FikirCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.settings ?? 'Settings',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  // Language selector
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.language_rounded, color: FikirColors.primaryMagenta),
                    title: Text(l10n?.language ?? 'Language'),
                    trailing: DropdownButton<String>(
                      value: currentLocale?.languageCode ?? 'en',
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'am', child: Text('አማርኛ (Amharic)')),
                        DropdownMenuItem(value: 'om', child: Text('Afaan Oromoo')),
                        DropdownMenuItem(value: 'ti', child: Text('ትግርኛ (Tigrinya)')),
                      ],
                      onChanged: (langCode) {
                        if (langCode != null) {
                          final newLocale = Locale(langCode);
                          ref.read(currentLocaleProvider.notifier).state = newLocale;
                          ref.read(preferencesServiceProvider).setLocale(newLocale);
                        }
                      },
                    ),
                  ),
                  const Divider(),
                  // Theme Mode selector
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.palette_outlined, color: FikirColors.primaryMagenta),
                    title: Text(l10n?.theme ?? 'Theme'),
                    trailing: DropdownButton<ThemeMode>(
                      value: currentTheme,
                      underline: const SizedBox.shrink(),
                      items: [
                        DropdownMenuItem(value: ThemeMode.system, child: Text(l10n?.systemMode ?? 'System')),
                        DropdownMenuItem(value: ThemeMode.light, child: Text(l10n?.lightMode ?? 'Light')),
                        DropdownMenuItem(value: ThemeMode.dark, child: Text(l10n?.darkMode ?? 'Dark')),
                      ],
                      onChanged: (mode) {
                        if (mode != null) {
                          ref.read(currentThemeModeProvider.notifier).state = mode;
                          ref.read(preferencesServiceProvider).setThemeMode(mode);
                        }
                      },
                    ),
                  ),
                  const Divider(),
                  // Delete Account Action
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_forever_rounded, color: FikirColors.dislike),
                    title: Text(
                      l10n?.deleteAccount ?? 'Delete Account',
                      style: const TextStyle(color: FikirColors.dislike, fontWeight: FontWeight.bold),
                    ),
                    onTap: () => _confirmDeleteAccount(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.deleteAccount ?? 'Delete Account'),
        content: Text(
          l10n?.deleteAccountConfirm ??
              'Are you sure you want to delete your account? Your profile will be hidden immediately and permanently purged after 30 days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: FikirColors.dislike,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authRepositoryProvider).deleteAccount();
            },
            child: Text(l10n?.confirmDelete ?? 'Delete My Account'),
          ),
        ],
      ),
    );
  }
}
