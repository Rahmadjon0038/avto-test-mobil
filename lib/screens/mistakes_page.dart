import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_constants.dart';
import '../models/auth_session.dart';
import '../models/mistake_question.dart';
import '../services/api_client.dart';
import '../services/question_page_settings_store.dart';
import '../widgets/question_explanation_footer.dart';
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
  int _currentIndex = 0;
  TabKey _tab = TabKey.list;
  bool _saving = false;
  bool _practiceFinished = false;
  bool _shuffleQuestions = false;
  bool _autoAdvanceEnabled = true;
  late String _accessToken;
  final GlobalKey _questionCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _accessToken = widget.session.accessToken;
    _mistakesFuture = _loadMistakes();
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

  @override
  Widget build(BuildContext context) {
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
                  title: 'Xatolar yuklanmadi',
                  subtitle: snapshot.error.toString(),
                  buttonText: 'Ortga qaytish',
                  onPressed: () => Navigator.of(context).pop(),
                );
              }

              final questions = snapshot.data ?? const <MistakeQuestion>[];

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
                    count: questions.length,
                    onChanged: (nextTab) {
                      setState(() => _tab = nextTab);
                    },
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _tab == TabKey.list
                        ? _buildListTab(context, questions)
                        : _buildPracticeTab(context, questions),
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
    if (questions.isEmpty) {
      return _EmptyState(
        icon: Icons.check_circle_rounded,
        title: 'Hozircha xato yo‘q',
        subtitle: 'Testlarda xato qilgan savollar shu yerda ko‘rinadi.',
        buttonText: 'Orqaga qaytish',
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
        );
      },
    );
  }

  Widget _buildPracticeTab(
    BuildContext context,
    List<MistakeQuestion> questions,
  ) {
    if (questions.isEmpty) {
      return _EmptyState(
        icon: Icons.menu_book_rounded,
        title: 'Mashq qilish uchun xato yo‘q',
        subtitle: 'Avval testlarda xato qiling, keyin shu yerda ishlaysiz.',
        buttonText: 'Orqaga qaytish',
        onPressed: () => Navigator.of(context).pop(),
      );
    }

    if (_currentIndex >= questions.length) {
      _currentIndex = questions.length - 1;
    }
    if (_currentIndex < 0) _currentIndex = 0;

    final currentQuestion = questions[_currentIndex];
    final selected = _answers[currentQuestion.id];
    final answered = selected != null;

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
                            _currentIndex += 1;
                          }
                        }
                      });
                      _scrollCurrentQuestionIntoView();
                    },
                  ),
                  if (answered && currentQuestion.explanation.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _ExplanationCard(text: currentQuestion.explanation),
                  ],
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
            finishLabel: _saving ? 'Saqlanmoqda...' : 'Yakunlash',
          ),
        ],
      ),
    );
  }

  void _restartPractice() {
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
      title: 'Test tugadi',
      message: 'Bu test yakunlangan. Davom etish uchun uni qayta boshlang.',
      onRestart: () async => _restartPractice(),
      restartLabel: 'Qayta boshlash',
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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
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
                const Text(
                  'Yakunlash',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 12),
                _StatRow(
                  label: 'Yechilgan',
                  value: '$answered/${questions.length}',
                ),
                const SizedBox(height: 10),
                _StatRow(label: 'To‘g‘ri bo‘lishi kutilgan', value: '$correct'),
                const SizedBox(height: 10),
                _StatRow(label: 'Qoladigan xatolar', value: '$wrong'),
                const SizedBox(height: 10),
                _StatRow(label: 'Foiz', value: '$percent%'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            Navigator.of(sheetContext).pop();
                            await _syncMistakes(questions);
                          },
                    child: Text(_saving ? 'Saqlanmoqda...' : 'Tasdiqlash'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _syncMistakes(List<MistakeQuestion> questions) async {
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
        SnackBar(content: Text('Yakunlandi: $fixed ta xato to‘g‘rilandi')),
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
      ).showSnackBar(SnackBar(content: Text(error.toString())));
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
    return Row(
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onBack,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 46,
              height: 46,
              child: Icon(Icons.arrow_back_rounded),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            'Mening xatolarim',
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
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onSettings,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 46,
              height: 46,
              child: Icon(Icons.settings_outlined, size: 22),
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
            label: 'Mening xatolarim',
            badge: count,
            icon: Icons.list_rounded,
            onTap: () => onChanged(TabKey.list),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TabButton(
            active: tab == TabKey.practice,
            label: 'Mashq qilish',
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active
                  ? AppColors.primary
                  : AppColors.border.withValues(alpha: 0.72),
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
                      : AppColors.surfaceSoft,
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
  });

  final MistakeQuestion question;
  final int index;
  final VoidCallback onPracticeTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.75)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title(index, question),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              question.text,
              style: const TextStyle(
                fontSize: 12.6,
                height: 1.22,
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
              const SizedBox(height: 8),
              Text(
                question.explanation,
                style: const TextStyle(
                  fontSize: 11.2,
                  height: 1.28,
                  color: AppColors.textMuted,
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
                child: const Text('Mashqda ochish'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _title(int index, MistakeQuestion question) {
    return '${index + 1}-savol';
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
    final backgroundColor = hasAnswered
        ? correct
              ? const Color(0xFFE1F5E8)
              : selected
              ? const Color(0xFFFDE3E3)
              : Colors.white
        : selected
        ? AppColors.surfaceTint
        : Colors.white;
    final borderColor = hasAnswered
        ? correct
              ? const Color(0xFF98D8AC)
              : selected
              ? const Color(0xFFEEA4A4)
              : AppColors.border.withValues(alpha: 0.72)
        : selected
        ? AppColors.primary.withValues(alpha: 0.32)
        : AppColors.border.withValues(alpha: 0.72);
    final iconBackground = hasAnswered
        ? correct
              ? const Color(0xFF21A65B)
              : selected
              ? const Color(0xFFD64545)
              : const Color(0xFFE9EDF6)
        : selected
        ? AppColors.primary
        : const Color(0xFFE9EDF6);
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
              ? const Color(0xFF178343)
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
                    fontSize: 13.2,
                    height: 1.22,
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

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ],
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
              : AppColors.surfaceSoft;
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
  });

  final MistakeQuestion question;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.text,
            style: const TextStyle(
              fontSize: 15.6,
              height: 1.28,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
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

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13.6,
          height: 1.42,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

Widget _buildQuestionImage(MistakeQuestion question) {
  final image = question.image.trim();
  if (image.isEmpty) {
    return Image.asset(
      'assets/default.png',
      width: double.infinity,
      fit: BoxFit.fitWidth,
      alignment: Alignment.center,
    );
  }

  if (image.startsWith('http://') || image.startsWith('https://')) {
    return Image.network(
      image,
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
        'assets/default.png',
        width: double.infinity,
        fit: BoxFit.fitWidth,
        alignment: Alignment.center,
      ),
    );
  }

  if (image.startsWith('/')) {
    return Image.network(
      '$apiBaseUrl$image',
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
        'assets/default.png',
        width: double.infinity,
        fit: BoxFit.fitWidth,
        alignment: Alignment.center,
      ),
    );
  }

  return image.startsWith('assets/')
      ? Image.asset(
          image,
          width: double.infinity,
          fit: BoxFit.fitWidth,
          alignment: Alignment.center,
          errorBuilder: (context, error, stackTrace) => Image.asset(
            'assets/default.png',
            width: double.infinity,
            fit: BoxFit.fitWidth,
            alignment: Alignment.center,
          ),
        )
      : Image.network(
          '$apiBaseUrl/$image',
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
            'assets/default.png',
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
                color: const Color(0xFFF7F8FB),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, color: AppColors.primary, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
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
