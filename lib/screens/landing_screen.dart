import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../widgets/top_bar.dart';
import 'language_selection_page.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({
    super.key,
    required this.onLogin,
    required this.onRegister,
    required this.onLanguageChanged,
  });

  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final ValueChanged<String> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    const backgroundTop = Color(0xFFF7F9FF);
    const backgroundBottom = Color(0xFFF7F8FC);
    const surface = Color(0xFFFFFFFF);
    const surfaceSoft = Color(0xFFF8F8FA);
    const border = Color(0xFFD1D1D6);
    const text = Color(0xFF1C1C1E);
    const textMuted = Color(0xFF636366);
    const primary = Color(0xFF007AFF);

    return Scaffold(
      backgroundColor: backgroundTop,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              backgroundTop,
              surfaceSoft,
              backgroundBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TopBar(
                        backgroundColor: surface,
                        borderColor: border,
                        shadowColor: const Color(0x14000000),
                        brandColor: primary,
                        trailing: _LanguageHeaderButton(
                          onTap: () => _openLanguageSheet(context),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A000000),
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        strings.t('hero_ready'),
                                        style: TextStyle(
                                          fontSize: 21,
                                          height: 1.28,
                                          fontWeight: FontWeight.w800,
                                          color: text,
                                          letterSpacing: -0.6,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Padding(
                                        padding: EdgeInsets.only(top: 2),
                                        child: Text(
                                          strings.t('hero_subtitle'),
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            height: 1.38,
                                            color: textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 118,
                                  child: Image.asset(
                                    'assets/main.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: FilledButton(
                                        onPressed: onLogin,
                                        style: FilledButton.styleFrom(
                                        backgroundColor: primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            strings.t('login_to_tests'),
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          CircleAvatar(
                                            radius: 12,
                                            backgroundColor: Colors.white,
                                            child: Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 15,
                                              color: primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
                            subtitle: strings.t('topics_subtitle'),
                            onTap: onLogin,
                          ),
                          const SizedBox(height: 10),
                            _SectionCard(
                              icon: Icons.play_circle_fill_rounded,
                              iconColor: const Color(0xFF8E6BFF),
                            title: strings.t('videos'),
                            subtitle: strings.t('videos_subtitle'),
                            onTap: onLogin,
                          ),
                          const SizedBox(height: 10),
                            _SectionCard(
                              icon: Icons.receipt_long_rounded,
                              iconColor: const Color(0xFF34C759),
                            title: strings.t('tickets'),
                            subtitle: strings.t('tickets_subtitle'),
                            onTap: onLogin,
                          ),
                          const SizedBox(height: 10),
                            _SectionCard(
                              icon: Icons.local_fire_department_rounded,
                              iconColor: const Color(0xFFFF6B35),
                            title: strings.t('marathon'),
                            subtitle: strings.t('marathon_subtitle'),
                            onTap: onLogin,
                          ),
                          const SizedBox(height: 10),
                            _SectionCard(
                              icon: Icons.tune_rounded,
                              iconColor: const Color(0xFF8E6BFF),
                            title: strings.t('custom_tests'),
                            subtitle: strings.t('custom_tests_subtitle'),
                            onTap: onLogin,
                          ),
                          const SizedBox(height: 10),
                            _SectionCard(
                              icon: Icons.close_rounded,
                              iconColor: const Color(0xFFEE5A73),
                            title: strings.t('mistakes'),
                            subtitle: strings.t('mistakes_subtitle'),
                            onTap: onLogin,
                          ),
                          const SizedBox(height: 10),
                            _SectionCard(
                              icon: Icons.menu_book_rounded,
                              iconColor: const Color(0xFFF5A623),
                            title: strings.t('answers'),
                            subtitle: strings.t('answers_subtitle'),
                            onTap: onLogin,
                          ),
                          const SizedBox(height: 10),
                            _SectionCard(
                              icon: Icons.check_circle_rounded,
                              iconColor: const Color(0xFF2BBE8A),
                            title: strings.t('exam'),
                            subtitle: strings.t('exam_subtitle'),
                            onTap: onLogin,
                          ),
                        ],
                      ),
                        const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2E7BFF), Color(0xFF58A6FF)],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1F2E7BFF),
                              blurRadius: 16,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    strings.t('hero_banner_title'),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      height: 1.15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    strings.t('hero_banner_subtitle'),
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12.5,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    height: 38,
                                    width: 110,
                                    child: FilledButton(
                                      onPressed: onLogin,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF0F53D6,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              strings.t('hero_cta'),
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            CircleAvatar(
                                              radius: 9,
                                              backgroundColor: Colors.white,
                                              child: Icon(
                                                Icons.play_arrow_rounded,
                                                size: 11,
                                                color: Color(0xFF0F53D6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.emoji_events_rounded,
                              color: Color(0xFFFFD166),
                              size: 92,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openLanguageSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Theme(
          data: ThemeData.light(useMaterial3: true),
          child: LanguageSelectionPage(
            compact: true,
            onSelected: (code) {
              Navigator.of(sheetContext).pop();
              onLanguageChanged(code);
            },
          ),
        );
      },
    );
  }
}

class _LanguageHeaderButton extends StatelessWidget {
  const _LanguageHeaderButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 32,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF4FF), Color(0xFFDDEBFF)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB7D2FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x142E7BFF),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: const Icon(
          Icons.language_rounded,
          size: 20,
          color: Color(0xFF2F80ED),
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
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFFFFFFFF);
    const border = Color(0xFFD1D1D6);
    const text = Color(0xFF1C1C1E);
    const textMuted = Color(0xFF636366);
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border.withValues(alpha: 0.75)),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.25,
                        color: textMuted,
                      ),
                    ),
                  ],
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
