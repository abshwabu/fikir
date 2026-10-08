import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/design/widgets/ethiopian_date_picker.dart';
import 'package:fikir/core/design/widgets/fikir_card.dart';
import 'package:fikir/core/storage/shared_prefs.dart';
import 'package:fikir/core/utils/ethiopian_calendar.dart';
import 'package:fikir/core/utils/ethiopic_numerals.dart';
import 'package:fikir/features/auth/data/auth_repository.dart';
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
  DateTime _birthdate = DateTime(1998, 5, 14);

  Future<void> _pickBirthdate() async {
    final useEthCal = ref.read(useEthiopianCalendarProvider);
    final useEthNum = ref.read(useEthiopicNumeralsProvider);

    if (useEthCal) {
      final selected = await EthiopianDatePickerDialog.show(
        context,
        initialDate: _birthdate,
        useEthiopicNumerals: useEthNum,
      );
      if (selected != null) {
        setState(() => _birthdate = selected);
      }
    } else {
      final selected = await showDatePicker(
        context: context,
        initialDate: _birthdate,
        firstDate: DateTime(1940),
        lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      );
      if (selected != null) {
        setState(() => _birthdate = selected);
      }
    }
  }

  String _formatBirthdate() {
    final useEthCal = ref.read(useEthiopianCalendarProvider);
    final useEthNum = ref.read(useEthiopicNumeralsProvider);

    if (useEthCal) {
      final eth = EthiopianDate.fromGregorian(_birthdate);
      final dayStr = EthiopicNumerals.format(eth.day, useEthiopic: useEthNum);
      final yearStr = EthiopicNumerals.format(eth.year, useEthiopic: useEthNum);
      return '${eth.monthNameAmharic} $dayStr፣ $yearStr ዓ.ም.';
    }
    return '${_birthdate.year}-${_birthdate.month.toString().padLeft(2, '0')}-${_birthdate.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.watch(currentLocaleProvider);
    final currentTheme = ref.watch(currentThemeModeProvider);
    final useEthCal = ref.watch(useEthiopianCalendarProvider);
    final useEthNum = ref.watch(useEthiopicNumeralsProvider);

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
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: FikirColors.primaryGradient,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: const CircleAvatar(
                      backgroundImage: NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400'),
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
                        padding: const EdgeInsets.all(6),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Abebe Bikila',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 6),
                Icon(Icons.verified, color: Colors.lightBlueAccent, size: 20),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Addis Ababa, Ethiopia',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 12),
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
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blueAccent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  icon: const Icon(Icons.verified_rounded, size: 16),
                  label: Text(l10n?.verifyProfile ?? 'Get Verified'),
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
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Profile Completeness',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '85%',
                        style: TextStyle(
                          color: FikirColors.primaryCoral,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: const LinearProgressIndicator(
                      value: 0.85,
                      minHeight: 8,
                      backgroundColor: Colors.black12,
                      valueColor: AlwaysStoppedAnimation<Color>(FikirColors.primaryCoral),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

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
                    title: Text(_formatBirthdate()),
                    subtitle: Text(
                      useEthCal ? 'Ethiopian Calendar (የኢትዮጵያ ቀን)' : 'Gregorian Calendar',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.edit_calendar_rounded, color: FikirColors.primaryCoral),
                    onTap: _pickBirthdate,
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
