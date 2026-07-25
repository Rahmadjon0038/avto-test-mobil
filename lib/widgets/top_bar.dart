import 'package:flutter/material.dart';

import '../core/app_colors.dart';

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    this.trailing,
    this.backgroundColor,
    this.borderColor,
    this.shadowColor,
    this.brandColor,
  });

  final Widget? trailing;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? shadowColor;
  final Color? brandColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(18)),
          border: Border.fromBorderSide(
            BorderSide(
              color:
                  borderColor ?? AppColors.border.withValues(alpha: 0.85),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: shadowColor ?? AppColors.shadow,
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
          child: Row(
            children: [
              _BrandMark(color: brandColor ?? AppColors.primary),
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
  const _BrandMark({required this.color});

  final Color color;

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
        Text.rich(
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
                style: TextStyle(color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
