import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import 'privacy_policy_page.dart';
import '../services/api_client.dart';

enum AuthMode { login, register }

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.initialMode});

  final AuthMode initialMode;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late AuthMode _mode = widget.initialMode;
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _appleLoading = false;
  bool _hidePassword = true;
  bool _acceptPrivacyPolicy = false;
  late final TapGestureRecognizer _privacyPolicyRecognizer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _privacyPolicyRecognizer = TapGestureRecognizer()
      ..onTap = _openPrivacyPolicy;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _privacyPolicyRecognizer.dispose();
    super.dispose();
  }

  void _switchMode(AuthMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      if (mode == AuthMode.login) {
        _acceptPrivacyPolicy = false;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_mode == AuthMode.register && !_acceptPrivacyPolicy) {
      setState(() {
        _error =
            'Ro‘yxatdan o‘tish uchun maxfiylik siyosatiga rozilik bildiring';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maxfiylik siyosatiga rozilik bildiring')),
      );
      return;
    }

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
              phone: '+998$phoneDigits',
              password: _passwordController.text.trim(),
            );
      if (!mounted) return;
      Navigator.of(context).pop(session);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      if (_mode == AuthMode.register &&
          message.toLowerCase().contains('allaqachon')) {
        setState(() {
          _mode = AuthMode.login;
          _error =
              'Bu raqam allaqachon ro‘yxatdan o‘tgan, iltimos tizimga kiring';
        });
      } else {
        setState(() => _error = message);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _appleLogin() async {
    if (_loading || _appleLoading || Platform.isAndroid) return;

    setState(() {
      _appleLoading = true;
      _error = null;
    });

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw Exception('Apple token topilmadi');
      }
      final fullName = [
        credential.givenName,
        credential.familyName,
      ].where((part) => (part ?? '').trim().isNotEmpty).join(' ');
      final session = await ApiClient.appleLogin(
        identityToken: identityToken,
        email: credential.email,
        fullName: fullName,
      );
      if (!mounted) return;
      Navigator.of(context).pop(session);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (!mounted) return;
      if (e.code == AuthorizationErrorCode.canceled) {
        setState(() => _appleLoading = false);
        return;
      }
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _appleLoading = false);
      }
    }
  }

  void _openPrivacyPolicy() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()));
  }

  Future<void> _openForgotPasswordDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 18),
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 30,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
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
                      child: Text(
                        'Parolni tiklash',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Agar parolingizni unutgan bo‘lsangiz, admin bilan Telegram orqali bog‘laning. Admin sizga vaqtinchalik parol beradi.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final phoneDigits = _normalizePhoneDigits(
                        _phoneController.text,
                      );
                      final phone = phoneDigits.length == 9
                          ? '+998$phoneDigits'
                          : '';
                      final text =
                          'Salom, men Topshirdi ilovasida parolimni unutdim. Telefon raqamim: $phone';
                      // Admin username: @Rahmadjonn (strip leading @ for t.me link)
                      final adminUsername = 'Rahmadjonn'.replaceAll(RegExp(r'^@'), '');
                      final url = Uri.parse(
                        'https://t.me/$adminUsername?text=${Uri.encodeComponent(text)}',
                      );
                      final opened = await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                      if (!opened && dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('Telegram ochilmadi')),
                        );
                      }
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Telegram orqali adminga yozish'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF229ED9),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFB7D2FF)),
                  ),
                  child: const Text(
                    'Adminga aynan shu xabarni yuboring. Telefon raqamingiz orqali accountingiz topiladi.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF2450A6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = _mode == AuthMode.login;
    final showAppleButton = Platform.isIOS;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  22 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 34,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _BackCircle(
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                          const Spacer(),
                          const _AuthBrand(),
                          const Spacer(),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F6FB),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _ModeTab(
                                label: 'Kirish',
                                icon: Icons.person_rounded,
                                selected: isLogin,
                                onTap: () => _switchMode(AuthMode.login),
                              ),
                            ),
                            Expanded(
                              child: _ModeTab(
                                label: "Ro'yxat",
                                icon: Icons.person_add_alt_1_rounded,
                                selected: !isLogin,
                                onTap: () => _switchMode(AuthMode.register),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          isLogin ? 'Tizimga kirish' : "Ro'yxatdan o'tish",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                            height: 1.05,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _RoundedField(
                              controller: _phoneController,
                              label: 'Telefon raqam',
                              hint: '90 123 45 67',
                              icon: Icons.phone_rounded,
                              keyboardType: TextInputType.phone,
                              prefixText: '+998 ',
                              inputFormatters: const [_UzPhoneInputFormatter()],
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                final digits = _normalizePhoneDigits(
                                  value ?? '',
                                );
                                return digits.length == 9
                                    ? null
                                    : 'Telefon raqam noto‘g‘ri';
                              },
                            ),
                            const SizedBox(height: 14),
                            if (!isLogin) ...[
                              const Text(
                                'Uzingiz uchun maxsus parol yarating',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            _RoundedField(
                              controller: _passwordController,
                              label: 'Parol',
                              hint: 'Parol',
                              icon: Icons.lock_rounded,
                              obscureText: _hidePassword,
                              textInputAction: TextInputAction.done,
                              suffix: IconButton(
                                onPressed: () => setState(
                                  () => _hidePassword = !_hidePassword,
                                ),
                                icon: Icon(
                                  _hidePassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().length < 6
                                  ? 'Kamida 6 ta belgi bo‘lsin'
                                  : null,
                            ),
                            if (isLogin) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _loading
                                      ? null
                                      : _openForgotPasswordDialog,
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Parolni unutdingizmi?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (!isLogin) ...[
                              const SizedBox(height: 10),
                              InkWell(
                                onTap: _loading
                                    ? null
                                    : () {
                                        setState(() {
                                          _acceptPrivacyPolicy =
                                              !_acceptPrivacyPolicy;
                                          _error = null;
                                        });
                                      },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Checkbox(
                                        value: _acceptPrivacyPolicy,
                                        onChanged: _loading
                                            ? null
                                            : (value) {
                                                setState(() {
                                                  _acceptPrivacyPolicy =
                                                      value ?? false;
                                                  _error = null;
                                                });
                                              },
                                        activeColor: AppColors.primary,
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      const SizedBox(width: 2),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 10,
                                          ),
                                          child: RichText(
                                            text: TextSpan(
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                height: 1.35,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textMuted,
                                              ),
                                              children: [
                                                const TextSpan(
                                                  text:
                                                      'Maxfiylik siyosatiga roziman. ',
                                                ),
                                                TextSpan(
                                                  text: 'Privacy Policy',
                                                  style: const TextStyle(
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                  recognizer:
                                                      _privacyPolicyRecognizer,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: AppColors.danger.withValues(
                                      alpha: 0.18,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: FilledButton(
                                onPressed: _loading ? null : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                child: Text(
                                  _loading
                                      ? 'Kutilmoqda...'
                                      : isLogin
                                      ? 'Kirish'
                                      : "Ro'yxatdan o'tish",
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton(
                                onPressed: _loading
                                    ? null
                                    : () => _switchMode(
                                        isLogin
                                            ? AuthMode.register
                                            : AuthMode.login,
                                      ),
                                child: Text(
                                  isLogin
                                      ? "Hisobingiz yo‘qmi? Ro'yxatdan o'tish"
                                      : 'Hisobingiz bormi? Kirish',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            if (showAppleButton) ...[
                              const SizedBox(height: 14),
                              _AppleButton(
                                loading: _appleLoading,
                                onPressed: _appleLoading ? null : _appleLogin,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

String _normalizePhoneDigits(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  final local = digits.startsWith('998') ? digits.substring(3) : digits;
  return local.length > 9 ? local.substring(0, 9) : local;
}

String _formatUzPhoneDigits(String value) {
  final digits = _normalizePhoneDigits(value);
  if (digits.isEmpty) return '';
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length && i < 9; i++) {
    if (i == 2 || i == 5 || i == 7) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

class _UzPhoneInputFormatter extends TextInputFormatter {
  const _UzPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = _normalizePhoneDigits(newValue.text);
    final formatted = _formatUzPhoneDigits(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _BackCircle extends StatelessWidget {
  const _BackCircle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.text,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _AuthBrand extends StatelessWidget {
  const _AuthBrand();

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: const TextSpan(
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          height: 1.0,
          letterSpacing: -0.2,
        ),
        children: [
          TextSpan(
            text: 'Topshirdi',
            style: TextStyle(
              color: AppColors.primary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        height: 48,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x1A007AFF),
                    blurRadius: 14,
                    offset: Offset(0, 7),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : const Color(0xFF9AA3B2),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppleButton extends StatelessWidget {
  const _AppleButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF111827),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.apple_rounded, size: 22),
        label: const Text(
          'Apple orqali kirish',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _RoundedField extends StatelessWidget {
  const _RoundedField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.prefixText,
    this.suffix,
    this.textInputAction,
    this.validator,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? prefixText;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(
        fontSize: 16,
        color: AppColors.text,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 18, right: 14),
          child: Icon(icon, size: 22, color: AppColors.primary),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        labelStyle: const TextStyle(color: AppColors.textMuted),
        hintStyle: const TextStyle(color: AppColors.textSoft),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.8),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.8),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
      ),
    );
  }
}
