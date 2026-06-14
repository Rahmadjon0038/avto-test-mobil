import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/app_colors.dart';
import '../services/api_client.dart';

const String _googleIosClientId =
    '844953821020-u94ktl35es9aquthb8rh5rmg7etossra.apps.googleusercontent.com';
const String _googleServerClientId =
    '844953821020-2dcgvd7i32rvpj552gkgopat9278tnfe.apps.googleusercontent.com';

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
  final _forgotPhoneController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email'],
    clientId: Platform.isIOS || Platform.isMacOS ? _googleIosClientId : null,
    serverClientId: _googleServerClientId,
  );
  bool _loading = false;
  bool _googleLoading = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _forgotPhoneController.dispose();
    super.dispose();
  }

  void _switchMode(AuthMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      if (mode == AuthMode.login) {
        _forgotPhoneController.clear();
      }
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
              phone: '+998$phoneDigits',
              password: _passwordController.text.trim(),
            );
      if (!mounted) return;
      Navigator.of(context).pop(session);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      if (_mode == AuthMode.register && message.toLowerCase().contains('allaqachon')) {
        setState(() {
          _mode = AuthMode.login;
          _error = 'Bu raqam allaqachon ro‘yxatdan o‘tgan, iltimos tizimga kiring';
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

  Future<void> _googleLogin() async {
    if (_loading || _googleLoading) return;

    setState(() {
      _googleLoading = true;
      _error = null;
    });

    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        if (!mounted) return;
        setState(() => _googleLoading = false);
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google token topilmadi');
      }

      final session = await ApiClient.googleLogin(idToken: idToken);
      if (!mounted) return;
      Navigator.of(context).pop(session);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _googleLoading = false);
      }
    }
  }

  Future<String?> _requestPasswordReset() async {
    final phoneDigits = _normalizePhoneDigits(_forgotPhoneController.text);
    if (phoneDigits.length != 9) {
      setState(() => _error = 'Telefon raqam noto‘g‘ri');
      return null;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.requestPasswordReset(
        phone: '+998$phoneDigits',
      );
      if (!mounted) return null;
      final tempPassword =
          response.temporaryPassword?.trim().isNotEmpty == true
              ? response.temporaryPassword!.trim()
              : null;
      final message = tempPassword != null
          ? 'Bir martalik parol: $tempPassword'
          : response.message.isNotEmpty
              ? response.message
              : 'Bir martalik parol yaratildi';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      if (tempPassword != null) {
        final phoneDigits = _normalizePhoneDigits(_forgotPhoneController.text);
        if (phoneDigits.isNotEmpty) {
          _phoneController.text = _formatUzPhoneDigits(phoneDigits);
        }
        _passwordController.text = tempPassword;
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                title: const Text('Bir martalik parol'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Parol yaratildi. Uni nusxalab olishingiz mumkin. Tizimga kirgandan keyin albatta parolni almashtiring.',
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F6FB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              tempPassword,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: tempPassword),
                              );
                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('Parol nusxalandi'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('Nusxalash'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Keyin'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _switchMode(AuthMode.login);
                      _submit();
                    },
                    child: const Text('Kirish'),
                  ),
                ],
              );
            },
          );
        }
      }
      return tempPassword;
    } catch (e) {
      if (!mounted) return null;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      return null;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openForgotPasswordDialog() async {
    _forgotPhoneController.clear();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Parolni tiklash'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Telefon raqamingizni kiriting. Sizga bir martalik parol beriladi.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _forgotPhoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: const [_UzPhoneInputFormatter()],
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                    decoration: const InputDecoration(
                      hintText: '90 123 45 67',
                      hintStyle: TextStyle(
                        color: Color(0xFFB8C0CC),
                        fontWeight: FontWeight.w500,
                      ),
                      prefixText: '+998 ',
                      prefixStyle: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                      filled: true,
                      fillColor: Color(0xFFF7F9FC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Bekor qilish'),
                ),
                FilledButton(
                  onPressed: _loading
                      ? null
                      : () async {
                          final tempPassword = await _requestPasswordReset();
                          if (tempPassword != null && dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                            if (mounted) {
                              setState(() {
                                _mode = AuthMode.login;
                              });
                            }
                          }
                          setDialogState(() {});
                        },
                  child: Text(_loading ? 'Yuborilmoqda...' : 'Yuborish'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = _mode == AuthMode.login;

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
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3CD),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE7D08B),
                                  ),
                                ),
                                child: const Text(
                                  'Ro‘yxatdan o‘tgandan keyin tizimga kirish uchun telefon raqam va parol ishlatiladi.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF6B5B20),
                                    height: 1.35,
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
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton(
                                onPressed: _loading ? null : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  disabledBackgroundColor: AppColors.primary
                                      .withValues(alpha: 0.55),
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
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            isLogin
                                                ? 'Kirish'
                                                : "Ro'yxatdan o'tish",
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.18,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 17,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 14),
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
                            const SizedBox(height: 14),
                            _GoogleButton(
                              loading: _googleLoading,
                              onPressed: _googleLoading ? null : _googleLogin,
                            ),
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
            text: 'ROAD ',
            style: TextStyle(
              color: AppColors.primary,
              fontStyle: FontStyle.italic,
            ),
          ),
          TextSpan(
            text: 'TEST',
            style: TextStyle(
              color: AppColors.text,
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

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.primary,
                ),
              )
            : const Icon(
                Icons.g_mobiledata_rounded,
                size: 28,
                color: AppColors.primary,
              ),
        label: const Text(
          'Google orqali kirish',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
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
