import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyThemeMode = 'theme_mode';
const _keyLeftSwipeAction = 'left_swipe_action';
const _keyRightSwipeAction = 'right_swipe_action';
const _keyAccentColor = 'accent_color';

/// Default accent (deepPurple).
const Color _defaultAccent = Color(0xFF6750A4);

/// Predefined accent color options.
const List<Color> predefinedAccentColors = [
  Color(0xFF6750A4), // deepPurple
  Color(0xFF1976D2), // blue
  Color(0xFF2E7D32), // green
  Color(0xFFF57C00), // orange
  Color(0xFFC62828), // red
  Color(0xFF00897B), // teal
  Color(0xFF7B1FA2), // purple
  Color(0xFF1565C0), // indigo
];

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
    if (i == null || i < 0 || i >= ThemeMode.values.length) {
      return ThemeMode.system;
    }
    return ThemeMode.values[i];
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setInt(_keyThemeMode, mode.index);
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

  Color get accentColor {
    final v = _prefs.getInt(_keyAccentColor);
    return v != null ? Color(v) : _defaultAccent;
  }

  Future<void> setAccentColor(Color color) async {
    await _prefs.setInt(_keyAccentColor, color.toARGB32());
  }
}
