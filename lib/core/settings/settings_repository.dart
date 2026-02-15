import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyThemeMode = 'theme_mode';
const _keyDefaultListId = 'default_list_id';
const _keyLeftSwipeAction = 'left_swipe_action';
const _keyRightSwipeAction = 'right_swipe_action';

/// Swipe action: Trash (soft delete), Done (complete), Edit (open edit sheet).
enum SwipeAction {
  trash,
  done,
  edit;

  static SwipeAction fromString(String? v) {
    switch (v) {
      case 'done':
        return SwipeAction.done;
      case 'edit':
        return SwipeAction.edit;
      default:
        return SwipeAction.trash;
    }
  }

  String get value => switch (this) {
        SwipeAction.trash => 'trash',
        SwipeAction.done => 'done',
        SwipeAction.edit => 'edit',
      };
}

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

  SwipeAction get leftSwipeAction =>
      SwipeAction.fromString(_prefs.getString(_keyLeftSwipeAction));

  Future<void> setLeftSwipeAction(SwipeAction action) async {
    await _prefs.setString(_keyLeftSwipeAction, action.value);
  }

  SwipeAction get rightSwipeAction =>
      SwipeAction.fromString(_prefs.getString(_keyRightSwipeAction));

  Future<void> setRightSwipeAction(SwipeAction action) async {
    await _prefs.setString(_keyRightSwipeAction, action.value);
  }
}
