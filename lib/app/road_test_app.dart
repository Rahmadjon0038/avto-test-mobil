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
  bool _passwordChangePromptShown = false;

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

    late final AuthSession stored;
    AuthSession? active;

    try {
      stored = AuthSession.fromJson(
        jsonDecode(rawSession) as Map<String, dynamic>,
      );
      active = stored;

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
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _clearSession();
        if (!mounted) return;
        setState(() {
          _session = null;
          _loading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _session =
            active ??
            AuthSession.fromJson(
              jsonDecode(rawSession) as Map<String, dynamic>,
            );
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _session =
            active ??
            AuthSession.fromJson(
              jsonDecode(rawSession) as Map<String, dynamic>,
            );
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
    _passwordChangePromptShown = false;
    setState(() => _session = session);
    _maybePromptPasswordChange(session);
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
    _passwordChangePromptShown = false;
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

  void _maybePromptPasswordChange(AuthSession session) {
    final mustChange = session.user['password_reset_required'] == true;
    if (!mustChange || _passwordChangePromptShown) return;
    _passwordChangePromptShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openPasswordChangeDialog();
    });
  }

  Future<void> _openPasswordChangeDialog() async {
    final current = _session;
    if (current == null) return;

    final rootContext = _navigatorKey.currentContext;
    if (rootContext == null) return;
    final messenger = ScaffoldMessenger.maybeOf(rootContext);

    final changed = await showDialog<bool>(
      context: rootContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _PasswordChangeDialog(accessToken: current.accessToken);
      },
    );

    if (changed == true && mounted && _session != null) {
      final updated = current.copyWith(
        user: {...current.user, 'password_reset_required': false},
      );
      await _saveSession(updated);
      if (mounted) {
        setState(() => _session = updated);
      }
      messenger?.showSnackBar(
        const SnackBar(content: Text('Parol muvaffaqiyatli almashtirildi')),
      );
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
        dialogTheme: const DialogThemeData(
          insetPadding: EdgeInsets.zero,
          alignment: Alignment.center,
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
              onChangePassword: _openPasswordChangeDialog,
            ),
    );
  }
}

class _ChangePasswordField extends StatelessWidget {
  const _ChangePasswordField({
    required this.controller,
    required this.label,
    required this.obscureText,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surfaceSoft,
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.85),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.85),
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _PasswordChangeDialog extends StatefulWidget {
  const _PasswordChangeDialog({required this.accessToken});

  final String accessToken;

  @override
  State<_PasswordChangeDialog> createState() => _PasswordChangeDialogState();
}

class _PasswordChangeDialogState extends State<_PasswordChangeDialog> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (currentPassword.isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Eski parolni kiriting')),
      );
      return;
    }
    if (newPassword.length < 6) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Yangi parol kamida 6 ta belgidan iborat bo‘lsin'),
        ),
      );
      return;
    }
    if (newPassword != confirmPassword) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Yangi parollar mos emas')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ApiClient.changePassword(
        accessToken: widget.accessToken,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: MediaQuery.sizeOf(context).width,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.75)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceTint,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Parolni almashtirish',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Bir martalik paroldan keyin yangi parol qo‘ying',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ChangePasswordField(
                controller: _currentPasswordController,
                label: 'Eski parol',
                obscureText: _obscure,
                suffix: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ChangePasswordField(
                controller: _newPasswordController,
                label: 'Yangi parol',
                obscureText: _obscure,
              ),
              const SizedBox(height: 12),
              _ChangePasswordField(
                controller: _confirmPasswordController,
                label: 'Tasdiqlash',
                obscureText: _obscure,
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFB7D2FF)),
                ),
                child: const Text(
                  'Diqqat: yangi parolni faqat siz bilasiz. Uni hech kimga bermang.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: Color(0xFF2450A6),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.55,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Saqlash',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// salom