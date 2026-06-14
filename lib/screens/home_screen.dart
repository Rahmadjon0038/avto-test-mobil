import 'dart:io';

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/app_colors.dart';
import '../models/auth_session.dart';
import '../services/api_client.dart';
import 'custom_tests_page.dart';
import 'answers_page.dart';
import 'exam_page.dart';
import 'mistakes_page.dart';
import 'tickets_page.dart';
import 'topics_page.dart';
import 'marathon_page.dart';
import 'videos_page.dart';
import '../widgets/top_bar.dart';

const String _googleWebClientId =
    '844953821020-2dcgvd7i32rvpj552gkgopat9278tnfe.apps.googleusercontent.com';
const String _googleIosClientId =
    '844953821020-u94ktl35es9aquthb8rh5rmg7etossra.apps.googleusercontent.com';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.onLogout,
    required this.onLogin,
    required this.onSessionUpdated,
    required this.onChangePassword,
  });

  final AuthSession session;
  final VoidCallback onLogout;
  final VoidCallback onLogin;
  final ValueChanged<AuthSession> onSessionUpdated;
  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF7F9FF),
              AppColors.background,
              Color(0xFFF7F8FC),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                TopBar(
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceTint,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.55),
                          ),
                        ),
                        child: InkWell(
                          onTap: () => _openProfileSheet(context),
                          borderRadius: BorderRadius.circular(14),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            size: 22,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF8E6BFF), Color(0xFF5B8CFF)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1E5B8CFF),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Video darsliklar',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Mavzulashtirilgan video darsliklar orqali o‘rganing.',
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.45,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 46,
                              width: 146,
                              child: FilledButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        VideosPage(session: session),
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF1F4FD0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                  elevation: 0,
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Boshlash',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    CircleAvatar(
                                      radius: 13,
                                      backgroundColor: Colors.white,
                                      child: Icon(
                                        Icons.play_arrow_rounded,
                                        size: 15,
                                        color: Color(0xFF1F4FD0),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 78,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  children: [
                    _SectionCard(
                      icon: Icons.description_rounded,
                      iconColor: const Color(0xFF4C8DFF),
                      title: 'Mavzu bo‘yicha testlar',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TopicsPage(session: session),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SectionCard(
                      icon: Icons.receipt_long_rounded,
                      iconColor: const Color(0xFF34C759),
                      title: 'Biletlar bo‘yicha testlar',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TicketsPage(
                            session: session,
                            onSessionUpdated: onSessionUpdated,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SectionCard(
                      icon: Icons.local_fire_department_rounded,
                      iconColor: const Color(0xFFFF6B35),
                      title: 'Marafon rejimi',
                      onTap: () => _openSection(context, 'Marafon rejimi'),
                    ),
                    const SizedBox(height: 10),
                    _SectionCard(
                      icon: Icons.tune_rounded,
                      iconColor: const Color(0xFF8E6BFF),
                      title: 'Sozlamali testlar',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CustomTestsPage(
                            session: session,
                            onSessionUpdated: onSessionUpdated,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SectionCard(
                      icon: Icons.close_rounded,
                      iconColor: const Color(0xFFEE5A73),
                      title: 'Mening xatolarim',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MistakesPage(
                            session: session,
                            onSessionUpdated: onSessionUpdated,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SectionCard(
                      icon: Icons.menu_book_rounded,
                      iconColor: const Color(0xFFF5A623),
                      title: 'Barcha testlar javoblari',
                      onTap: () =>
                          _openSection(context, 'Barcha testlar javoblari'),
                    ),
                    const SizedBox(height: 10),
                    _SectionCard(
                      icon: Icons.check_circle_rounded,
                      iconColor: const Color(0xFF2BBE8A),
                      title: 'Imtihon topshirish',
                      onTap: () => _openSection(context, 'Imtihon topshirish'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _SocialFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openSection(BuildContext context, String title) {
    if (title == 'Marafon rejimi') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MarathonPage(
            session: session,
            onSessionUpdated: onSessionUpdated,
          ),
        ),
      );
      return;
    }
    if (title == 'Barcha testlar javoblari') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              AnswersPage(session: session, onSessionUpdated: onSessionUpdated),
        ),
      );
      return;
    }
    if (title == 'Imtihon topshirish') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ExamPage(session: session, onSessionUpdated: onSessionUpdated),
        ),
      );
      return;
    }
    if (title == 'Video darsliklar') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => VideosPage(session: session)));
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SectionPage(title: title)));
  }

  void _openProfileSheet(BuildContext context) {
    final fullName = session.userName;
    final phoneCandidates = <String?>[
      session.user['phone']?.toString(),
      session.user['phoneNumber']?.toString(),
      session.user['mobile']?.toString(),
      session.user['tel']?.toString(),
    ];
    String? phone;
    for (final candidate in phoneCandidates) {
      final value = candidate?.trim();
      if (value != null && value.isNotEmpty) {
        phone = value;
        break;
      }
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final googleSignIn = GoogleSignIn(
          scopes: <String>['email'],
          clientId: Platform.isIOS || Platform.isMacOS
              ? _googleIosClientId
              : null,
          serverClientId: _googleWebClientId,
        );
        bool googleLoading = false;

        Future<bool> confirmGoogleLink() async {
          final result = await showDialog<bool>(
            context: sheetContext,
            barrierDismissible: false,
            builder: (dialogContext) {
              return AlertDialog(
                title: const Text('Google ulash'),
                content: const Text(
                  'Google akkauntingizni telefon orqali kirgan hisobingizga birlashtirish uchun ruxsat kerak. '
                  'Shunda keyin telefon raqam yoki Google orqali kirganingizda bitta akkaunt ochiladi.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Bekor qilish'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Roziman'),
                  ),
                ],
              );
            },
          );
          return result ?? false;
        }

        Future<bool> confirmDeleteAccount() async {
          final result = await showDialog<bool>(
            context: sheetContext,
            barrierDismissible: false,
            builder: (dialogContext) {
              return AlertDialog(
                title: const Text('Accountni o‘chirish'),
                content: const Text(
                  'Siz accountni butunlay o‘chirmoqchimisiz? Agar bunday qilsangiz, barcha ma’lumotlaringizni qayta tiklab bo‘lmaydi.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Bekor qilish'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Roziman'),
                  ),
                ],
              );
            },
          );
          return result ?? false;
        }

        return SafeArea(
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              Future<void> linkGoogle() async {
                if (googleLoading) return;
                final accepted = await confirmGoogleLink();
                if (!accepted) return;
                setSheetState(() => googleLoading = true);
                try {
                  final account = await googleSignIn.signIn();
                  if (account == null) return;
                  final auth = await account.authentication;
                  final idToken = auth.idToken;
                  if (idToken == null || idToken.isEmpty) {
                    throw Exception('Google token topilmadi');
                  }
                  final linked = await ApiClient.googleLogin(
                    idToken: idToken,
                    accessToken: session.accessToken,
                  );
                  onSessionUpdated(linked);
                  if (sheetContext.mounted) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(content: Text('Google akkaunti ulandi')),
                    );
                  }
                } catch (e) {
                  if (sheetContext.mounted) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.toString().replaceFirst('Exception: ', ''),
                        ),
                      ),
                    );
                  }
                } finally {
                  if (sheetContext.mounted) {
                    setSheetState(() => googleLoading = false);
                  }
                }
              }

              Future<void> deleteAccount() async {
                if (googleLoading) return;
                final accepted = await confirmDeleteAccount();
                if (!accepted) return;
                setSheetState(() => googleLoading = true);
                try {
                  await ApiClient.deleteAccount(session.accessToken);
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                    onLogout();
                  }
                } catch (e) {
                  if (sheetContext.mounted) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.toString().replaceFirst('Exception: ', ''),
                        ),
                      ),
                    );
                  }
                } finally {
                  if (sheetContext.mounted) {
                    setSheetState(() => googleLoading = false);
                  }
                }
              }

              return Container(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(26),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceTint,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: AppColors.primary,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Profil',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  fullName.isNotEmpty
                                      ? fullName
                                      : 'Foydalanuvchi',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _ProfileInfoRow(
                        label: 'Ism',
                        value: fullName.isNotEmpty ? fullName : 'Belgilanmagan',
                      ),
                      const SizedBox(height: 10),
                      _ProfileInfoRow(
                        label: 'Telefon',
                        value: phone?.isNotEmpty == true
                            ? phone!
                            : 'Belgilanmagan',
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: onChangePassword,
                          icon: const Icon(Icons.lock_reset_rounded),
                          label: const Text('Parolni almashtirish'),
                        ),
                      ),
                      if ((session.user['google_sub']?.toString() ?? '')
                          .isEmpty) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: googleLoading ? null : linkGoogle,
                            icon: googleLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                    ),
                                  )
                                : const Icon(Icons.link_rounded),
                            label: const Text('Google ulash'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.tonal(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            onLogout();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFFEDEE),
                            foregroundColor: AppColors.danger,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text('Chiqish'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: googleLoading ? null : deleteAccount,
                          icon: const Icon(Icons.delete_forever_rounded),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: Color(0xFFEF9A9A)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          label: const Text('Delete account'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSoft,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.75)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 10,
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
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFB5B8C0),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialFooter extends StatelessWidget {
  const _SocialFooter();

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Link ochilmadi');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: _SocialIconButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Instagram',
                  color: const Color(0xFFE1306C),
                  onTap: () =>
                      _openLink('https://www.instagram.com/reel/DZZ3X7agYDW/'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SocialIconButton(
                  icon: Icons.send_rounded,
                  label: 'Telegram',
                  color: const Color(0xFF2AABEE),
                  onTap: () => _openLink('https://t.me/JURABEK_AUTOTEACHER'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  const _SocialIconButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionPage extends StatelessWidget {
  const SectionPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(onBack: () => Navigator.of(context).pop()),
              const SizedBox(height: 18),
              Expanded(
                child: Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onBack,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 46,
              height: 46,
              child: Icon(Icons.arrow_back_rounded),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Text(
          'Bo‘lim',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}
