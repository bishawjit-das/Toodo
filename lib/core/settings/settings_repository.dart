import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyThemeMode = 'theme_mode';
const _keyDefaultListId = 'default_list_id';

class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  ThemeMode get themeMode {
    final i = _prefs.getInt(_keyThemeMode);
    if (i == null || i < 0 || i >= ThemeMode.values.length) return ThemeMode.system;
    return ThemeMode.values[i];
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setInt(_keyThemeMode, mode.index);
  }

  int? get defaultListId => _prefs.getInt(_keyDefaultListId);

  Future<void> setDefaultListId(int? id) async {
    if (id == null) {
      await _prefs.remove(_keyDefaultListId);
    } else {
      await _prefs.setInt(_keyDefaultListId, id);
    }
  }
}
