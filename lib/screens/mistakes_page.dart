import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_colors.dart';
import '../core/media_urls.dart';
import '../models/auth_session.dart';
import '../models/mistake_question.dart';
import '../l10n/app_strings.dart';
import '../services/api_client.dart';
import '../services/question_page_settings_store.dart';
import '../utils/friendly_error_message.dart';
import '../widgets/question_explanation_footer.dart';
import '../widgets/question_result_modal.dart';
import '../widgets/question_swipe_detector.dart';

class MistakesPage extends StatefulWidget {
  const MistakesPage({super.key, required this.session, this.onSessionUpdated});

  final AuthSession session;
  final ValueChanged<AuthSession>? onSessionUpdated;

  @override
  State<MistakesPage> createState() => _MistakesPageState();
}

class _MistakesPageState extends State<MistakesPage> {
  late Future<List<MistakeQuestion>> _mistakesFuture;
  final Map<String, int> _answers = <String, int>{};
  Set<String> _hiddenMistakeIds = <String>{};
  int _currentIndex = 0;
  TabKey _tab = TabKey.list;
  bool _saving = false;
  bool _practiceFinished = false;
  bool _shuffleQuestions = false;
  bool _autoAdvanceEnabled = true;
  bool _hiddenMistakesLoaded = false;
  late String _accessToken;
  String? _languageCode;
  final GlobalKey _questionCardKey = GlobalKey();
  Timer? _practiceAdvanceTimer;

  @override
  void initState() {
    super.initState();
    _accessToken = widget.session.accessToken;
    _languageCode = AppLanguageStore.currentCode;
    _mistakesFuture = _loadMistakes();
    _loadHiddenMistakes();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLanguage = AppLanguageScope.of(context).languageCode;
    if (_languageCode == currentLanguage) return;
    _languageCode = currentLanguage;
    _practiceAdvanceTimer?.cancel();
    setState(() {
      _mistakesFuture = _loadMistakes();
      _answers.clear();
      _currentIndex = 0;
      _tab = TabKey.list;
      _saving = false;
      _practiceFinished = false;
    });
  }

  Future<List<MistakeQuestion>> _loadMistakes() async {
    final settings = await QuestionPageSettingsStore.load();
    if (!mounted) return const <MistakeQuestion>[];
    _shuffleQuestions = settings.shuffleQuestions;
    _autoAdvanceEnabled = settings.autoAdvance;

    try {
      final questions = await ApiClient.mistakes(_accessToken);
      final result = List<MistakeQuestion>.from(questions);
      if (_shuffleQuestions) {
        result.shuffle();
      }
      return result;
    } on ApiException catch (error) {
      final refreshToken = widget.session.refreshToken;
      if (error.statusCode != 401 ||
          refreshToken == null ||
          refreshToken.isEmpty) {
        rethrow;
      }

      final refreshed = await ApiClient.refresh(refreshToken);
      if (!mounted) return const <MistakeQuestion>[];
      final active = refreshed.copyWith(user: widget.session.user);

      setState(() {
        _accessToken = active.accessToken;
      });
      widget.onSessionUpdated?.call(active);

      return ApiClient.mistakes(active.accessToken);
    }
  }

  static const String _hiddenMistakeStorageKey = 'hidden_mistake_question_ids';

  Future<void> _loadHiddenMistakes() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_hiddenMistakeStorageKey) ?? <String>[];
    if (!mounted) return;
    setState(() {
      _hiddenMistakeIds = saved.toSet();
      _hiddenMistakesLoaded = true;
    });
  }

  List<MistakeQuestion> _visibleMistakes(List<MistakeQuestion> questions) {
    return questions
        .where((question) => !_hiddenMistakeIds.contains(question.id))
        .toList();
  }

  Future<void> _hideMistake(MistakeQuestion question) async {
    final nextHidden = Set<String>.from(_hiddenMistakeIds)..add(question.id);
    setState(() {
      _hiddenMistakeIds = nextHidden;
      _answers.remove(question.id);
      if (_practiceFinished && _tab == TabKey.practice) {
        _practiceFinished = false;
      }
    });

    try {
      await ApiClient.mistakesProgress(
        accessToken: _accessToken,
        answers: <String, int>{question.id: question.correctIndex},
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppStrings.of(context).t('delete_question_failed')}: $error',
            ),
          ),
        );
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenMistakeStorageKey, nextHidden.toList());
  }

  @override
  void dispose() {
    _practiceAdvanceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FutureBuilder<List<MistakeQuestion>>(
            future: _mistakesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: strings.t('mistakes_load_failed'),
                  subtitle: friendlyErrorMessage(
                    context,
                    snapshot.error,
                    fallbackKey: 'mistakes_load_failed',
                  ),
                  buttonText: strings.t('mistakes_back'),
                  onPressed: () => Navigator.of(context).pop(),
                );
              }

              final questions = snapshot.data ?? const <MistakeQuestion>[];
              if (!_hiddenMistakesLoaded) {
                return const Center(child: CircularProgressIndicator());
              }
              final visibleQuestions = _visibleMistakes(questions);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    onBack: () => Navigator.of(context).pop(),
                    onSettings: () => showQuestionPageSettingsSheet(
                      context: context,
                      shuffleQuestions: _shuffleQuestions,
                      autoAdvance: _autoAdvanceEnabled,
                      onShuffleChanged: (value) {
                        setState(() {
                          _shuffleQuestions = value;
                          _currentIndex = 0;
                          _answers.clear();
                          _practiceFinished = false;
                          _tab = TabKey.list;
                          _mistakesFuture = _loadMistakes();
                        });
                      },
                      onAutoAdvanceChanged: (value) {
                        setState(() {
                          _autoAdvanceEnabled = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Tabs(
                    tab: _tab,
                    count: visibleQuestions.length,
                    onChanged: (nextTab) {
                      setState(() => _tab = nextTab);
                    },
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _tab == TabKey.list
                        ? _buildListTab(context, visibleQuestions)
                        : _buildPracticeTab(context, visibleQuestions),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildListTab(BuildContext context, List<MistakeQuestion> questions) {
    final strings = AppStrings.of(context);
    if (questions.isEmpty) {
      return _EmptyState(
        icon: Icons.check_circle_rounded,
        title: strings.t('mistakes_list_empty_title'),
        subtitle: strings.t('mistakes_list_empty_subtitle'),
        buttonText: strings.t('mistakes_back'),
        onPressed: () => Navigator.of(context).pop(),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: questions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final question = questions[index];
        return _MistakeCard(
          question: question,
          index: index,
          onPracticeTap: () {
            setState(() {
              _tab = TabKey.practice;
              _currentIndex = index;
            });
          },
          onDeleteTap: () => _hideMistake(question),
        );
      },
    );
  }

  Widget _buildPracticeTab(
    BuildContext context,
    List<MistakeQuestion> questions,
  ) {
    final strings = AppStrings.of(context);
    if (questions.isEmpty) {
      return _EmptyState(
        icon: Icons.menu_book_rounded,
        title: strings.t('mistakes_practice_empty_title'),
        subtitle: strings.t('mistakes_practice_empty_subtitle'),
        buttonText: strings.t('mistakes_back'),
        onPressed: () => Navigator.of(context).pop(),
      );
    }

    if (_currentIndex >= questions.length) {
      _currentIndex = questions.length - 1;
    }
    if (_currentIndex < 0) _currentIndex = 0;

    final currentQuestion = questions[_currentIndex];
    final selected = _answers[currentQuestion.id];

    return QuestionSwipeDetector(
      onSwipeLeft: _practiceFinished
          ? () => _showLockedRestartModal()
          : _currentIndex < questions.length - 1
          ? () {
              setState(() {
                _currentIndex += 1;
              });
              _scrollCurrentQuestionIntoView();
            }
          : null,
      onSwipeRight: _practiceFinished
          ? () => _showLockedRestartModal()
          : _currentIndex > 0
          ? () {
              setState(() {
                _currentIndex -= 1;
              });
              _scrollCurrentQuestionIntoView();
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QuestionNavigator(
            total: questions.length,
            currentIndex: _currentIndex,
            questionIds: questions.map((q) => q.id).toList(),
            answeredStates: _answers,
            correctAnswers: questions.map((q) => q.correctIndex).toList(),
            onTap: (index) {
              if (_practiceFinished) {
                _showLockedRestartModal();
                return;
              }
              setState(() {
                _currentIndex = index;
              });
              _scrollCurrentQuestionIntoView();
            },
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _QuestionCard(
                    key: _questionCardKey,
                    question: currentQuestion,
                    selectedIndex: selected,
                    onDeleteTap: () => _hideMistake(currentQuestion),
                    onSelect: (index) {
                      if (_practiceFinished) {
                        _showLockedRestartModal();
                        return;
                      }
                      setState(() {
                        if (_answers[currentQuestion.id] == null) {
                          _answers[currentQuestion.id] = index;
                          if (_autoAdvanceEnabled &&
                              _currentIndex < questions.length - 1) {
                            _practiceAdvanceTimer?.cancel();
                            _practiceAdvanceTimer = Timer(
                              const Duration(milliseconds: 1600),
                              () {
                                if (!mounted || _practiceFinished) return;
                                setState(() {
                                  _currentIndex += 1;
                                });
                                _scrollCurrentQuestionIntoView();
                              },
                            );
                          }
                        }
                      });
                      _scrollCurrentQuestionIntoView();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          QuestionExplanationFooter(
            questionText: currentQuestion.text,
            correctAnswer: currentQuestion.correctAnswer,
            explanation: currentQuestion.explanation,
            audioUrl: currentQuestion.audio,
            onFinish: _saving
                ? null
                : _practiceFinished
                ? () => _showLockedRestartModal()
                : () => _openFinishSheet(questions),
            onRestart: _restartPractice,
            finishLabel: _saving
                ? strings.t('mistakes_saving')
                : strings.t('mistakes_finish'),
          ),
        ],
      ),
    );
  }

  void _restartPractice() {
    _practiceAdvanceTimer?.cancel();
    setState(() {
      _answers.clear();
      _currentIndex = 0;
      _practiceFinished = false;
    });
    _scrollCurrentQuestionIntoView();
  }

  Future<void> _showLockedRestartModal() {
    return showTestLockedRestartSheet(
      context: context,
      title: AppStrings.of(context).t('mistakes_test_finished_title'),
      message: AppStrings.of(context).t('mistakes_test_finished_message'),
      onRestart: () async => _restartPractice(),
      restartLabel: AppStrings.of(context).t('mistakes_restart'),
    );
  }

  void _scrollCurrentQuestionIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentContext = _questionCardKey.currentContext;
      if (currentContext == null) return;
      Scrollable.ensureVisible(
        currentContext,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        alignment: 0.45,
      );
    });
  }

  Future<void> _openFinishSheet(List<MistakeQuestion> questions) async {
    if (mounted) {
      setState(() => _practiceFinished = true);
    }
    final correct = questions
        .where(
          (question) =>
              _answers[question.id] != null &&
              _answers[question.id] == question.correctIndex,
        )
        .length;
    final answered = _answers.length;
    final wrong = answered - correct;
    final percent = questions.isEmpty
        ? 0
        : ((correct / questions.length) * 100).round();

    await showQuestionResultModal(
      context: context,
      correct: correct,
      wrong: wrong,
      total: questions.length,
      unanswered: (questions.length - answered).clamp(0, questions.length),
      percent: percent,
      onClose: () async {
        await _syncMistakes(questions);
      },
      popPageOnClose: true,
    );
  }

  Future<void> _syncMistakes(List<MistakeQuestion> questions) async {
    _practiceAdvanceTimer?.cancel();
    setState(() => _saving = true);
    try {
      final payload = <String, int>{};
      for (final question in questions) {
        final answer = _answers[question.id];
        if (answer != null) {
          payload[question.id] = answer;
        }
      }

      final result = await ApiClient.mistakesProgress(
        accessToken: _accessToken,
        answers: payload,
      );

      if (!mounted) return;
      final fixed = (result['fixed'] ?? 0).toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.of(context)
                .t('mistakes_synced')
                .replaceFirst('{fixed}', fixed),
          ),
        ),
      );

      setState(() {
        _tab = TabKey.list;
        _answers.clear();
        _currentIndex = 0;
        _mistakesFuture = _loadMistakes();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(
              context,
              error,
              fallbackKey: 'mistakes_load_failed',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

enum TabKey { list, practice }

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onSettings});

  final VoidCallback onBack;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Row(
      children: [
        Material(
          color: isDark ? AppColors.surfaceSoft : AppColors.surface,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onBack,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(Icons.arrow_back_rounded, color: AppColors.text),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            AppStrings.of(context).t('mistakes_title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: isDark ? AppColors.surfaceSoft : AppColors.surface,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onSettings,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(
                Icons.settings_outlined,
                size: 22,
                color: AppColors.text,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.tab,
    required this.count,
    required this.onChanged,
  });

  final TabKey tab;
  final int count;
  final ValueChanged<TabKey> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TabButton(
            active: tab == TabKey.list,
            label: AppStrings.of(context).t('mistakes_title'),
            badge: count,
            icon: Icons.list_rounded,
            onTap: () => onChanged(TabKey.list),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TabButton(
            active: tab == TabKey.practice,
            label: AppStrings.of(context).t('practice'),
            badge: count,
            icon: Icons.task_alt_rounded,
            onTap: () => onChanged(TabKey.practice),
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.active,
    required this.label,
    required this.badge,
    required this.icon,
    required this.onTap,
  });

  final bool active;
  final String label;
  final int badge;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary
                : (isDark ? AppColors.surfaceSoft : Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active
                  ? AppColors.primary
                  : AppColors.border.withValues(alpha: isDark ? 0.9 : 0.72),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? Colors.white : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.7,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.2)
                      : (isDark ? AppColors.surface : AppColors.surfaceSoft),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$badge',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.textMuted,
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

class _MistakeCard extends StatelessWidget {
  const _MistakeCard({
    required this.question,
    required this.index,
    required this.onPracticeTap,
    required this.onDeleteTap,
  });

  final MistakeQuestion question;
  final int index;
  final VoidCallback onPracticeTap;
  final VoidCallback onDeleteTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final cardColor = isDark ? AppColors.surface : Colors.white;
    final deleteTint = isDark
        ? const Color(0xFF3A2020)
        : const Color(0xFFFFECEB);
    final shadow = isDark
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ]
        : const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ];
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.border.withValues(alpha: isDark ? 0.9 : 0.75),
          ),
          boxShadow: shadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 56, top: 2),
                    child: Text(
                      _title(context, index, question),
                      style: TextStyle(
                        fontSize: 13.8,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -2,
                    right: 0,
                    child: Material(
                      color: deleteTint,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: onDeleteTap,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Icon(
                            Icons.delete_forever_rounded,
                            size: 19,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              question.text,
              style: TextStyle(
                fontSize: 14.6,
                height: 1.34,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            if (question.image.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _buildQuestionImage(question),
              ),
            ],
            const SizedBox(height: 10),
            _CompactOptionList(
              options: question.options,
              selectedIndex: question.wrongAnswer,
              correctIndex: question.correctIndex,
              interactive: false,
            ),
            if (question.explanation.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                question.explanation,
                style: TextStyle(
                  fontSize: 13.6,
                  height: 1.44,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            if (question.audio.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    showQuestionAudioExplanationSheet(
                      context: context,
                      audioUrl: question.audio,
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(Icons.volume_up_rounded, size: 18),
                  label: Text(
                    AppStrings.of(context).t('audio_explanation'),
                    style: TextStyle(
                      fontSize: 12.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: FilledButton(
                onPressed: onPracticeTap,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(AppStrings.of(context).t('mistakes_open_practice')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _title(BuildContext context, int index, MistakeQuestion question) {
    return '${index + 1}-${AppStrings.of(context).t('question_suffix')}';
  }
}

class _CompactOptionList extends StatelessWidget {
  const _CompactOptionList({
    required this.options,
    required this.selectedIndex,
    required this.correctIndex,
    required this.interactive,
    this.onSelect,
  });

  final List<String> options;
  final int? selectedIndex;
  final int correctIndex;
  final bool interactive;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(options.length, (index) {
        if (index > 0) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _CompactOptionListItem(
              option: options[index],
              selected: selectedIndex == index,
              correct: index == correctIndex,
              interactive: interactive,
              onTap: onSelect == null ? null : () => onSelect!(index),
              hasAnswered: selectedIndex != null,
            ),
          );
        }

        return _CompactOptionListItem(
          option: options[index],
          selected: selectedIndex == index,
          correct: index == correctIndex,
          interactive: interactive,
          onTap: onSelect == null ? null : () => onSelect!(index),
          hasAnswered: selectedIndex != null,
        );
      }),
    );
  }
}

class _CompactOptionListItem extends StatelessWidget {
  const _CompactOptionListItem({
    required this.option,
    required this.selected,
    required this.correct,
    required this.interactive,
    required this.hasAnswered,
    this.onTap,
  });

  final String option;
  final bool selected;
  final bool correct;
  final bool interactive;
  final bool hasAnswered;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final backgroundColor = hasAnswered
        ? correct
              ? (isDark ? const Color(0xFF163625) : const Color(0xFFE1F5E8))
              : selected
              ? (isDark ? const Color(0xFF3B2023) : const Color(0xFFFDE3E3))
              : (isDark ? AppColors.surfaceSoft : Colors.white)
        : selected
        ? AppColors.surfaceTint
        : (isDark ? AppColors.surface : Colors.white);
    final borderColor = hasAnswered
        ? correct
              ? (isDark ? const Color(0xFF2E6E49) : const Color(0xFF98D8AC))
              : selected
              ? (isDark ? const Color(0xFF8C4E50) : const Color(0xFFEEA4A4))
              : AppColors.border.withValues(alpha: isDark ? 0.9 : 0.72)
        : selected
        ? AppColors.primary.withValues(alpha: 0.32)
        : AppColors.border.withValues(alpha: isDark ? 0.9 : 0.72);
    final iconBackground = hasAnswered
        ? correct
              ? const Color(0xFF21A65B)
              : selected
              ? const Color(0xFFD64545)
              : (isDark ? const Color(0xFF2A3550) : const Color(0xFFE9EDF6))
        : selected
        ? AppColors.primary
        : (isDark ? const Color(0xFF2A3550) : const Color(0xFFE9EDF6));
    final icon = hasAnswered
        ? correct
              ? Icons.check_rounded
              : selected
              ? Icons.close_rounded
              : Icons.circle_outlined
        : selected
        ? Icons.check_rounded
        : Icons.circle_outlined;
    final textColor = hasAnswered
        ? correct
              ? (isDark ? const Color(0xFF7EE2A8) : const Color(0xFF178343))
              : selected
              ? const Color(0xFFD64545)
              : AppColors.text
        : selected
        ? Colors.white
        : AppColors.text;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: interactive ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 13,
                  color: hasAnswered && (correct || selected)
                      ? Colors.white
                      : selected
                      ? Colors.white
                      : AppColors.textSoft,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  option,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.4,
                    height: 1.24,
                    fontWeight: FontWeight.w700,
                    color: textColor,
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

class _QuestionNavigator extends StatelessWidget {
  const _QuestionNavigator({
    required this.total,
    required this.currentIndex,
    required this.questionIds,
    required this.answeredStates,
    required this.correctAnswers,
    required this.onTap,
  });

  final int total;
  final int currentIndex;
  final List<String> questionIds;
  final Map<String, int> answeredStates;
  final List<int> correctAnswers;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: total,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final questionId = questionIds[index];
          final answered = answeredStates.containsKey(questionId);
          final isCurrent = index == currentIndex;
          final isCorrect =
              answered && answeredStates[questionId] == correctAnswers[index];
          final backgroundColor = isCurrent
              ? const Color(0xFF1F4FD0)
              : answered
              ? isCorrect
                    ? const Color(0xFF21A65B)
                    : const Color(0xFFD64545)
              : (isDark ? AppColors.surfaceSoft : AppColors.surfaceSoft);
          final borderColor = isCurrent
              ? const Color(0xFF7FA6FF)
              : answered
              ? isCorrect
                    ? const Color(0xFF5BC37E)
                    : const Color(0xFFE06A6A)
              : AppColors.border.withValues(alpha: 0.85);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onTap(index),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isCurrent || answered
                        ? Colors.white
                        : AppColors.text,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    super.key,
    required this.question,
    required this.selectedIndex,
    required this.onSelect,
    required this.onDeleteTap,
  });

  final MistakeQuestion question;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onDeleteTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final cardColor = isDark ? AppColors.surface : Colors.white;
    final shadow = isDark
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ]
        : const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border.withValues(alpha: isDark ? 0.9 : 0.72),
        ),
        boxShadow: shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 58, top: 2),
                  child: Text(
                    question.text,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.34,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Positioned(
                  top: -2,
                  right: 0,
                  child: Material(
                    color: isDark
                        ? const Color(0xFF3A2020)
                        : const Color(0xFFFFECEB),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: onDeleteTap,
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Icon(
                          Icons.delete_forever_rounded,
                          size: 20,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (question.image.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _buildQuestionImage(question),
            ),
          ],
          const SizedBox(height: 10),
          _CompactOptionList(
            options: question.options,
            selectedIndex: selectedIndex,
            correctIndex: question.correctIndex,
            interactive: selectedIndex == null,
            onSelect: onSelect,
          ),
        ],
      ),
    );
  }
}

Widget _buildQuestionImage(MistakeQuestion question) {
  final imageUrl = resolveQuestionImageUrl(question.image);
  if (imageUrl == defaultQuestionImageAsset) {
    return Image.asset(
      defaultQuestionImageAsset,
      width: double.infinity,
      fit: BoxFit.fitWidth,
      alignment: Alignment.center,
    );
  }

  return Image.network(
    imageUrl,
    width: double.infinity,
    fit: BoxFit.fitWidth,
    alignment: Alignment.center,
    loadingBuilder: (context, child, loadingProgress) {
      if (loadingProgress == null) return child;
      return const SizedBox(
        height: 120,
        width: double.infinity,
        child: Center(
          child: SizedBox(
            height: 28,
            width: 28,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    },
    errorBuilder: (context, error, stackTrace) => Image.asset(
      defaultQuestionImageAsset,
      width: double.infinity,
      fit: BoxFit.fitWidth,
      alignment: Alignment.center,
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final emptyColor = isDark ? AppColors.surfaceSoft : const Color(0xFFF7F8FB);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: emptyColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, color: AppColors.primary, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 180,
              height: 48,
              child: FilledButton(
                onPressed: onPressed,
                child: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
