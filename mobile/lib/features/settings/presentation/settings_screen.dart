import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/design/widgets/fikir_card.dart';
import 'package:fikir/core/storage/shared_prefs.dart';
import 'package:fikir/features/auth/data/auth_repository.dart';
import 'package:fikir/features/discover/domain/discovery_filters.dart';
import 'package:fikir/features/discover/presentation/widgets/discovery_filter_sheet.dart';
import 'package:fikir/features/profile/presentation/profile_screen.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dataSaverModeProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return prefs.getDataSaverMode();
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(preferencesServiceProvider);
    final currentLocale = ref.watch(currentLocaleProvider);
    final currentTheme = ref.watch(currentThemeModeProvider);
    final isDataSaver = ref.watch(dataSaverModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.settings ?? 'Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Discovery Preferences
          FikirCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.discoverySettings ?? 'Discovery Settings',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.tune_rounded, color: FikirColors.primaryCoral),
                  title: const Text('Filters & Preferences'),
                  subtitle: const Text('Distance, age range, gender interested in'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    DiscoveryFilterSheet.show(
                      context,
                      initialFilters: const DiscoveryFilters(),
                      onApply: (_) {},
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Data-Saver Mode
          FikirCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.data_saver_on_rounded, color: Colors.teal),
                    const SizedBox(width: 8),
                    Text(
                      l10n?.dataSaverMode ?? 'Data-Saver Mode',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isDataSaver ? 'Active (Low Data)' : 'Off (High Quality)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    l10n?.dataSaverDesc ??
                        'Reduces mobile data usage by loading smaller images and limiting prefetching',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  value: isDataSaver,
                  activeThumbColor: Colors.teal,
                  onChanged: (val) {
                    ref.read(dataSaverModeProvider.notifier).state = val;
                    prefs.setDataSaverMode(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Notification Settings
          FikirCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.notificationSettings ?? 'Notifications',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n?.notifyNewMatches ?? 'New Matches'),
                  value: prefs.getNotifyMatch(),
                  activeThumbColor: FikirColors.primaryCoral,
                  onChanged: (val) async {
                    await prefs.setNotifyMatch(val);
                    setState(() {});
                  },
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n?.notifyNewMessages ?? 'New Messages'),
                  value: prefs.getNotifyMessage(),
                  activeThumbColor: FikirColors.primaryCoral,
                  onChanged: (val) async {
                    await prefs.setNotifyMessage(val);
                    setState(() {});
                  },
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n?.notifySuperLikes ?? 'Super Likes'),
                  value: prefs.getNotifySuperLike(),
                  activeThumbColor: FikirColors.primaryCoral,
                  onChanged: (val) async {
                    await prefs.setNotifySuperLike(val);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Privacy Settings
          FikirCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.privacySettings ?? 'Privacy',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n?.hideDistance ?? 'Hide My Distance'),
                  subtitle: const Text('Other users will not see your distance'),
                  value: prefs.getHideDistance(),
                  activeThumbColor: FikirColors.primaryMagenta,
                  onChanged: (val) async {
                    await prefs.setHideDistance(val);
                    setState(() {});
                  },
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n?.hideOnlineStatus ?? 'Hide Online Status'),
                  subtitle: const Text('Do not show when you are active'),
                  value: prefs.getHideOnlineStatus(),
                  activeThumbColor: FikirColors.primaryMagenta,
                  onChanged: (val) async {
                    await prefs.setHideOnlineStatus(val);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 5. App Experience (Language & Theme)
          FikirCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'App Preferences',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
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
                    onChanged: (code) {
                      if (code != null) {
                        final locale = Locale(code);
                        ref.read(currentLocaleProvider.notifier).state = locale;
                        prefs.setLocale(locale);
                      }
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.palette_outlined, color: FikirColors.primaryCoral),
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
                        prefs.setThemeMode(mode);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 6. Safety Center & Blocked Users
          FikirCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.safetyCenter ?? 'Safety & Community',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.security_rounded, color: Colors.blueAccent),
                  title: Text(l10n?.safetyCenter ?? 'Safety Center'),
                  subtitle: Text(
                    l10n?.safetyCenterDesc ?? 'Emergency numbers and guidance for dating safely in Ethiopia',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showSafetyCenterSheet(context),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.block_rounded, color: Colors.grey),
                  title: Text(l10n?.blockedUsers ?? 'Blocked Users'),
                  subtitle: Text('${prefs.getBlockedUsers().length} users blocked'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showBlockedUsersSheet(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 7. Account Actions (Delete Account & Logout)
          FikirCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout_rounded, color: Colors.black87),
                  title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    ref.read(authRepositoryProvider).logout();
                  },
                ),
                const Divider(),
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
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showSafetyCenterSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_rounded, color: Colors.blueAccent, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    l10n?.safetyCenter ?? 'Safety Center',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Emergency Numbers
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ethiopian Emergency Numbers',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.local_police_rounded, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          l10n?.emergencyPolice ?? 'Ethiopian Police: 991',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.medical_services_rounded, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          l10n?.emergencyRedCross ?? 'Red Cross Ambulance: 907',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Key Safety Rules:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text('• Never send money, CBE Birr, Telebirr, or prepaid vouchers to anyone.'),
              const Text('• Always meet in open public places (cafes, malls, restaurants).'),
              const Text('• Tell a trusted friend or family member about your plans.'),
            ],
          ),
        ),
      ),
    );
  }

  void _showBlockedUsersSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.read(preferencesServiceProvider);

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final list = prefs.getBlockedUsers();

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.blockedUsers ?? 'Blocked Users',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          l10n?.noBlockedUsers ?? 'You have not blocked anyone.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  else
                    ...list.map(
                      (id) => ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person_off_rounded)),
                        title: Text('User $id'),
                        trailing: TextButton(
                          onPressed: () async {
                            await prefs.removeBlockedUser(id);
                            setSheetState(() {});
                            setState(() {});
                          },
                          child: Text(l10n?.unblock ?? 'Unblock'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
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
