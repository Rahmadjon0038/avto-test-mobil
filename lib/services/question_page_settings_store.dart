import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_colors.dart';
import '../l10n/app_strings.dart';

class QuestionPageSettings {
  const QuestionPageSettings({
    required this.shuffleQuestions,
    required this.autoAdvance,
  });

  final bool shuffleQuestions;
  final bool autoAdvance;
}

class QuestionPageSettingsStore {
  const QuestionPageSettingsStore._();

  static const String _shuffleKey = 'question_page_shuffle_questions';
  static const String _autoAdvanceKey = 'question_page_auto_advance';

  static Future<QuestionPageSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return QuestionPageSettings(
      shuffleQuestions: prefs.getBool(_shuffleKey) ?? false,
      autoAdvance: prefs.getBool(_autoAdvanceKey) ?? true,
    );
  }

  static Future<void> setShuffleQuestions(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shuffleKey, value);
  }

  static Future<void> setAutoAdvance(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoAdvanceKey, value);
  }
}

Future<void> showQuestionPageSettingsSheet({
  required BuildContext context,
  required bool shuffleQuestions,
  required bool autoAdvance,
  required ValueChanged<bool> onShuffleChanged,
  required ValueChanged<bool> onAutoAdvanceChanged,
  bool showShuffleQuestions = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final strings = AppStrings.of(sheetContext);
      final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
      var shuffleEnabled = shuffleQuestions;
      var autoAdvanceEnabled = autoAdvance;

      return MediaQuery.removePadding(
        context: sheetContext,
        removeBottom: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface : AppColors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
            border: Border.all(
              color: isDark
                  ? AppColors.border.withValues(alpha: 0.85)
                  : AppColors.border.withValues(alpha: 0.65),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0xAA000000)
                    : const Color(0x14000000),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> updateShuffle(bool value) async {
                setModalState(() {
                  shuffleEnabled = value;
                });
                onShuffleChanged(value);
                await QuestionPageSettingsStore.setShuffleQuestions(value);
              }

              Future<void> updateAutoAdvance(bool value) async {
                setModalState(() {
                  autoAdvanceEnabled = value;
                });
                onAutoAdvanceChanged(value);
                await QuestionPageSettingsStore.setAutoAdvance(value);
              }

              return Column(
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
                    strings.t('settings_title'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceSoft : const Color(0xFFF8F9FD),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? AppColors.border.withValues(alpha: 0.9)
                            : AppColors.border.withValues(alpha: 0.75),
                      ),
                    ),
                    child: Column(
                      children: [
                        if (showShuffleQuestions) ...[
                          SwitchListTile.adaptive(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            title: Text(
                              strings.t('shuffle_questions_title'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                            subtitle: Text(
                              strings.t('shuffle_questions_subtitle'),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                            value: shuffleEnabled,
                            onChanged: (value) => updateShuffle(value),
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.border.withValues(alpha: 0.55),
                          ),
                        ],
                        SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          title: Text(
                            strings.t('auto_advance_title'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          subtitle: Text(
                            strings.t('auto_advance_subtitle'),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                          value: autoAdvanceEnabled,
                          onChanged: (value) => updateAutoAdvance(value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: Text(strings.t('close')),
                  ),
                ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}
