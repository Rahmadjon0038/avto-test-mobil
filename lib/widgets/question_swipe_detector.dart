import 'package:flutter/material.dart';

class QuestionSwipeDetector extends StatelessWidget {
  const QuestionSwipeDetector({
    super.key,
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
  });

  final Widget child;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        const threshold = 250;
        if (velocity <= -threshold) {
          onSwipeLeft?.call();
        } else if (velocity >= threshold) {
          onSwipeRight?.call();
        }
      },
      child: child,
    );
  }
}
