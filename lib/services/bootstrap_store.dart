import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_bootstrap.dart';

class BootstrapStore {
  static const String _appConfigKey = 'bootstrap_app_config_v1';
  static const String _offlineManifestKey = 'bootstrap_offline_manifest_v1';

  static Future<AppBootstrapConfig?> loadAppConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_appConfigKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AppBootstrapConfig.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveAppConfig(AppBootstrapConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appConfigKey, jsonEncode(config.toJson()));
  }

  static Future<OfflineManifest?> loadOfflineManifest() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_offlineManifestKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return OfflineManifest.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveOfflineManifest(OfflineManifest manifest) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_offlineManifestKey, jsonEncode(manifest.toJson()));
  }
}
