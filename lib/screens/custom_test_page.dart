import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_constants.dart';
import '../models/auth_session.dart';
import '../models/ticket_summary.dart';
import '../models/topic_question.dart';
import '../services/api_client.dart';
import '../services/question_page_settings_store.dart';
import '../widgets/question_explanation_footer.dart';
import '../widgets/question_swipe_detector.dart';

class CustomTestPage extends StatefulWidget {
  const CustomTestPage({
    super.key,
    required this.session,
    required this.ticket,
    this.onSessionUpdated,
  });

  final AuthSession session;
  final TicketSummary ticket;
  final ValueChanged<AuthSession>? onSessionUpdated;

  @override
  State<CustomTestPage> createState() => _CustomTestPageState();
}

class _CustomTestPageState extends State<CustomTestPage> {
  late Future<List<TopicQuestion>> _questionsFuture;
  final List<int?> _answers = <int?>[];
  int _currentIndex = 0;
  int? _selectedIndex;
  bool _resultShown = false;
  bool _shuffleQuestions = false;
  bool _autoAdvanceEnabled = true;
  List<TopicQuestion>? _loadedQuestions;
  late String _accessToken;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _questionCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _accessToken = widget.session.accessToken;
    _questionsFuture = _loadQuestions();
  }

  Future<List<TopicQuestion>> _loadQuestions() async {
    final settings = await QuestionPageSettingsStore.load();
    if (!mounted) return const <TopicQuestion>[];
    _shuffleQuestions = settings.shuffleQuestions;
    _autoAdvanceEnabled = settings.autoAdvance;

    try {
      final questions = await ApiClient.customTestQuestions(
        accessToken: _accessToken,
        testId: widget.ticket.id,
      );
      final result = List<TopicQuestion>.from(questions);
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
      if (!mounted) return const <TopicQuestion>[];
      final active = refreshed.copyWith(user: widget.session.user);

      setState(() {
        _accessToken = active.accessToken;
      });
      widget.onSessionUpdated?.call(active);

      return ApiClient.customTestQuestions(
        accessToken: active.accessToken,
        testId: widget.ticket.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: QuestionSwipeDetector(
          onSwipeLeft: _resultShown
              ? () => _showLockedRestartModal()
              : _goToNextQuestion,
          onSwipeRight: _resultShown
              ? () => _showLockedRestartModal()
              : _goToPreviousQuestion,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<List<TopicQuestion>>(
              future: _questionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _EmptyState(
                    title: 'Bu testda savollar mavjud emas',
                    subtitle:
                        'Hozircha ushbu test uchun savollar qo‘shilmagan.',
                    buttonText: 'Ortga qaytish',
                    onPressed: () => Navigator.of(context).pop(),
                  );
                }

                final questions = snapshot.data ?? const <TopicQuestion>[];
                if (questions.isEmpty) {
                  return _EmptyState(
                    title: 'Bu testda savollar mavjud emas',
                    subtitle:
                        'Hozircha ushbu test uchun savollar qo‘shilmagan.',
                    buttonText: 'Ortga qaytish',
                    onPressed: () => Navigator.of(context).pop(),
                  );
                }

                _loadedQuestions = questions;
                final question = questions[_currentIndex];
                final locked = _resultShown;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            customBorder: const CircleBorder(),
                            child: const SizedBox(
                              width: 46,
                              height: 46,
                              child: Icon(Icons.arrow_back_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.ticket.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_currentIndex + 1}/${questions.length} savol',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _SettingsButton(
                          onTap: () => showQuestionPageSettingsSheet(
                            context: context,
                            shuffleQuestions: _shuffleQuestions,
                            autoAdvance: _autoAdvanceEnabled,
                            onShuffleChanged: (value) {
                              setState(() {
                                _shuffleQuestions = value;
                                _currentIndex = 0;
                                _selectedIndex = null;
                                _answers.clear();
                                _resultShown = false;
                                _loadedQuestions = null;
                                _questionsFuture = _loadQuestions();
                              });
                            },
                            onAutoAdvanceChanged: (value) {
                              setState(() {
                                _autoAdvanceEnabled = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _QuestionNavigator(
                              total: questions.length,
                              currentIndex: _currentIndex,
                              answeredStates: _answers,
                              correctAnswers: questions
                                  .map((question) => question.correctIndex)
                                  .toList(),
                              onTap: (index) {
                                if (locked) {
                                  _showLockedRestartModal();
                                  return;
                                }
                                setState(() {
                                  _currentIndex = index;
                                  _selectedIndex = _answerFor(_currentIndex);
                                });
                                _scrollCurrentQuestionIntoView();
                              },
                            ),
                            const SizedBox(height: 14),
                            Container(
                              key: _questionCardKey,
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: AppColors.border.withValues(
                                    alpha: 0.72,
                                  ),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x08000000),
                                    blurRadius: 14,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    question.text,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.28,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  GestureDetector(
                                    onTap: () => _openImagePreview(
                                      _questionImageUrl(question),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: _buildQuestionImage(question),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            ...List.generate(question.options.length, (index) {
                              final selected = _selectedIndex == index;
                              final isCorrect = index == question.correctIndex;
                              final showResult = _selectedIndex != null;
                              final backgroundColor = showResult
                                  ? isCorrect
                                        ? const Color(0xFFCFF0D9)
                                        : selected
                                        ? const Color(0xFFF4C5C5)
                                        : Colors.white
                                  : selected
                                  ? AppColors.surfaceTint
                                  : Colors.white;
                              final borderColor = showResult
                                  ? isCorrect
                                        ? const Color(0xFF6CBF86)
                                        : selected
                                        ? const Color(0xFFDD6B6B)
                                        : AppColors.border.withValues(
                                            alpha: 0.72,
                                          )
                                  : selected
                                  ? AppColors.primary.withValues(alpha: 0.28)
                                  : AppColors.border.withValues(alpha: 0.72);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  child: InkWell(
                                    onTap: locked
                                        ? () => _showLockedRestartModal()
                                        : _selectedIndex == null
                                        ? () {
                                            setState(() {
                                              _selectedIndex = index;
                                            });
                                            _saveAnswer(_currentIndex, index);
                                            if (_autoAdvanceEnabled &&
                                                _currentIndex <
                                                    questions.length - 1) {
                                              _advanceToNextQuestion();
                                            }
                                          }
                                        : null,
                                    borderRadius: BorderRadius.circular(18),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 15,
                                      ),
                                      decoration: BoxDecoration(
                                        color: backgroundColor,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: showResult && isCorrect
                                                  ? const Color(0xFF21A65B)
                                                  : showResult && selected
                                                  ? const Color(0xFFD64545)
                                                  : const Color(0xFFE9EDF6),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              showResult && isCorrect
                                                  ? Icons.check_rounded
                                                  : showResult && selected
                                                  ? Icons.close_rounded
                                                  : Icons.circle_outlined,
                                              size: 16,
                                              color:
                                                  showResult &&
                                                      (isCorrect || selected)
                                                  ? Colors.white
                                                  : AppColors.textSoft,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              question.options[index],
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                height: 1.3,
                                                fontWeight: FontWeight.w600,
                                                color: showResult && isCorrect
                                                    ? const Color(0xFF178343)
                                                    : showResult && selected
                                                    ? const Color(0xFFD64545)
                                                    : AppColors.text,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    QuestionExplanationFooter(
                      questionText: question.text,
                      correctAnswer:
                          question.correctIndex >= 0 &&
                              question.correctIndex < question.options.length
                          ? question.options[question.correctIndex]
                          : question.options.isNotEmpty
                          ? question.options.first
                          : '',
                      explanation: question.explanation,
                      audioUrl: question.audio,
                      onFinish: locked
                          ? () => _showLockedRestartModal()
                          : () => _finishNow(questions),
                      onRestart: _restartCurrentTest,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _questionImageUrl(TopicQuestion question) {
    final image = question.image.trim();
    if (image.isEmpty) return 'assets/default.png';
    if (image.startsWith('http://') || image.startsWith('https://')) {
      return image;
    }
    if (image.startsWith('/')) {
      return '$apiBaseUrl$image';
    }
    return 'assets/default.png';
  }

  Widget _buildQuestionImage(TopicQuestion question) {
    final imageUrl = _questionImageUrl(question);
    if (imageUrl == 'assets/default.png') {
      return Image.asset(
        imageUrl,
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
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/default.png',
          width: double.infinity,
          fit: BoxFit.fitWidth,
          alignment: Alignment.center,
        );
      },
    );
  }

  int? _answerFor(int index) {
    if (index < 0 || index >= _answers.length) return null;
    return _answers[index];
  }

  void _saveAnswer(int questionIndex, int answerIndex) {
    while (_answers.length <= questionIndex) {
      _answers.add(null);
    }
    _answers[questionIndex] = answerIndex;
  }

  void _goToNextQuestion() {
    final questions = _loadedQuestions;
    if (questions == null || _currentIndex >= questions.length - 1) return;
    setState(() {
      _currentIndex += 1;
      _selectedIndex = _answerFor(_currentIndex);
    });
    _scrollCurrentQuestionIntoView();
  }

  void _goToPreviousQuestion() {
    if (_currentIndex <= 0) return;
    setState(() {
      _currentIndex -= 1;
      _selectedIndex = _answerFor(_currentIndex);
    });
    _scrollCurrentQuestionIntoView();
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

  void _restartCurrentTest() {
    setState(() {
      _answers.clear();
      _currentIndex = 0;
      _selectedIndex = null;
      _resultShown = false;
      _loadedQuestions = null;
      _questionsFuture = _loadQuestions();
    });
  }

  Future<void> _showLockedRestartModal() {
    return showTestLockedRestartSheet(
      context: context,
      title: 'Test tugadi',
      message: 'Bu test yakunlangan. Davom etish uchun uni qayta boshlang.',
      onRestart: () async => _restartCurrentTest(),
      restartLabel: 'Qayta boshlash',
    );
  }

  void _advanceToNextQuestion() {
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      _goToNextQuestion();
    });
  }

  Future<void> _finishNow(List<TopicQuestion> questions) async {
    if (_selectedIndex != null) {
      _saveAnswer(_currentIndex, _selectedIndex!);
    }

    final correct = _countCorrect(questions, _answers);
    final total = questions.length;
    final wrong = total - correct;
    final percent = total == 0 ? 0 : ((correct / total) * 100).round();
    if (!_resultShown && mounted) {
      _resultShown = true;
      await _showResultModal(
        correct: correct,
        wrong: wrong,
        total: total,
        percent: percent,
      );
    }
  }

  int _countCorrect(List<TopicQuestion> questions, List<int?> answers) {
    var correct = 0;
    for (var index = 0; index < questions.length; index++) {
      final answer = index < answers.length ? answers[index] : null;
      if (answer != null && answer == questions[index].correctIndex) {
        correct += 1;
      }
    }
    return correct;
  }

  Future<void> _showResultModal({
    required int correct,
    required int wrong,
    required int total,
    required int percent,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
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
                  'Natija',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 12),
                _ResultRow(label: 'To‘g‘ri javoblar', value: '$correct'),
                const SizedBox(height: 10),
                _ResultRow(label: 'Noto‘g‘ri javoblar', value: '$wrong'),
                const SizedBox(height: 10),
                _ResultRow(label: 'Jami savollar', value: '$total'),
                const SizedBox(height: 10),
                _ResultRow(label: 'Foiz', value: '$percent%'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Yopish'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openImagePreview(String imageUrl) {
    final isAsset = imageUrl == 'assets/default.png';
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Preview',
      barrierColor: Colors.black.withValues(alpha: 0.84),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: isAsset
                        ? Image.asset(imageUrl, fit: BoxFit.contain)
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  height: 34,
                                  width: 34,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.6,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset(
                                  'assets/default.png',
                                  fit: BoxFit.contain,
                                ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(fade),
            child: child,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _QuestionNavigator extends StatelessWidget {
  const _QuestionNavigator({
    required this.total,
    required this.currentIndex,
    required this.answeredStates,
    required this.correctAnswers,
    required this.onTap,
  });

  final int total;
  final int currentIndex;
  final List<int?> answeredStates;
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
          final answered =
              index < answeredStates.length && answeredStates[index] != null;
          final isCurrent = index == currentIndex;
          final isCorrect =
              answered && answeredStates[index] == correctAnswers[index];
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
        color: const Color(0xFFF7F8FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: const TextStyle(
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

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 46,
          height: 46,
          child: Icon(Icons.settings_outlined, size: 22),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

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
                color: const Color(0xFFFFECEB),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: AppColors.danger,
                size: 34,
              ),
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
