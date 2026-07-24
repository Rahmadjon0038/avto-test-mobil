import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/media_urls.dart';
import '../models/auth_session.dart';
import '../models/exam_question.dart';
import '../l10n/app_strings.dart';
import '../services/api_client.dart';
import '../services/offline_cache_store.dart';
import '../widgets/question_explanation_footer.dart';
import '../widgets/question_result_modal.dart';
import '../widgets/question_swipe_detector.dart';

class ExamPage extends StatefulWidget {
  const ExamPage({super.key, required this.session, this.onSessionUpdated});

  final AuthSession session;
  final ValueChanged<AuthSession>? onSessionUpdated;

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  late String _accessToken;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _questionCardKey = GlobalKey();
  final Map<String, int> _answers = <String, int>{};
  final List<ExamQuestion> _questions = <ExamQuestion>[];

  Timer? _timer;
  Timer? _autoNextTimer;

  int _currentIndex = 0;
  int _secondsLeft = 0;
  int _score = 0;
  bool _isLoading = true;
  bool _sessionExpired = false;
  bool _completed = false;
  bool _expired = false;
  bool _submitting = false;
  String? _loadError;
  DateTime? _expiresAt;
  String? _languageCode;

  ExamQuestion? get _currentQuestion =>
      _currentIndex >= 0 && _currentIndex < _questions.length
      ? _questions[_currentIndex]
      : null;

  bool get _locked => _completed || _expired || _sessionExpired;

  @override
  void initState() {
    super.initState();
    _accessToken = widget.session.accessToken;
    _languageCode = AppLanguageStore.currentCode;
    _bootstrapExam();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLanguage = AppLanguageScope.of(context).languageCode;
    if (_languageCode == currentLanguage) return;
    _languageCode = currentLanguage;
    _timer?.cancel();
    _autoNextTimer?.cancel();
    _bootstrapExam();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoNextTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapExam() async {
    setState(() {
      _isLoading = true;
      _sessionExpired = false;
      _completed = false;
      _expired = false;
      _loadError = null;
      _answers.clear();
      _questions.clear();
      _currentIndex = 0;
      _secondsLeft = 0;
      _score = 0;
      _expiresAt = null;
    });

    try {
      await ApiClient.examReset(_accessToken);
      final exam = await ApiClient.startExam(
        accessToken: _accessToken,
        count: 20,
      );
      if (!mounted) return;
      _applyExam(exam);
    } on ApiException catch (error) {
      if (error.statusCode == 401 &&
          widget.session.refreshToken != null &&
          widget.session.refreshToken!.isNotEmpty) {
        final refreshed = await _refreshAccessToken();
        if (!refreshed || !mounted) return;
        await _bootstrapExam();
        return;
      }
      if (!mounted) return;
      setState(() {
        _loadError = error.message;
        _isLoading = false;
      });
    }
  }

  Future<bool> _refreshAccessToken() async {
    final refreshToken = widget.session.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      if (!mounted) return false;
      setState(() {
        _sessionExpired = true;
        _isLoading = false;
      });
      return false;
    }

    try {
      final refreshed = await ApiClient.refresh(refreshToken);
      if (!mounted) return false;
      final active = refreshed.copyWith(user: widget.session.user);
      setState(() {
        _accessToken = active.accessToken;
      });
      widget.onSessionUpdated?.call(active);
      return true;
    } on ApiException {
      if (!mounted) return false;
      setState(() {
        _sessionExpired = true;
        _isLoading = false;
      });
      return false;
    }
  }

  void _applyExam(Map<String, dynamic> exam) {
    final rawQuestions = exam['questions'];
    final questions = rawQuestions is List
        ? rawQuestions
              .whereType<Map>()
              .map(
                (item) =>
                    ExamQuestion.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <ExamQuestion>[];

    unawaited(
      OfflineCacheStore.prefetchAudioUrls(
        audioUrls: questions.map((question) => question.audio),
      ),
    );

    final rawAnswers = exam['answers'];
    final answers = <String, int>{};
    if (rawAnswers is Map) {
      for (final entry in rawAnswers.entries) {
        final value = int.tryParse(entry.value?.toString() ?? '');
        if (value != null) {
          answers[entry.key.toString()] = value;
        }
      }
    }

    _timer?.cancel();
    _questions
      ..clear()
      ..addAll(questions);
    _answers
      ..clear()
      ..addAll(answers);
    _currentIndex = 0;
    _completed = exam['completed'] == true;
    _expired = exam['expired'] == true;
    _score = int.tryParse(exam['score']?.toString() ?? '') ?? 0;
    _secondsLeft =
        int.tryParse(exam['remainingSeconds']?.toString() ?? '') ?? 0;
    _expiresAt = exam['expiresAt'] == null
        ? null
        : DateTime.tryParse(exam['expiresAt'].toString());

    setState(() {
      _isLoading = false;
    });

    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_expiresAt == null || _locked) return;

    void tick() {
      final remaining = _expiresAt == null
          ? 0
          : (_expiresAt!.difference(DateTime.now()).inSeconds > 0
                ? _expiresAt!.difference(DateTime.now()).inSeconds
                : 0);
      if (!mounted) return;
      setState(() {
        _secondsLeft = remaining;
        _expired = remaining == 0 && !_completed;
      });
      if (remaining == 0 && !_completed && !_sessionExpired && !_submitting) {
        _finishExam();
      }
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<Map<String, dynamic>?> _submitProgress({
    required bool finalize,
  }) async {
    if (_sessionExpired) return null;
    _submitting = true;
    try {
      return await ApiClient.examProgress(
        accessToken: _accessToken,
        answers: _answers,
        finalize: finalize,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 401 &&
          widget.session.refreshToken != null &&
          widget.session.refreshToken!.isNotEmpty) {
        final refreshed = await _refreshAccessToken();
        if (!refreshed) return null;
        try {
          return await ApiClient.examProgress(
            accessToken: _accessToken,
            answers: _answers,
            finalize: finalize,
          );
        } on ApiException catch (retryError) {
          if (!mounted) return null;
          setState(() {
            _loadError = retryError.message;
            _sessionExpired = retryError.statusCode == 401;
          });
          return null;
        }
      }

      if (!mounted) return null;
      setState(() {
        _loadError = error.message;
      });
      return null;
    } finally {
      _submitting = false;
    }
  }

  void _saveAnswer(int questionIndex, int answerIndex) {
    if (questionIndex < 0 || questionIndex >= _questions.length) return;
    final question = _questions[questionIndex];
    if (_answers.containsKey(question.id) || _locked) return;

    setState(() {
      _answers[question.id] = answerIndex;
    });

    _submitProgress(finalize: false);

    if (_currentIndex < _questions.length - 1) {
      _scheduleAutoNext(_currentIndex + 1);
    }
  }

  void _scheduleAutoNext(int nextIndex) {
    _autoNextTimer?.cancel();
    _autoNextTimer = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted || _locked) return;
      if (_currentIndex != nextIndex - 1) return;
      setState(() {
        _currentIndex = nextIndex;
      });
      _scrollCurrentQuestionIntoView();
    });
  }

  void _goToNextQuestion() {
    if (_locked || _currentIndex >= _questions.length - 1) return;
    _autoNextTimer?.cancel();
    setState(() {
      _currentIndex += 1;
    });
    _scrollCurrentQuestionIntoView();
  }

  void _goToPreviousQuestion() {
    if (_locked || _currentIndex <= 0) return;
    _autoNextTimer?.cancel();
    setState(() {
      _currentIndex -= 1;
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

  int _countCorrect() {
    var correct = 0;
    for (final question in _questions) {
      final selected = _answers[question.id];
      if (selected != null && selected == question.correctIndex) {
        correct += 1;
      }
    }
    return correct;
  }

  Future<void> _finishExam() async {
    if (_locked) return;
    _timer?.cancel();
    _autoNextTimer?.cancel();
    final response = await _submitProgress(finalize: true);
    if (!mounted || response == null) return;

    final total =
        int.tryParse(response['total']?.toString() ?? '') ?? _questions.length;
    final serverScore =
        int.tryParse(response['score']?.toString() ?? '') ?? _countCorrect();
    final correct = serverScore;
    final answered = _answers.length > total ? total : _answers.length;
    final unanswered = total > answered ? total - answered : 0;
    final wrong = answered > correct ? answered - correct : 0;
    final percent = total > 0 ? ((correct / total) * 100).round() : 0;

    setState(() {
      _completed =
          response['completed'] == true || response['finalize'] == true;
      _expired = response['expired'] == true;
      _score = correct;
    });

    await showQuestionResultModal(
      context: context,
      correct: correct,
      wrong: wrong,
      total: total,
      unanswered: unanswered,
      percent: percent,
      onClose: () async {},
      popPageOnClose: true,
    );
  }

  Future<void> _showLockedRestartModal() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return MediaQuery.removePadding(
          context: sheetContext,
          removeBottom: true,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
            decoration: BoxDecoration(
              color: AppColors.surface,
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
                Text(
                  AppStrings.of(context).t('exam_finished_sheet_title'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppStrings.of(context).t('exam_finished_sheet_subtitle'),
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await _restartExam();
                    },
                    child: Text(AppStrings.of(context).t('exam_restart_button')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _restartExam() async {
    if (_submitting) return;
    try {
      await ApiClient.examReset(_accessToken);
      if (!mounted) return;
      await _bootstrapExam();
    } on ApiException catch (error) {
      if (error.statusCode == 401 &&
          widget.session.refreshToken != null &&
          widget.session.refreshToken!.isNotEmpty) {
        final refreshed = await _refreshAccessToken();
        if (!refreshed) return;
        await _restartExam();
        return;
      }
      if (!mounted) return;
      setState(() {
        _loadError = error.message;
      });
    }
  }

  String _questionImageUrl(ExamQuestion question) {
    return resolveQuestionImageUrl(question.image);
  }

  Widget _buildQuestionImage(ExamQuestion question) {
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
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final question = _currentQuestion;
    final locked = _locked;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: QuestionSwipeDetector(
          onSwipeLeft: locked
              ? () => _showLockedRestartModal()
              : _goToNextQuestion,
          onSwipeRight: locked
              ? () => _showLockedRestartModal()
              : _goToPreviousQuestion,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _sessionExpired
                ? _CenteredMessage(
                    title: strings.t('session_ended_title'),
                    subtitle: strings.t('session_ended_subtitle'),
                    actionText: strings.t('exam_session_ended_action'),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : _loadError != null && _questions.isEmpty
                ? _CenteredMessage(
                    title: strings.t('not_loaded_title'),
                    subtitle: _loadError!,
                    actionText: strings.t('exam_load_failed_action'),
                    onPressed: _bootstrapExam,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Material(
                            color: AppColors.surface,
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
                                  strings.t('exam_title'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_currentIndex + 1}/${_questions.length} ${strings.t('question_suffix')}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          _TimerChip(secondsLeft: _secondsLeft),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (_completed || _expired)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSoft,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.7),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _completed
                                          ? strings.t('exam_finished')
                                          : strings.t('session_ended'),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${strings.t('result_correct')}: $_score/${_questions.length}',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 40,
                                child: FilledButton.tonal(
                                  onPressed: _restartExam,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFDCE9FF),
                                    foregroundColor: const Color(0xFF0A4DB5),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  ),
                                  child: Text(strings.t('exam_new_test')),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_completed || _expired) const SizedBox(height: 14),
                      Expanded(
                        child: question == null
                            ? const SizedBox.shrink()
                            : SingleChildScrollView(
                                controller: _scrollController,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 18),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        height: 42,
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          physics:
                                              const BouncingScrollPhysics(),
                                          itemCount: _questions.length,
                                          separatorBuilder: (context, index) =>
                                              const SizedBox(width: 6),
                                          itemBuilder: (context, index) {
                                            final answered = _answers
                                                .containsKey(
                                                  _questions[index].id,
                                                );
                                            final isCurrent =
                                                index == _currentIndex;
                                            final isCorrect =
                                                answered &&
                                                _answers[_questions[index]
                                                        .id] ==
                                                    _questions[index]
                                                        .correctIndex;
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
                                                : AppColors.border.withValues(
                                                    alpha: 0.85,
                                                  );

                                            return Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: locked
                                                    ? () =>
                                                          _showLockedRestartModal()
                                                    : () {
                                                        setState(() {
                                                          _currentIndex = index;
                                                        });
                                                        _scrollCurrentQuestionIntoView();
                                                      },
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Container(
                                                  width: 34,
                                                  height: 34,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    color: backgroundColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: borderColor,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    '${index + 1}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color:
                                                          isCurrent || answered
                                                          ? Colors.white
                                                          : AppColors.text,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Container(
                                        key: _questionCardKey,
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(18),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              question.text,
                                              style: TextStyle(
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
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                child: _buildQuestionImage(
                                                  question,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      ...List.generate(question.options.length, (
                                        index,
                                      ) {
                                        final selected =
                                            _answers[question.id] == index;
                                        final isCorrect =
                                            index == question.correctIndex;
                                        final showResult = _answers.containsKey(
                                          question.id,
                                        );
                                        final backgroundColor = showResult
                                            ? isCorrect
                                                  ? const Color(0xFFCFF0D9)
                                                  : selected
                                                  ? const Color(0xFFF4C5C5)
                                                  : AppColors.surface
                                            : selected
                                            ? AppColors.surfaceTint
                                            : AppColors.surface;
                                        final borderColor = showResult
                                            ? isCorrect
                                                  ? const Color(0xFF6CBF86)
                                                  : selected
                                                  ? const Color(0xFFDD6B6B)
                                                  : AppColors.border.withValues(
                                                      alpha: 0.72,
                                                    )
                                            : selected
                                            ? AppColors.primary.withValues(
                                                alpha: 0.28,
                                              )
                                            : AppColors.border.withValues(
                                                alpha: 0.72,
                                              );

                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: Material(
                                            color: AppColors.surface,
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            child: InkWell(
                                              onTap: locked
                                                  ? () =>
                                                        _showLockedRestartModal()
                                                  : _submitting
                                                  ? null
                                                  : () => _saveAnswer(
                                                      _currentIndex,
                                                      index,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 180,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 15,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: backgroundColor,
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                  border: Border.all(
                                                    color: borderColor,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 28,
                                                      height: 28,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            showResult &&
                                                                isCorrect
                                                            ? const Color(
                                                                0xFF21A65B,
                                                              )
                                                            : showResult &&
                                                                  selected
                                                            ? const Color(
                                                                0xFFD64545,
                                                              )
                                                            : AppColors
                                                                  .surfaceSoft,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        showResult && isCorrect
                                                            ? Icons
                                                                  .check_rounded
                                                            : showResult &&
                                                                  selected
                                                            ? Icons
                                                                  .close_rounded
                                                            : Icons
                                                                  .circle_outlined,
                                                        size: 16,
                                                        color:
                                                            showResult &&
                                                                (isCorrect ||
                                                                    selected)
                                                            ? Colors.white
                                                            : AppColors
                                                                  .textSoft,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        question.options[index],
                                                        style: TextStyle(
                                                          fontSize: 13.5,
                                                          height: 1.3,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              showResult &&
                                                                  isCorrect
                                                              ? const Color(
                                                                  0xFF178343,
                                                                )
                                                              : showResult &&
                                                                    selected
                                                              ? const Color(
                                                                  0xFFD64545,
                                                                )
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
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final currentQuestion = question!;
                          return QuestionExplanationFooter(
                            questionText: currentQuestion.text,
                            correctAnswer: currentQuestion.correctAnswer,
                            explanation: currentQuestion.explanation,
                            audioUrl: currentQuestion.audio,
                            showExplanationActions: false,
                            onFinish: locked
                                ? () => _showLockedRestartModal()
                                : _finishExam,
                            onRestart: _restartExam,
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({required this.secondsLeft});

  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    final minutes = (secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (secondsLeft % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Text(
        '$minutes:$seconds',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.title,
    required this.subtitle,
    required this.actionText,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String actionText;
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
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.flag_rounded,
                color: AppColors.danger,
                size: 34,
              ),
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
                child: Text(actionText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
