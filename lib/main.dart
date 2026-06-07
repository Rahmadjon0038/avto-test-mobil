import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String apiBaseUrl = 'https://api.road-test.uz';
const String sessionStorageKey = 'road_test_session';

void main() {
  runApp(const RoadTestApp());
}

class RoadTestApp extends StatefulWidget {
  const RoadTestApp({super.key});

  @override
  State<RoadTestApp> createState() => _RoadTestAppState();
}

class _RoadTestAppState extends State<RoadTestApp> {
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

  Future<void> _openAuthSheet(AuthMode initialMode) async {
    final result = await showModalBottomSheet<AuthSession>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AuthSheet(initialMode: initialMode),
    );

    if (result != null) {
      await _handleAuthSuccess(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Road Test Mobil Ilova',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
      ),
      home: _loading
          ? const SplashScreen()
          : _session == null
          ? LandingScreen(
              onLogin: () => _openAuthSheet(AuthMode.login),
              onRegister: () => _openAuthSheet(AuthMode.register),
            )
          : HomeScreen(
              session: _session!,
              onLogout: _logout,
              onLogin: () => _openAuthSheet(AuthMode.login),
            ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.traffic, size: 72, color: Color(0xFF1E88E5)),
            SizedBox(height: 20),
            Text(
              'Road Test Mobil Ilova',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Ishga tushmoqda...',
              style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

class LandingScreen extends StatelessWidget {
  const LandingScreen({
    super.key,
    required this.onLogin,
    required this.onRegister,
  });

  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const TopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F8FF),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0xFFE2EAF7)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Road Test Mobil Ilova',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Testlar, mavzular va imtihon tayyorgarligi uchun mobil versiya. Hozircha kirish yoki ro\'yxatdan o\'tish orqali tizimga kirishingiz mumkin.',
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: onLogin,
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text('Kirish'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: onRegister,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFF1E88E5),
                                    ),
                                  ),
                                  child: const Text('Ro\'yxatdan o\'tish'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _FeatureCard(
                      title: 'Mavzular va biletlarga tayyor baza',
                      text:
                          'Keyingi bosqichda backenddagi mavzu, bilet va imtihon API\'lari ulab boriladi.',
                    ),
                    const SizedBox(height: 12),
                    const _FeatureCard(
                      title: 'Bir xil backend',
                      text:
                          'Mobil ilova `https://api.road-test.uz` orqali ishlaydi.',
                    ),
                    const SizedBox(height: 12),
                    const _FeatureCard(
                      title: 'White UI',
                      text:
                          'Hozircha ilova oq fon va sodda layoutda qoladi. Dark mode keyin qo\'shiladi.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.onLogout,
    required this.onLogin,
  });

  final AuthSession session;
  final VoidCallback onLogout;
  final VoidCallback onLogin;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<List<TopicSummary>> _topicsFuture = ApiClient.topics(
    widget.session.accessToken,
  );

  @override
  Widget build(BuildContext context) {
    final fullName = widget.session.userName;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.dark_mode_outlined),
                    splashRadius: 22,
                  ),
                  TextButton(
                    onPressed: widget.onLogout,
                    child: const Text('Chiqish'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Xush kelibsiz',
                            style: TextStyle(
                              fontSize: 18,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            fullName,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Siz tizimga muvaffaqiyatli kirdingiz. Endi keyingi bosqichda mavzular, testlar va natijalarni qo\'shamiz.',
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    FutureBuilder<List<TopicSummary>>(
                      future: _topicsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const _LoadingCard();
                        }
                        if (snapshot.hasError) {
                          return _StatusCard(
                            title: 'Mavzular yuklanmadi',
                            text: 'Backendga ulanishda xato bo\'ldi.',
                            actionText: 'Qayta kirish',
                            onAction: widget.onLogin,
                          );
                        }

                        final topics = snapshot.data ?? const <TopicSummary>[];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Backenddan olingan mavzular',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  '${topics.length} ta',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E88E5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (topics.isEmpty)
                              const _StatusCard(
                                title: 'Mavzular topilmadi',
                                text: 'Backenddan bo\'sh ro\'yxat keldi.',
                              )
                            else
                              ...topics
                                  .take(6)
                                  .map(
                                    (topic) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE5E7EB),
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x0A000000),
                                              blurRadius: 16,
                                              offset: Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 42,
                                              height: 42,
                                              decoration: BoxDecoration(
                                                color: topic.completed
                                                    ? const Color(0xFFE8F5E9)
                                                    : const Color(0xFFEFF6FF),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                topic.completed
                                                    ? Icons.check_circle
                                                    : Icons.menu_book_outlined,
                                                color: topic.completed
                                                    ? const Color(0xFF16A34A)
                                                    : const Color(0xFF1E88E5),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    topic.title,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFF111827),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    topic.completed
                                                        ? 'Tugallangan'
                                                        : 'Davom etmoqda',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: topic.completed
                                                          ? const Color(
                                                              0xFF16A34A,
                                                            )
                                                          : const Color(
                                                              0xFF64748B,
                                                            ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.chevron_right,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TopBar extends StatelessWidget {
  const TopBar({super.key, this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 6),
      child: Row(
        children: [
          const _BrandMark(),
          const Spacer(),
          if (trailing case final Widget widget) widget,
          if (trailing == null)
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.dark_mode_outlined),
              splashRadius: 22,
            ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        CircleAvatar(
          radius: 18,
          backgroundColor: Color(0xFFEFF6FF),
          child: Icon(Icons.traffic, color: Color(0xFF1E88E5), size: 20),
        ),
        SizedBox(width: 10),
        Text(
          'ROAD TEST',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Mavzular yuklanmoqda...'),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.text,
    this.actionText,
    this.onAction,
  });

  final String title;
  final String text;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF475569),
            ),
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 10),
            TextButton(onPressed: onAction, child: Text(actionText!)),
          ],
        ],
      ),
    );
  }
}

enum AuthMode { login, register }

class AuthSheet extends StatefulWidget {
  const AuthSheet({super.key, required this.initialMode});

  final AuthMode initialMode;

  @override
  State<AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<AuthSheet> {
  late AuthMode _mode = widget.initialMode;
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _switchMode(AuthMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final phoneDigits = _normalizePhoneDigits(_phoneController.text);
    if (phoneDigits.length != 9) {
      setState(() => _error = 'Telefon raqam formati noto‘g‘ri');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = _mode == AuthMode.login
          ? await ApiClient.login(
              phone: '+998$phoneDigits',
              password: _passwordController.text.trim(),
            )
          : await ApiClient.register(
              fullName: _fullNameController.text.trim(),
              phone: '+998$phoneDigits',
              password: _passwordController.text.trim(),
            );
      if (!mounted) return;
      Navigator.of(context).pop(session);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = _mode == AuthMode.login;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<AuthMode>(
                          segments: const [
                            ButtonSegment(
                              value: AuthMode.login,
                              label: Text('Kirish'),
                            ),
                            ButtonSegment(
                              value: AuthMode.register,
                              label: Text('Ro\'yxat'),
                            ),
                          ],
                          selected: {_mode},
                          onSelectionChanged: (value) =>
                              _switchMode(value.first),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isLogin ? 'Tizimga kirish' : 'Ro\'yxatdan o\'tish',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isLogin
                        ? 'Telefon raqam va parol bilan kiring.'
                        : 'Ism, telefon raqam va parol bilan ro\'yxatdan o\'ting.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (!isLogin) ...[
                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'To‘liq ism',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Ism kiriting'
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefon raqam',
                      hintText: '90 123 45 67',
                      border: OutlineInputBorder(),
                      prefixText: '+998 ',
                    ),
                    validator: (value) {
                      final digits = _normalizePhoneDigits(value ?? '');
                      return digits.length == 9
                          ? null
                          : 'Telefon raqam noto‘g‘ri';
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _hidePassword,
                    decoration: InputDecoration(
                      labelText: 'Parol',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                    validator: (value) =>
                        value == null || value.trim().length < 6
                        ? 'Kamida 6 ta belgi bo‘lsin'
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(isLogin ? 'Kirish' : 'Ro‘yxatdan o‘tish'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthSession {
  AuthSession({
    required this.accessToken,
    required this.user,
    this.refreshToken,
  });

  final String accessToken;
  final String? refreshToken;
  final Map<String, dynamic> user;

  String get userName {
    final fullName = user['fullName']?.toString().trim();
    if (fullName != null && fullName.isNotEmpty) return fullName;
    final phone = user['phone']?.toString().trim();
    if (phone != null && phone.isNotEmpty) return phone;
    return 'Foydalanuvchi';
  }

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    Map<String, dynamic>? user,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
    );
  }

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'user': user,
  };

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: (json['accessToken'] ?? '').toString(),
      refreshToken: json['refreshToken']?.toString(),
      user: Map<String, dynamic>.from(json['user'] as Map? ?? {}),
    );
  }
}

class AuthResult {
  AuthResult({required this.session, required this.user});

  final AuthSession session;
  final Map<String, dynamic> user;
}

class TopicSummary {
  TopicSummary({
    required this.id,
    required this.title,
    required this.completed,
  });

  final String id;
  final String title;
  final bool completed;

  factory TopicSummary.fromJson(Map<String, dynamic> json) {
    return TopicSummary(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      completed: json['completed'] == true,
    );
  }
}

class ApiClient {
  static Map<String, String> _jsonHeaders({String? accessToken}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    return headers;
  }

  static String? _extractRefreshToken(http.Response response) {
    final raw = response.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return null;
    final match = RegExp(r'refresh_token=([^;]+)').firstMatch(raw);
    return match?.group(1);
  }

  static Future<AuthSession> register({
    required String fullName,
    required String phone,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/api/auth/register'),
      headers: _jsonHeaders(),
      body: jsonEncode({
        'fullName': fullName,
        'phone': phone,
        'password': password,
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw Exception(
        body['error']?.toString() ?? 'Ro‘yxatdan o‘tish amalga oshmadi',
      );
    }
    final accessToken = body['accessToken']?.toString();
    final user = body['user'];
    if (accessToken == null || accessToken.isEmpty || user is! Map) {
      throw Exception('Noto‘g‘ri javob keldi');
    }
    return AuthSession(
      accessToken: accessToken,
      refreshToken: _extractRefreshToken(response),
      user: Map<String, dynamic>.from(user),
    );
  }

  static Future<AuthSession> login({
    required String phone,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/api/auth/login'),
      headers: _jsonHeaders(),
      body: jsonEncode({'phone': phone, 'password': password}),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw Exception(body['error']?.toString() ?? 'Kirish amalga oshmadi');
    }
    final accessToken = body['accessToken']?.toString();
    final user = body['user'];
    if (accessToken == null || accessToken.isEmpty || user is! Map) {
      throw Exception('Noto‘g‘ri javob keldi');
    }
    return AuthSession(
      accessToken: accessToken,
      refreshToken: _extractRefreshToken(response),
      user: Map<String, dynamic>.from(user),
    );
  }

  static Future<AuthSession> refresh(String refreshToken) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/api/auth/refresh'),
      headers: {'Cookie': 'refresh_token=$refreshToken'},
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw Exception(body['error']?.toString() ?? 'Session yangilanmadi');
    }
    final accessToken = body['accessToken']?.toString();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Access token qaytmadi');
    }
    return AuthSession(
      accessToken: accessToken,
      refreshToken: _extractRefreshToken(response) ?? refreshToken,
      user: const <String, dynamic>{},
    );
  }

  static Future<AuthResult> me(String accessToken) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/auth/me'),
      headers: _jsonHeaders(accessToken: accessToken),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw Exception(body['error']?.toString() ?? 'Profil topilmadi');
    }
    final user = body['user'];
    if (user is! Map) throw Exception('Noto‘g‘ri profil javobi');
    return AuthResult(
      session: AuthSession(
        accessToken: accessToken,
        user: Map<String, dynamic>.from(user),
      ),
      user: Map<String, dynamic>.from(user),
    );
  }

  static Future<List<TopicSummary>> topics(String accessToken) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/topics'),
      headers: _jsonHeaders(accessToken: accessToken),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw Exception(body['error']?.toString() ?? 'Mavzular yuklanmadi');
    }
    final rawTopics = body['topics'];
    if (rawTopics is! List) return const [];
    return rawTopics
        .whereType<Map>()
        .map((topic) => TopicSummary.fromJson(Map<String, dynamic>.from(topic)))
        .toList();
  }

  static Future<void> logout(String refreshToken) async {
    await http.post(
      Uri.parse('$apiBaseUrl/api/auth/logout'),
      headers: {'Cookie': 'refresh_token=$refreshToken'},
    );
  }

  static Map<String, dynamic> _decodeBody(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{'data': decoded};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}

String _normalizePhoneDigits(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  final local = digits.startsWith('998') ? digits.substring(3) : digits;
  return local.length > 9 ? local.substring(0, 9) : local;
}
