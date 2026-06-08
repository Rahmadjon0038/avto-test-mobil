import 'package:flutter/material.dart';

import '../core/app_colors.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFDFDFD), Color(0xFFF2F2F7)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/logo.png',
                width: 92,
                height: 92,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 14),
              const Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.8,
                  ),
                  children: [
                    TextSpan(
                      text: 'ROAD ',
                      style: TextStyle(color: AppColors.primary),
                    ),
                    TextSpan(
                      text: 'TEST',
                      style: TextStyle(color: AppColors.text),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
