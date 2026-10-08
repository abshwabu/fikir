import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized before use');
});

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PreferencesService(prefs);
});

class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  static const _keyLocale = 'fikir_locale';
  static const _keyThemeMode = 'fikir_theme_mode';
  static const _keyEthiopianCalendar = 'fikir_use_ethiopian_calendar';
  static const _keyEthiopicNumerals = 'fikir_use_ethiopic_numerals';

  Locale? getLocale() {
    final code = _prefs.getString(_keyLocale);
    if (code == null) return null;
    return Locale(code);
  }

  Future<void> setLocale(Locale locale) {
    return _prefs.setString(_keyLocale, locale.languageCode);
  }

  ThemeMode getThemeMode() {
    final modeStr = _prefs.getString(_keyThemeMode);
    switch (modeStr) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) {
    return _prefs.setString(_keyThemeMode, mode.name);
  }

  bool getUseEthiopianCalendar() {
    return _prefs.getBool(_keyEthiopianCalendar) ?? true;
  }

  Future<void> setUseEthiopianCalendar(bool value) {
    return _prefs.setBool(_keyEthiopianCalendar, value);
  }

  bool getUseEthiopicNumerals() {
    return _prefs.getBool(_keyEthiopicNumerals) ?? false;
  }

  Future<void> setUseEthiopicNumerals(bool value) {
    return _prefs.setBool(_keyEthiopicNumerals, value);
  }

  static const _keyDataSaver = 'fikir_data_saver_mode';
  static const _keyNotifyMatch = 'fikir_notify_match';
  static const _keyNotifyMessage = 'fikir_notify_message';
  static const _keyNotifySuperLike = 'fikir_notify_super_like';
  static const _keyHideDistance = 'fikir_hide_distance';
  static const _keyHideOnlineStatus = 'fikir_hide_online_status';
  static const _keyMutedMatches = 'fikir_muted_matches';
  static const _keyBlockedUsers = 'fikir_blocked_users';

  bool getDataSaverMode() {
    return _prefs.getBool(_keyDataSaver) ?? false;
  }

  Future<void> setDataSaverMode(bool value) {
    return _prefs.setBool(_keyDataSaver, value);
  }

  bool getNotifyMatch() {
    return _prefs.getBool(_keyNotifyMatch) ?? true;
  }

  Future<void> setNotifyMatch(bool value) {
    return _prefs.setBool(_keyNotifyMatch, value);
  }

  bool getNotifyMessage() {
    return _prefs.getBool(_keyNotifyMessage) ?? true;
  }

  Future<void> setNotifyMessage(bool value) {
    return _prefs.setBool(_keyNotifyMessage, value);
  }

  bool getNotifySuperLike() {
    return _prefs.getBool(_keyNotifySuperLike) ?? true;
  }

  Future<void> setNotifySuperLike(bool value) {
    return _prefs.setBool(_keyNotifySuperLike, value);
  }

  bool getHideDistance() {
    return _prefs.getBool(_keyHideDistance) ?? false;
  }

  Future<void> setHideDistance(bool value) {
    return _prefs.setBool(_keyHideDistance, value);
  }

  bool getHideOnlineStatus() {
    return _prefs.getBool(_keyHideOnlineStatus) ?? false;
  }

  Future<void> setHideOnlineStatus(bool value) {
    return _prefs.setBool(_keyHideOnlineStatus, value);
  }

  bool isMatchMuted(String matchId) {
    final list = _prefs.getStringList(_keyMutedMatches) ?? [];
    return list.contains(matchId);
  }

  Future<void> setMatchMuted(String matchId, bool muted) async {
    final list = List<String>.from(_prefs.getStringList(_keyMutedMatches) ?? []);
    if (muted && !list.contains(matchId)) {
      list.add(matchId);
    } else if (!muted) {
      list.remove(matchId);
    }
    await _prefs.setStringList(_keyMutedMatches, list);
  }

  List<String> getBlockedUsers() {
    return _prefs.getStringList(_keyBlockedUsers) ?? [];
  }

  Future<void> addBlockedUser(String id) async {
    final list = List<String>.from(_prefs.getStringList(_keyBlockedUsers) ?? []);
    if (!list.contains(id)) {
      list.add(id);
      await _prefs.setStringList(_keyBlockedUsers, list);
    }
  }

  Future<void> removeBlockedUser(String id) async {
    final list = List<String>.from(_prefs.getStringList(_keyBlockedUsers) ?? []);
    list.remove(id);
    await _prefs.setStringList(_keyBlockedUsers, list);
  }
}
