import 'package:flutter/material.dart';

import '../core/app_colors.dart';

class QuestionFooterNavButtons extends StatelessWidget {
  const QuestionFooterNavButtons({
    super.key,
    required this.onPrevious,
    required this.onNext,
  });

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _NavSquareButton(
          icon: Icons.chevron_left_rounded,
          onPressed: onPrevious,
        ),
        const SizedBox(width: 10),
        _NavSquareButton(icon: Icons.chevron_right_rounded, onPressed: onNext),
      ],
    );
  }
}

class _NavSquareButton extends StatelessWidget {
  const _NavSquareButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final backgroundColor = enabled
        ? const Color(0xFFEAF0FA)
        : const Color(0xFFF1F3F7);
    final foregroundColor = enabled ? AppColors.text : const Color(0xFFB2B8C5);

    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Icon(icon, size: 26, color: foregroundColor),
        ),
      ),
    );
  }
}
