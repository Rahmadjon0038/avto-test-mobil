import 'package:flutter/material.dart';

class AppColors {
  static bool _darkMode = false;

  static void setDarkMode(bool value) {
    _darkMode = value;
  }

  static bool get isDarkMode => _darkMode;

  static Color get primary => const Color(0xFF007AFF);
  static Color get primaryPressed => const Color(0xFF0062CC);
  static Color get background =>
      _darkMode ? const Color(0xFF0B1220) : const Color(0xFFF2F2F7);
  static Color get surface =>
      _darkMode ? const Color(0xFF121A2A) : const Color(0xFFFFFFFF);
  static Color get surfaceSoft =>
      _darkMode ? const Color(0xFF182235) : const Color(0xFFF8F8FA);
  static Color get surfaceTint =>
      _darkMode ? const Color(0xFF16253F) : const Color(0xFFEAF2FF);
  static Color get border =>
      _darkMode ? const Color(0xFF2B3952) : const Color(0xFFD1D1D6);
  static Color get text =>
      _darkMode ? const Color(0xFFF3F6FB) : const Color(0xFF1C1C1E);
  static Color get textMuted =>
      _darkMode ? const Color(0xFFB8C0CC) : const Color(0xFF636366);
  static Color get textSoft =>
      _darkMode ? const Color(0xFF8F99A8) : const Color(0xFF8E8E93);
  static Color get success => const Color(0xFF34C759);
  static Color get danger => const Color(0xFFFF3B30);
  static Color get shadow =>
      _darkMode ? const Color(0x66000000) : const Color(0x14000000);
}
