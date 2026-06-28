import 'package:flutter/material.dart';

import '../core/app_colors.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key, this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(18)),
          border: Border.fromBorderSide(
            BorderSide(color: Color(0xFFDDE2EA), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
          child: Row(
            children: [
              const _BrandMark(),
              const Spacer(),
              if (trailing case final Widget widget) widget,
            ],
          ),
        ),
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
      children: [
        Image.asset(
          'assets/logo.png',
          width: 24,
          height: 24,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 8),
        const Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.0,
              letterSpacing: -0.3,
              fontStyle: FontStyle.italic,
            ),
            children: [
              TextSpan(
                text: 'Topshirdi',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
