import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/auth_session.dart';
import '../models/app_bootstrap.dart';
import '../services/api_client.dart';
import '../l10n/app_strings.dart';
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
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onLanguageChanged,
  });

  final AuthSession session;
  final VoidCallback onLogout;
  final VoidCallback onLogin;
  final ValueChanged<AuthSession> onSessionUpdated;
  final VoidCallback onChangePassword;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<String> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.isDarkMode
                ? [
                    const Color(0xFF0E1626),
                    AppColors.background,
                    const Color(0xFF111A2D),
                  ]
                : [
                    const Color(0xFFF7F9FF),
                    AppColors.background,
                    const Color(0xFFF7F8FC),
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
                          gradient: LinearGradient(
                            colors: AppColors.isDarkMode
                                ? [
                                    const Color(0xFF25324B),
                                    const Color(0xFF1C2B44),
                                  ]
                                : [
                                    const Color(0xFFEAF4FF),
                                    const Color(0xFFDCEBFF),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF77AFFF).withValues(
                              alpha: AppColors.isDarkMode ? 0.35 : 0.25,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF77AFFF).withValues(
                                alpha: AppColors.isDarkMode ? 0.12 : 0.18,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () => _openLanguageSheet(context),
                          borderRadius: BorderRadius.circular(14),
                          child: Icon(
                            Icons.language_rounded,
                            size: 20,
                            color: const Color(0xFF2F80ED),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 42,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: AppColors.isDarkMode
                                ? [
                                    const Color(0xFF2D243C),
                                    const Color(0xFF221B31),
                                  ]
                                : [
                                    const Color(0xFFF1ECFF),
                                    const Color(0xFFE4DBFF),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF8E6BFF).withValues(
                              alpha: AppColors.isDarkMode ? 0.35 : 0.25,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8E6BFF).withValues(
                                alpha: AppColors.isDarkMode ? 0.10 : 0.16,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () {
                            final nextMode = themeMode == ThemeMode.dark
                                ? ThemeMode.light
                                : ThemeMode.dark;
                            onThemeModeChanged(nextMode);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Icon(
                            themeMode == ThemeMode.dark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_outlined,
                            size: 20,
                            color: themeMode == ThemeMode.dark
                                ? const Color(0xFFFCD34D)
                                : const Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 42,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: AppColors.isDarkMode
                                ? [
                                    const Color(0xFF24362E),
                                    const Color(0xFF1A2A23),
                                  ]
                                : [
                                    const Color(0xFFE9FBF0),
                                    const Color(0xFFD6F5E1),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF22C55E).withValues(
                              alpha: AppColors.isDarkMode ? 0.32 : 0.22,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF22C55E).withValues(
                                alpha: AppColors.isDarkMode ? 0.08 : 0.14,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () => _openProfileSheet(context),
                          borderRadius: BorderRadius.circular(14),
                          child: Icon(
                            Icons.person_outline_rounded,
                            size: 22,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
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
                            Text(
                              strings.t('videos'),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                              Text(
                              strings.t('videos_subtitle'),
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
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                  elevation: 0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      strings.t('hero_cta'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1F4FD0),
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
                      Icon(
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
                      title: strings.t('topics'),
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
                      title: strings.t('tickets'),
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
                      title: strings.t('marathon'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MarathonPage(
                            session: session,
                            onSessionUpdated: onSessionUpdated,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SectionCard(
                      icon: Icons.tune_rounded,
                      iconColor: const Color(0xFF8E6BFF),
                      title: strings.t('custom_tests'),
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
                      title: strings.t('mistakes'),
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
                      title: strings.t('answers'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AnswersPage(
                            session: session,
                            onSessionUpdated: onSessionUpdated,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SectionCard(
                      icon: Icons.check_circle_rounded,
                      iconColor: const Color(0xFF2BBE8A),
                      title: strings.t('exam'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ExamPage(
                            session: session,
                            onSessionUpdated: onSessionUpdated,
                          ),
                        ),
                      ),
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

  void _openProfileSheet(BuildContext context) {
    final strings = AppStrings.of(context);
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
                title: Text(strings.t('delete_account_title')),
                content: Text(
                  strings.t('delete_account_message'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(strings.t('cancel')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(strings.t('confirm')),
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
                  color: AppColors.surface,
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
                          child: Icon(
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
                              Text(
                                strings.t('profile'),
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
                                    : strings.t('phone_not_found'),
                                style: TextStyle(
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
                        icon: Icon(Icons.lock_reset_rounded),
                        label: Text(strings.t('change_password')),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          if (Platform.isMacOS) {
                            launchUrl(
                              Uri.parse('https://topshirdi.uz/privacy'),
                              mode: LaunchMode.externalApplication,
                            );
                            return;
                          }
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
                        icon: Icon(Icons.policy_outlined, size: 18),
                        label: Text(
                          strings.t('privacy_policy'),
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
                        child: Text(strings.t('logout')),
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
                        child: Text(strings.t('delete_account')),
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

  void _openLanguageSheet(BuildContext context) {
    final strings = AppStrings.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
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
              Text(
                strings.t('choose_language'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                strings.t('choose_language_desc'),
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              _LanguageOption(
                label: strings.t('uz_latn'),
                selected: AppLanguageScope.of(context).languageCode ==
                    AppLanguageStore.uzLatn,
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  onLanguageChanged(AppLanguageStore.uzLatn);
                },
              ),
              const SizedBox(height: 10),
              _LanguageOption(
                label: strings.t('uz_cyrl'),
                selected: AppLanguageScope.of(context).languageCode ==
                    AppLanguageStore.uzCyrl,
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  onLanguageChanged(AppLanguageStore.uzCyrl);
                },
              ),
              const SizedBox(height: 10),
              _LanguageOption(
                label: strings.t('ru'),
                selected:
                    AppLanguageScope.of(context).languageCode == AppLanguageStore.ru,
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  onLanguageChanged(AppLanguageStore.ru);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ignore: unused_element
class _OfflineStatusBanner extends StatelessWidget {
  const _OfflineStatusBanner({
    required this.ready,
    required this.title,
    required this.subtitle,
    required this.manifest,
  });

  final bool ready;
  final String title;
  final String subtitle;
  final OfflineManifest? manifest;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final borderColor = ready
        ? const Color(0xFF22C55E).withValues(alpha: isDark ? 0.35 : 0.25)
        : const Color(0xFF2F80ED).withValues(alpha: isDark ? 0.35 : 0.25);
    final background = ready
        ? const LinearGradient(
            colors: [Color(0xFF0F2A22), Color(0xFF102C1E)],
          )
        : const LinearGradient(
            colors: [Color(0xFF132238), Color(0xFF172B46)],
          );

    final topics = manifest?.topics.count ?? 0;
    final tickets = manifest?.tickets.count ?? 0;
    final customTests = manifest?.customTests.count ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: ready
                  ? const Color(0xFF22C55E).withValues(alpha: 0.16)
                  : const Color(0xFF2F80ED).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              ready ? Icons.cloud_done_rounded : Icons.sync_rounded,
              color: ready ? const Color(0xFF4ADE80) : const Color(0xFF5BA8FF),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniCountChip(label: 'Mavzular', value: topics),
                    _MiniCountChip(label: 'Biletlar', value: tickets),
                    _MiniCountChip(label: 'Testlar', value: customTests),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCountChip extends StatelessWidget {
  const _MiniCountChip({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
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
      color: AppColors.surface,
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
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? AppColors.border.withValues(alpha: 0.95)
              : AppColors.border.withValues(alpha: 0.72),
        ),
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
                  onTap: () => _openLink(
                    'https://www.instagram.com/reel/DZZ3X7agYDW/',
                  ),
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
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: _SocialIconButton(
              icon: Icons.camera_alt_rounded,
              label: 'Instagram',
              color: const Color(0xFFC13584),
              onTap: () => _openLink('https://www.instagram.com/topshirdi_uz/'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.surfaceTint : AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.38)
                  : AppColors.border.withValues(alpha: 0.75),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  selected ? Icons.check_circle_rounded : Icons.language_rounded,
                  color: selected ? AppColors.primary : AppColors.textSoft,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.surfaceSoft : AppColors.surface;
    final borderColor = isDark
        ? AppColors.border.withValues(alpha: 0.95)
        : color.withValues(alpha: 0.18);
    final foregroundColor = isDark ? AppColors.text : color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: foregroundColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: foregroundColor,
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
                    color: AppColors.surface,
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
                      style: TextStyle(
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
              color: AppColors.surface,
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
        Text(
          AppStrings.of(context).t('section_title'),
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
