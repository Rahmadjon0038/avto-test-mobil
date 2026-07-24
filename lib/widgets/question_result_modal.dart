import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../l10n/app_strings.dart';

Future<void> showQuestionResultModal({
  required BuildContext context,
  required int correct,
  required int wrong,
  required int total,
  required int unanswered,
  required int percent,
  required FutureOr<void> Function() onClose,
  bool popPageOnClose = false,
}) {
  final strings = AppStrings.of(context);
  final pageContext = context;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    builder: (modalContext) {
      return MediaQuery.removePadding(
        context: modalContext,
        removeBottom: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                strings.t('result_title'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ResultPieChart(
                    correct: correct,
                    wrong: wrong,
                    total: total,
                    unanswered: unanswered,
                    percent: percent,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      children: [
                        _ResultRow(
                          label: strings.t('result_correct_count'),
                          value: '$correct',
                        ),
                        const SizedBox(height: 10),
                        _ResultRow(
                          label: strings.t('result_wrong_count'),
                          value: '$wrong',
                        ),
                        const SizedBox(height: 10),
                        _ResultRow(
                          label: strings.t('result_total_count'),
                          value: '$total',
                        ),
                        const SizedBox(height: 10),
                        _ResultRow(
                          label: strings.t('result_unanswered_count'),
                          value: '$unanswered',
                        ),
                        const SizedBox(height: 10),
                        _ResultRow(
                          label: strings.t('result_percent'),
                          value: '$percent%',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () async {
                    Navigator.of(modalContext).pop();
                    await onClose();
                    if (popPageOnClose && pageContext.mounted) {
                      Navigator.of(pageContext).pop(true);
                    }
                  },
                  child: Text(strings.t('close')),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultPieChart extends StatelessWidget {
  const _ResultPieChart({
    required this.correct,
    required this.wrong,
    required this.total,
    required this.unanswered,
    required this.percent,
  });

  final int correct;
  final int wrong;
  final int total;
  final int unanswered;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return SizedBox(
      width: 138,
      child: SizedBox(
        width: 120,
        height: 120,
        child: CustomPaint(
          painter: _ResultPiePainter(
            correct: correct,
            wrong: wrong,
            unanswered: unanswered,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  strings.t('progress_label'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultPiePainter extends CustomPainter {
  _ResultPiePainter({
    required this.correct,
    required this.wrong,
    required this.unanswered,
  });

  final int correct;
  final int wrong;
  final int unanswered;

  @override
  void paint(Canvas canvas, Size size) {
    final total = correct + wrong + unanswered;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final basePaint = Paint()
      ..color = AppColors.surfaceSoft
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, basePaint);

    if (total <= 0) {
      final emptyPaint = Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, emptyPaint);
      return;
    }

    final segments = <({int value, Color color})>[
      (value: correct, color: const Color(0xFF21A65B)),
      (value: wrong, color: const Color(0xFFD64545)),
      (value: unanswered, color: const Color(0xFFB5B8C0)),
    ];

    var start = -math.pi / 2;
    for (final segment in segments) {
      if (segment.value <= 0) continue;
      final sweep = (segment.value / total) * math.pi * 2;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _ResultPiePainter oldDelegate) {
    return oldDelegate.correct != correct ||
        oldDelegate.wrong != wrong ||
        oldDelegate.unanswered != unanswered;
  }
}
