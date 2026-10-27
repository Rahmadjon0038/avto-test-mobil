import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../models/auth_session.dart';
import '../services/api_client.dart';
import '../utils/uz_phone.dart';
import '../widgets/top_bar.dart';
import 'language_selection_page.dart';

/// Ilova ochilishidagi kirish ekrani (oldingi guest/landing sahifa o'rniga):
///  * telefon raqam -> Telegramning rasmiy tasdiqlash xabari orqali kod -> kirish;
///  * "Telegram orqali kirish" (Telegram ilovasida tasdiqlash);
///  * pastda "Boshqa usul bilan kirish" — oddiy login/ro'yxatdan o'tish.
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({
    super.key,
    required this.onAuthenticated,
    required this.onOtherMethod,
    required this.onLanguageChanged,
  });

  final ValueChanged<AuthSession> onAuthenticated;
  final VoidCallback onOtherMethod;
  final ValueChanged<String> onLanguageChanged;

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> with WidgetsBindingObserver {
  static const _primary = Color(0xFF007AFF);
  static const _telegramBlue = Color(0xFF229ED9);
  static const _text = Color(0xFF1C1C1E);
  static const _muted = Color(0xFF636366);
  static const _border = Color(0xFFD1D1D6);
  static const _danger = Color(0xFFD92D20);

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  TelegramLoginConfig _config = const TelegramLoginConfig();
  bool _configLoaded = false;
  bool _codeStep = false;
  bool _busy = false;
  String? _error;
  int _resendIn = 0;
  Timer? _resendTimer;

  // "Telegram orqali kirish" holati
  String? _tgState;
  bool _tgViaBot = false;
  Timer? _pollTimer;
  DateTime? _pollDeadline;
  bool _pollInFlight = false;

  String get _fullPhone => '+998${normalizeUzPhoneDigits(_phoneController.text)}';
  bool get _phoneValid => normalizeUzPhoneDigits(_phoneController.text).length == 9;
  bool get _waitingTelegram => _tgState != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConfig();
  }

  static const _configCacheKey = 'telegram_login_config';

  // Oxirgi bilingan sozlamani darrov ko'rsatamiz (sekin internetda tugma kechikmasin), keyin serverdan yangilaymiz.
  Future<void> _loadConfig() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_configCacheKey);
      if (cached != null && mounted && !_configLoaded) {
        setState(() {
          _config = TelegramLoginConfig.fromJson(Map<String, dynamic>.from(jsonDecode(cached) as Map));
          _configLoaded = true;
        });
      }
    } catch (_) {}
    final fresh = await ApiClient.telegramLoginConfig();
    if (!mounted) return;
    setState(() {
      _config = fresh;
      _configLoaded = true;
    });
    try {
      // Tarmoq xatosida bo'sh sozlama qaytadi: u bilan eski yaxshi sozlamani o'chirib yubormaymiz.
      if (fresh.any) await prefs?.setString(_configCacheKey, jsonEncode(fresh.toJson()));
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resendTimer?.cancel();
    _pollTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Telegramdan ilovaga qaytganda natijani darrov so'raymiz.
    if (state == AppLifecycleState.resumed && _waitingTelegram) _pollOnce();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 45);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn = (_resendIn - 1).clamp(0, 45));
      if (_resendIn == 0) timer.cancel();
    });
  }

  String _errorText(Object error) {
    if (error is ApiException) return error.message;
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  Future<void> _requestCode() async {
    final strings = AppStrings.of(context);
    if (!_phoneValid) {
      setState(() => _error = strings.t('phone_invalid'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiClient.telegramRequestCode(_fullPhone);
      if (!mounted) return;
      setState(() {
        _codeStep = true;
        _codeController.clear();
      });
      _startResendCountdown();
      _codeFocus.requestFocus();
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    final strings = AppStrings.of(context);
    final code = _codeController.text.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) {
      setState(() => _error = strings.t('tg_code_len'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await ApiClient.telegramVerifyCode(phone: _fullPhone, code: code);
      if (!mounted) return;
      widget.onAuthenticated(session);
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loginWithTelegram() async {
    final strings = AppStrings.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final start = await ApiClient.telegramStartLogin(viaBot: _config.botEnabled);
      final opened = await launchUrl(Uri.parse(start.authUrl), mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (!opened) {
        setState(() => _error = strings.t('tg_open_failed'));
        return;
      }
      setState(() {
        _tgState = start.state;
        _tgViaBot = start.viaBot;
      });
      _pollDeadline = DateTime.now().add(const Duration(minutes: 5));
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollOnce());
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pollOnce() async {
    final state = _tgState;
    if (state == null || _pollInFlight) return;
    if (_pollDeadline != null && DateTime.now().isAfter(_pollDeadline!)) {
      _cancelTelegram();
      return;
    }
    _pollInFlight = true;
    try {
      final session = await ApiClient.telegramLoginStatus(state);
      if (!mounted || _tgState != state) return;
      if (session != null) {
        _pollTimer?.cancel();
        widget.onAuthenticated(session);
      }
    } on ApiException catch (error) {
      // 410: havola eskirgan, bekor qilingan yoki ruxsat berilmagan.
      if (error.statusCode == 410 || error.statusCode == 403 || error.statusCode == 400) {
        if (mounted) {
          _cancelTelegram();
          setState(() => _error = error.message);
        }
      }
    } catch (_) {
      // Tarmoq vaqtincha yo'q: keyingi urinishda qayta so'raymiz.
    } finally {
      _pollInFlight = false;
    }
  }

  void _cancelTelegram() {
    _pollTimer?.cancel();
    if (mounted) setState(() => _tgState = null);
  }

  void _openLanguageSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Theme(
        data: ThemeData.light(useMaterial3: true),
        child: LanguageSelectionPage(
          compact: true,
          onSelected: (code) {
            Navigator.of(sheetContext).pop();
            widget.onLanguageChanged(code);
          },
        ),
      ),
    );
  }

  InputDecoration _decoration({required String label, String? hint, String? prefix, required IconData icon}) {
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefix,
      prefixIcon: Icon(icon, color: _primary),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: border(_border),
      focusedBorder: border(_primary, 1.6),
      border: border(_border),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final telegramAvailable = _config.any;
    // Telegram (bot) yoqilgan bo'lsa yangi bosh sahifa dizayni; telefon+kod formasi kerak bo'lsa avvalgi ko'rinish.
    if (!_configLoaded || (_config.telegramButton && !_config.showCodeForm)) return _buildModern(strings);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TopBar(
                backgroundColor: Colors.white,
                borderColor: _border,
                shadowColor: const Color(0x14000000),
                brandColor: _primary,
                trailing: IconButton(
                  onPressed: _openLanguageSheet,
                  icon: const Icon(Icons.language_rounded, color: Color(0xFF2F80ED)),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                strings.t('tg_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _text, height: 1.2),
              ),
              const SizedBox(height: 8),
              Text(
                telegramAvailable ? strings.t('tg_subtitle') : strings.t('tg_unavailable'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: _muted, height: 1.4),
              ),
              const SizedBox(height: 22),
              if (_waitingTelegram)
                _buildWaitingCard(strings)
              else ...[
                if (_config.showCodeForm) _buildCodeForm(strings),
                if (_config.telegramButton) ...[
                  if (_config.showCodeForm) _buildDivider(strings),
                  _buildTelegramButton(strings),
                ],
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: _danger, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 28),
              TextButton(
                onPressed: _busy ? null : widget.onOtherMethod,
                child: Text(
                  strings.t('tg_other_method'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Yangi bosh sahifa dizayni (Telegram orqali kirish asosiy) -----------------------------------
  static const _navy = Color(0xFF14213D);
  static const _titleBlue = Color(0xFF3F6FEE);

  String get _languageLabel {
    switch (AppLanguageStore.currentCode) {
      case AppLanguageStore.uzCyrl:
        return 'ЎЗ';
      case 'ru':
        return 'RU';
      default:
        return 'UZ';
    }
  }

  Widget _buildModern(AppStrings strings) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF1F6FF), Colors.white],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildModernHeader(strings),
                    const SizedBox(height: 56),
                    Text(
                      strings.t('tg_hero_sub'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _titleBlue, height: 1.2),
                    ),
                    const SizedBox(height: 28),
                    if (_waitingTelegram)
                      _buildWaitingCard(strings)
                    else if (!_configLoaded)
                      const SizedBox(height: 48, child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))))
                    else
                      _buildModernTelegramButton(strings),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _danger, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                    _buildDivider(strings),
                    _buildModernOtherMethod(strings),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader(AppStrings strings) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFE6EFFF), borderRadius: BorderRadius.circular(14)),
          child: Image.asset('assets/logo.png', fit: BoxFit.contain),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: const Text(
            'Topshirdi',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              letterSpacing: -0.3,
              color: _titleBlue,
            ),
          ),
        ),
        InkWell(
          onTap: _openLanguageSheet,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE1E8F5)),
              boxShadow: const [BoxShadow(color: Color(0x0F1B2B52), blurRadius: 10, offset: Offset(0, 3))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language_rounded, size: 18, color: _navy),
                const SizedBox(width: 6),
                Text(_languageLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
                const SizedBox(width: 2),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _muted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernTelegramButton(AppStrings strings) {
    return Opacity(
      opacity: _busy ? 0.7 : 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Color(0x332F63E6), blurRadius: 12, offset: Offset(0, 5))],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(colors: [Color(0xFF3F86F5), Color(0xFF2F63E6)]),
            ),
            child: InkWell(
              onTap: _busy ? null : _loginWithTelegram,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded, size: 19, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    strings.t('tg_login_telegram'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernOtherMethod(AppStrings strings) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy ? null : widget.onOtherMethod,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFDCE5F3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mail_outline_rounded, size: 18, color: _navy),
              const SizedBox(width: 8),
              Text(strings.t('tg_other_method'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeForm(AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _phoneController,
          enabled: !_codeStep && !_busy,
          keyboardType: TextInputType.phone,
          inputFormatters: const [UzPhoneInputFormatter()],
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          decoration: _decoration(label: strings.t('phone'), hint: '90 123 45 67', prefix: '+998 ', icon: Icons.phone_rounded),
          onSubmitted: (_) {
            if (!_codeStep) _requestCode();
          },
        ),
        const SizedBox(height: 14),
        if (!_codeStep)
          _primaryButton(label: strings.t('tg_get_code'), onPressed: _busy ? null : _requestCode)
        else ...[
          TextField(
            controller: _codeController,
            focusNode: _codeFocus,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofillHints: const [AutofillHints.oneTimeCode],
            textInputAction: TextInputAction.done,
            style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.w700),
            decoration: _decoration(label: strings.t('tg_code_label'), icon: Icons.lock_rounded).copyWith(counterText: ''),
            onChanged: (value) {
              if (value.length == 6 && !_busy) _verifyCode();
            },
            onSubmitted: (_) => _verifyCode(),
          ),
          const SizedBox(height: 8),
          Text(strings.t('tg_code_sent'), style: const TextStyle(fontSize: 13, color: _muted, height: 1.4)),
          const SizedBox(height: 14),
          _primaryButton(label: strings.t('login'), onPressed: _busy ? null : _verifyCode),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _codeStep = false;
                          _error = null;
                          _resendTimer?.cancel();
                        }),
                child: Text(strings.t('tg_change_phone')),
              ),
              TextButton(
                onPressed: (_busy || _resendIn > 0) ? null : _requestCode,
                child: Text(_resendIn > 0 ? '${strings.t('tg_resend')} ($_resendIn)' : strings.t('tg_resend')),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDivider(AppStrings strings) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          const Expanded(child: Divider(color: _border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(strings.t('tg_or'), style: const TextStyle(color: _muted)),
          ),
          const Expanded(child: Divider(color: _border)),
        ],
      ),
    );
  }

  Widget _buildTelegramButton(AppStrings strings) {
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: _telegramBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        onPressed: _busy ? null : _loginWithTelegram,
        icon: const Icon(Icons.send_rounded, size: 20),
        label: Text(strings.t('tg_login_telegram'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildWaitingCard(AppStrings strings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          const SizedBox(height: 4),
          const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, color: _telegramBlue)),
          const SizedBox(height: 16),
          Text(strings.t('tg_waiting'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _text)),
          const SizedBox(height: 8),
          Text(strings.t(_tgViaBot ? 'tg_waiting_hint_bot' : 'tg_waiting_hint'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: _muted, height: 1.4)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _telegramBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _busy ? null : _loginWithTelegram,
              child: Text(strings.t('tg_reopen'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(onPressed: _cancelTelegram, child: Text(strings.t('tg_cancel'))),
        ],
      ),
    );
  }

  Widget _primaryButton({required String label, required VoidCallback? onPressed}) {
    return SizedBox(
      height: 54,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        onPressed: onPressed,
        child: _busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
