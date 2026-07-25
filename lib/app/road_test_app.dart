import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../core/app_constants.dart';
import '../models/app_bootstrap.dart';
import '../models/auth_session.dart';
import '../screens/auth_page.dart';
import '../screens/home_screen.dart';
import '../screens/language_selection_page.dart';
import '../screens/landing_screen.dart';
import '../screens/splash_screen.dart';
import '../services/api_client.dart';
import '../services/bootstrap_store.dart';
import '../services/offline_cache_store.dart';
import '../services/theme_mode_store.dart';
import '../l10n/app_strings.dart';

class TopshirdiApp extends StatefulWidget {
  const TopshirdiApp({super.key});

  @override
  State<TopshirdiApp> createState() => _TopshirdiAppState();
}

class _TopshirdiAppState extends State<TopshirdiApp>
    with WidgetsBindingObserver {
  static const Duration _bootstrapRefreshInterval = Duration(seconds: 45);
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  AuthSession? _session;
  bool _loading = true;
  bool _passwordChangePromptShown = false;
  bool _updatePromptShown = false;
  bool _updatePromptVisible = false;
  ThemeMode _themeMode = ThemeMode.light;
  bool _offline = false;
  String? _languageCode;
  AppBootstrapConfig? _appConfig;
  PackageInfo? _packageInfo;
  Timer? _bootstrapRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    _bootstrapRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startBootstrapRefreshTimer();
      unawaited(_refreshBootstrapData(showPromptIfNeeded: true));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _bootstrapRefreshTimer?.cancel();
    }
  }

  void _startBootstrapRefreshTimer() {
    _bootstrapRefreshTimer?.cancel();
    _bootstrapRefreshTimer = Timer.periodic(_bootstrapRefreshInterval, (_) {
      if (!mounted || _loading) return;
      unawaited(_refreshBootstrapData(showPromptIfNeeded: false));
    });
  }

  Future<void> _initializeApp() async {
    final storedTheme = await ThemeModeStore.load();
    final storedLanguage = await AppLanguageStore.load();
    AppColors.setDarkMode(storedTheme == ThemeMode.dark);
    if (!mounted) return;
    setState(() {
      _themeMode = storedTheme;
      _languageCode = storedLanguage;
      _offline = false;
    });

    await _loadPackageInfo();
    await _restoreSession();
    await _refreshBootstrapData(showPromptIfNeeded: true);
    _startBootstrapRefreshTimer();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadPackageInfo() async {
    try {
      _packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {
      _packageInfo = null;
    }
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final rawSession = prefs.getString(sessionStorageKey);
    if (rawSession == null) {
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
      });
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _clearSession();
        if (!mounted) return;
        setState(() {
          _session = null;
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
      });
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _offline = true;
        _session = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _session =
            active ??
            AuthSession.fromJson(
              jsonDecode(rawSession) as Map<String, dynamic>,
            );
      });
    }
  }

  Future<void> _refreshBootstrapData({bool showPromptIfNeeded = false}) async {
    final previousUpdatedAt = _appConfig?.updatedAt;
    AppBootstrapConfig? loadedConfig;
    try {
      final config = await ApiClient.appConfig();
      loadedConfig = config;
      await BootstrapStore.saveAppConfig(config);
      OfflineCacheStore.setAppConfig(config);
      final cachedManifest = await BootstrapStore.loadOfflineManifest();
      OfflineCacheStore.setOfflineManifest(cachedManifest);
      if (!mounted) return;
      setState(() {
        if (previousUpdatedAt != config.updatedAt) {
          _updatePromptShown = false;
        }
        _appConfig = config;
      });

      if (config.syncOnLaunch) {
        try {
          final manifest = await ApiClient.offlineManifest();
          await BootstrapStore.saveOfflineManifest(manifest);
          OfflineCacheStore.setOfflineManifest(manifest);
        } catch (_) {
          // Keep the last cached manifest when a fresh sync is unavailable.
        }
      }
    } catch (_) {
      final cachedConfig = await BootstrapStore.loadAppConfig();
      loadedConfig = cachedConfig;
      final cachedManifest = await BootstrapStore.loadOfflineManifest();
      OfflineCacheStore.setAppConfig(cachedConfig);
      OfflineCacheStore.setOfflineManifest(cachedManifest);
      if (!mounted) return;
      setState(() {
        if (cachedConfig?.updatedAt != previousUpdatedAt) {
          _updatePromptShown = false;
        }
        _appConfig = cachedConfig;
      });
    }

    final currentConfig = loadedConfig ?? _appConfig;
    final shouldShowModal = currentConfig != null && _isForceUpdateRequired(currentConfig);

    if (mounted && !shouldShowModal && _updatePromptVisible) {
      final navigator = _navigatorKey.currentState;
      if (navigator != null) {
        navigator.maybePop();
      }
      _updatePromptVisible = false;
      _updatePromptShown = false;
    }

    if (showPromptIfNeeded && mounted) {
      _maybeShowAppUpdateWarning();
    }
  }

  void _maybeShowAppUpdateWarning() {
    final config = _appConfig;
    if (config == null || _updatePromptShown) return;

    final context = _navigatorKey.currentContext;
    if (context == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ctx = _navigatorKey.currentContext;
      if (ctx == null) return;
      final showModal = _isForceUpdateRequired(config);
      if (!showModal) return;
      _updatePromptShown = true;
      _updatePromptVisible = true;
      final shouldContinue = await showDialog<bool>(
        context: ctx,
        barrierDismissible: false,
        builder: (dialogContext) {
          final languageCode = _languageCode ?? AppLanguageStore.currentCode;
          final title = config.warning.titleFor(languageCode);
          final message = config.warning.messageFor(languageCode);
          final actionLabel = config.warning.actionLabelFor(languageCode);
          final openUrl = _resolveStoreUrl(config);
          return Dialog(
            insetPadding: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceTint,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.system_update_alt_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final url = Uri.tryParse(openUrl);
                        if (url != null) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      },
                      child: Text(actionLabel),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      _updatePromptVisible = false;
      if (shouldContinue == false && mounted) {
        _updatePromptShown = false;
      }
    });
  }

  bool _isForceUpdateRequired(AppBootstrapConfig config) {
    if (!config.forceUpdate) return false;

    final packageInfo = _packageInfo;
    if (packageInfo == null) return false;

    final minimumVersion = Platform.isIOS
        ? config.minAppVersionIos.trim()
        : config.minAppVersionAndroid.trim();
    if (minimumVersion.isEmpty) return false;

    return _isVersionOlder(
      packageInfo.version,
      packageInfo.buildNumber,
      minimumVersion,
    );
  }

  bool _isVersionOlder(String installedVersion, String installedBuild, String minimum) {
    final current = _parseVersionDescriptor(installedVersion, installedBuild);
    final required = _parseVersionDescriptor(minimum, null);
    if (current == null || required == null) return false;

    final versionCompare = _compareIntLists(current.versionParts, required.versionParts);
    if (versionCompare != 0) {
      return versionCompare < 0;
    }
    return current.buildNumber < required.buildNumber;
  }

  _ParsedVersion? _parseVersionDescriptor(String version, String? buildNumber) {
    var rawVersion = version.trim();
    if (rawVersion.isEmpty) return null;
    if (rawVersion.startsWith('v') || rawVersion.startsWith('V')) {
      rawVersion = rawVersion.substring(1);
    }

    var rawBuild = buildNumber?.trim() ?? '';
    if (rawVersion.contains('+')) {
      final parts = rawVersion.split('+');
      rawVersion = parts.first.trim();
      if (rawBuild.isEmpty && parts.length > 1) {
        rawBuild = parts.last.trim();
      }
    }

    final versionParts = rawVersion
        .split('.')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    while (versionParts.length < 3) {
      versionParts.add(0);
    }

    final parsedBuild = int.tryParse(rawBuild.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return _ParsedVersion(versionParts: versionParts, buildNumber: parsedBuild);
  }

  int _compareIntLists(List<int> left, List<int> right) {
    final maxLength = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < maxLength; i++) {
      final leftValue = i < left.length ? left[i] : 0;
      final rightValue = i < right.length ? right[i] : 0;
      if (leftValue != rightValue) {
        return leftValue.compareTo(rightValue);
      }
    }
    return 0;
  }

  String _resolveStoreUrl(AppBootstrapConfig config) {
    if (Platform.isIOS) {
      final ios = config.updateUrlIos.trim();
      if (ios.isNotEmpty) return ios;
    } else {
      final android = config.updateUrlAndroid.trim();
      if (android.isNotEmpty) return android;
    }
    final fallback = config.updateUrl.trim();
    if (fallback.isNotEmpty) return fallback;
    return Platform.isIOS
        ? 'https://apps.apple.com/us/app/topshirdi/id6781198005'
        : 'https://play.google.com/store/apps/details?id=uz.roadtest.app&hl=en_IE';
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
    setState(() => _offline = false);
    _passwordChangePromptShown = false;
    setState(() => _session = session);
    _maybePromptPasswordChange(session);
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    await ThemeModeStore.save(mode);
    AppColors.setDarkMode(mode == ThemeMode.dark);
    if (!mounted) return;
    setState(() {
      _themeMode = mode;
    });
  }

  Future<void> _setLanguage(String code) async {
    await AppLanguageStore.save(code);
    if (!mounted) return;
    setState(() {
      _languageCode = code;
    });
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
        builder: (context) =>
            _ForceLightModeScope(child: AuthPage(initialMode: initialMode)),
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
      _openPasswordChangeDialog(forceReset: true);
    });
  }

  Future<void> _openPasswordChangeDialog({bool forceReset = false}) async {
    final current = _session;
    if (current == null) return;

    final rootContext = _navigatorKey.currentContext;
    if (rootContext == null) return;
    final messenger = ScaffoldMessenger.maybeOf(rootContext);

    final changed = await showDialog<bool>(
      context: rootContext,
      barrierDismissible: !forceReset,
      builder: (dialogContext) {
        return _PasswordChangeDialog(
          accessToken: current.accessToken,
          forceReset: forceReset,
        );
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
    final languageCode = _languageCode ?? AppLanguageStore.uzLatn;
    return AppLanguageScope(
      languageCode: languageCode,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        title: 'Topshirdi Mobil Ilova',
        themeMode: _themeMode,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: _loading
            ? const SplashScreen()
            : _languageCode == null
            ? LanguageSelectionPage(onSelected: _setLanguage)
            : _offline
            ? _OfflineScreen(
                onRetry: () async {
                  if (!mounted) return;
                  setState(() => _loading = true);
                  await _initializeApp();
                },
              )
            : _session == null
            ? LandingScreen(
                onLogin: () => _openAuthPage(AuthMode.login),
                onRegister: () => _openAuthPage(AuthMode.register),
                onLanguageChanged: _setLanguage,
              )
            : HomeScreen(
                session: _session!,
                onLogout: _logout,
                onLogin: () => _openAuthPage(AuthMode.login),
                onSessionUpdated: _handleAuthSuccess,
                onChangePassword: _openPasswordChangeDialog,
                themeMode: _themeMode,
                onThemeModeChanged: _setThemeMode,
                onLanguageChanged: _setLanguage,
              ),
      ),
    );
  }
}

class _ParsedVersion {
  _ParsedVersion({
    required this.versionParts,
    required this.buildNumber,
  });

  final List<int> versionParts;
  final int buildNumber;
}

class _ForceLightModeScope extends StatefulWidget {
  const _ForceLightModeScope({required this.child});

  final Widget child;

  @override
  State<_ForceLightModeScope> createState() => _ForceLightModeScopeState();
}

class _ForceLightModeScopeState extends State<_ForceLightModeScope> {
  late final bool _previousDarkMode;

  @override
  void initState() {
    super.initState();
    _previousDarkMode = AppColors.isDarkMode;
    AppColors.setDarkMode(false);
  }

  @override
  void dispose() {
    AppColors.setDarkMode(_previousDarkMode);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _OfflineScreen extends StatelessWidget {
  const _OfflineScreen({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.wifi_off_rounded,
                    size: 42,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Internetga ulanish talab qilinadi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Ilovadan foydalanish uchun mobil internet yoki Wi-Fi yoqing va qayta urinib ko‘ring.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 180,
                  height: 50,
                  child: FilledButton(
                    onPressed: () => onRetry(),
                    child: Text('Qayta urinish'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF007AFF),
    brightness: brightness,
  );
  final background = isDark ? const Color(0xFF0B1220) : const Color(0xFFF2F2F7);
  final surfaceSoft = isDark
      ? const Color(0xFF182235)
      : const Color(0xFFF8F8FA);
  final border = isDark ? const Color(0xFF2B3952) : const Color(0xFFD1D1D6);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    dialogTheme: const DialogThemeData(
      insetPadding: EdgeInsets.zero,
      alignment: Alignment.center,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: background,
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: scheme.primary.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceSoft,
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      hintStyle: TextStyle(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: border.withValues(alpha: 0.85)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: border.withValues(alpha: 0.85)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),
    ),
  );
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _PasswordChangeDialog extends StatefulWidget {
  const _PasswordChangeDialog({
    required this.accessToken,
    this.forceReset = false,
  });

  final String accessToken;
  final bool forceReset;

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
    final strings = AppStrings.of(context);
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (!widget.forceReset && currentPassword.isEmpty) {
      messenger?.showSnackBar(
        SnackBar(content: Text(strings.t('password_current_required'))),
      );
      return;
    }
    if (newPassword.length < 6) {
      messenger?.showSnackBar(
        SnackBar(content: Text(strings.t('password_min_length'))),
      );
      return;
    }
    if (newPassword != confirmPassword) {
      messenger?.showSnackBar(
        SnackBar(content: Text(strings.t('password_mismatch'))),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ApiClient.changePassword(
        accessToken: widget.accessToken,
        currentPassword: widget.forceReset ? null : currentPassword,
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
    final strings = AppStrings.of(context);
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
                    child: Icon(
                      Icons.lock_reset_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.t('password_modal_title'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          strings.t('password_modal_subtitle'),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!widget.forceReset)
                    IconButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: Icon(Icons.close_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (!widget.forceReset) ...[
                _ChangePasswordField(
                  controller: _currentPasswordController,
                  label: strings.t('password_old_label'),
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
              ],
              _ChangePasswordField(
                controller: _newPasswordController,
                label: strings.t('password_new_label'),
                obscureText: _obscure,
              ),
              const SizedBox(height: 12),
              _ChangePasswordField(
                controller: _confirmPasswordController,
                label: strings.t('password_confirm_label'),
                obscureText: _obscure,
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  strings.t('password_tip'),
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppColors.textMuted,
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
                      : Text(
                          strings.t('password_save'),
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
