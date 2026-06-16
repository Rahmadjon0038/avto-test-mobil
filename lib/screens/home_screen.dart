import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/auth_session.dart';
import '../services/api_client.dart';
import 'privacy_policy_page.dart';
import 'custom_tests_page.dart';
import 'answers_page.dart';
import 'exam_page.dart';
import 'mistakes_page.dart';
import 'tickets_page.dart';
import 'topics_page.dart';
import 'marathon_page.dart';
import 'videos_page.dart';
import '../widgets/top_bar.dart';

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
                                    builder: (_) => VideosPage(
                                      session: session,
                                      onSessionUpdated: onSessionUpdated,
                                    ),
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
                          builder: (_) => TopicsPage(
                            session: session,
                            onSessionUpdated: onSessionUpdated,
                          ),
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
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              VideosPage(session: session, onSessionUpdated: onSessionUpdated),
        ),
      );
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SectionPage(title: title)));
  }

  void _openProfileSheet(BuildContext context) {
    final phoneCandidates = <String?>[
      session.user['phone']?.toString(),
      session.user['phoneNumber']?.toString(),
      session.user['mobile']?.toString(),
      session.user['tel']?.toString(),
    ];
    String phone = '';
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
        bool actionLoading = false;

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

        return MediaQuery.removePadding(
          context: sheetContext,
          removeBottom: true,
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              Future<void> deleteAccount() async {
                if (actionLoading) return;
                final accepted = await confirmDeleteAccount();
                if (!accepted) return;
                setSheetState(() => actionLoading = true);
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
                    setSheetState(() => actionLoading = false);
                  }
                }
              }

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
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
                                phone.isNotEmpty
                                    ? phone
                                    : 'Telefon raqam topilmadi',
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
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: onChangePassword,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.lock_reset_rounded),
                        label: const Text('Parolni almashtirish'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).push(
                            MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyPage(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.text,
                          side: BorderSide(
                            color: AppColors.border.withValues(alpha: 0.9),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.policy_outlined, size: 18),
                        label: const Text(
                          'Privacy Policy',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          onLogout();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1E40AF),
                          foregroundColor: Colors.white,
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
                      child: FilledButton(
                        onPressed: actionLoading ? null : deleteAccount,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFB91C1C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text('Delete account'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
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
