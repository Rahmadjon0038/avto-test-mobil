import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String themeModeStorageKey = 'road_test_theme_mode';

class ThemeModeStore {
  static Future<ThemeMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(themeModeStorageKey);
    return switch (value) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.light,
    };
  }

  static Future<void> save(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      _ => 'light',
    };
    await prefs.setString(themeModeStorageKey, value);
  }
}
