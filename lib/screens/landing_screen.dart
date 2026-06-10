import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../widgets/top_bar.dart';

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
          child: Column(
            children: [
              const TopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.98),
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
                                      const Text(
                                        'Haydovchilikka\ntayyormisiz?',
                                        style: TextStyle(
                                          fontSize: 21,
                                          height: 1.28,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.text,
                                          letterSpacing: -0.6,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2),
                                        child: Text(
                                          'Nazariy bilimlaringizni sinang\nva imtihonga tayyorlaning.',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            height: 1.38,
                                            color: AppColors.textMuted,
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
                                        backgroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Testlarga kirish',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          CircleAvatar(
                                            radius: 12,
                                            backgroundColor: Colors.white,
                                            child: Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 15,
                                              color: AppColors.primary,
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
                            title: 'Mavzu bo‘yicha testlar',
                            subtitle:
                                'Belgilar va qoidalarni bo‘limma-bo‘lim o‘rganing.',
                            onTap: onLogin,
                          ),
                          const SizedBox(height: 10),
                          _SectionCard(
                            icon: Icons.play_circle_fill_rounded,
                            iconColor: const Color(0xFF8E6BFF),
                            title: 'Video darsliklar',
                            subtitle: 'Mavzulashtirilgan video darsliklar.',
                            onTap: onLogin,
                          ),
                          const SizedBox(height: 10),
                          _SectionCard(
                            icon: Icons.receipt_long_rounded,
                            iconColor: const Color(0xFF34C759),
                            title: 'Biletlar bo‘yicha testlar',
                            subtitle:
                                'Rasmiy biletlar formatida yechib mashq qiling.',
                            onTap: onLogin,
                          ),
                          const SizedBox(height: 10),
                          _SectionCard(
                            icon: Icons.local_fire_department_rounded,
                            iconColor: const Color(0xFFFF6B35),
                            title: 'Marafon rejimi',
                            subtitle:
                                'Uzluksiz savollar: tezlik va aniqlikni oshiring.',
                            onTap: onLogin,
                          ),
                          const SizedBox(height: 10),
                          _SectionCard(
                            icon: Icons.tune_rounded,
                            iconColor: const Color(0xFF8E6BFF),
                            title: 'Sozlamali testlar',
                            subtitle: 'Savol soni va rejimni o‘zingiz tanlang.',
                            onTap: onLogin,
                          ),
                          const SizedBox(height: 10),
                          _SectionCard(
                            icon: Icons.close_rounded,
                            iconColor: const Color(0xFFEE5A73),
                            title: 'Mening xatolarim',
                            subtitle:
                                'Xato qilgan savollaringizni qayta ko‘rib chiqing.',
                            onTap: onLogin,
                          ),
                          const SizedBox(height: 10),
                          _SectionCard(
                            icon: Icons.menu_book_rounded,
                            iconColor: const Color(0xFFF5A623),
                            title: 'Barcha testlar javoblari',
                            subtitle:
                                'To‘g‘ri javoblarni izohlar bilan ko‘ring.',
                            onTap: onLogin,
                          ),
                          const SizedBox(height: 10),
                          _SectionCard(
                            icon: Icons.check_circle_rounded,
                            iconColor: const Color(0xFF2BBE8A),
                            title: 'Imtihon topshirish',
                            subtitle: 'Haqiqiy imtihondek sinovdan o‘ting.',
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
                                  const Text(
                                    'Bilimingizni\nsinab ko‘ring!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      height: 1.15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Test yeching, natijani kuzating\nva reytingda yuqorilang.',
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
                                      child: const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Boshlash',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            SizedBox(width: 8),
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
                            const Icon(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.25,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
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
