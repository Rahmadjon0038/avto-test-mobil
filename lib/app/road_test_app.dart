import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_colors.dart';
import '../core/app_constants.dart';
import '../models/auth_session.dart';
import '../screens/auth_page.dart';
import '../screens/home_screen.dart';
import '../screens/landing_screen.dart';
import '../screens/splash_screen.dart';
import '../services/api_client.dart';

class RoadTestApp extends StatefulWidget {
  const RoadTestApp({super.key});

  @override
  State<RoadTestApp> createState() => _RoadTestAppState();
}

class _RoadTestAppState extends State<RoadTestApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  AuthSession? _session;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final rawSession = prefs.getString(sessionStorageKey);
    if (rawSession == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    try {
      final stored = AuthSession.fromJson(
        jsonDecode(rawSession) as Map<String, dynamic>,
      );
      AuthSession active = stored;

      if (stored.refreshToken != null && stored.refreshToken!.isNotEmpty) {
        active = await ApiClient.refresh(stored.refreshToken!);
        final me = await ApiClient.me(active.accessToken);
        active = active.copyWith(user: me.user);
      } else {
        final me = await ApiClient.me(stored.accessToken);
        active = stored.copyWith(user: me.user);
      }

      await _saveSession(active);
      if (!mounted) return;
      setState(() {
        _session = active;
        _loading = false;
      });
    } catch (_) {
      await _clearSession();
      if (!mounted) return;
      setState(() {
        _session = null;
        _loading = false;
      });
    }
  }

  Future<void> _saveSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(sessionStorageKey, jsonEncode(session.toJson()));
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(sessionStorageKey);
  }

  Future<void> _handleAuthSuccess(AuthSession session) async {
    await _saveSession(session);
    if (!mounted) return;
    setState(() => _session = session);
  }

  Future<void> _logout() async {
    final current = _session;
    if (current != null &&
        current.refreshToken != null &&
        current.refreshToken!.isNotEmpty) {
      await ApiClient.logout(current.refreshToken!);
    }
    await _clearSession();
    if (!mounted) return;
    setState(() => _session = null);
  }

  Future<void> _openAuthPage(AuthMode initialMode) async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    final result = await navigator.push<AuthSession>(
      MaterialPageRoute(
        builder: (context) => AuthPage(initialMode: initialMode),
      ),
    );

    if (result != null) {
      await _handleAuthSuccess(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      title: 'Road Test Mobil Ilova',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.primary,
          surface: AppColors.surface,
          error: AppColors.danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.text,
          surfaceTintColor: AppColors.background,
          elevation: 0,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.surface,
            disabledBackgroundColor: AppColors.primaryPressed,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.text,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: _loading
          ? const SplashScreen()
          : _session == null
          ? LandingScreen(
              onLogin: () => _openAuthPage(AuthMode.login),
              onRegister: () => _openAuthPage(AuthMode.register),
            )
          : HomeScreen(
              session: _session!,
              onLogout: _logout,
              onLogin: () => _openAuthPage(AuthMode.login),
              onSessionUpdated: _handleAuthSuccess,
            ),
    );
  }
}
