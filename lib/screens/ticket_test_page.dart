import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/media_urls.dart';
import '../models/auth_session.dart';
import '../models/ticket_summary.dart';
import '../models/topic_question.dart';
import '../l10n/app_strings.dart';
import '../services/api_client.dart';
import '../services/offline_cache_store.dart';
import '../services/question_page_settings_store.dart';
import '../services/ticket_test_progress_store.dart';
import '../utils/friendly_error_message.dart';
import '../widgets/question_explanation_footer.dart';
import '../widgets/question_swipe_detector.dart';

class TicketTestPage extends StatefulWidget {
  const TicketTestPage({
    super.key,
    required this.session,
    required this.ticket,
    this.onSessionUpdated,
  });

  final AuthSession session;
  final TicketSummary ticket;
  final ValueChanged<AuthSession>? onSessionUpdated;

  @override
  State<TicketTestPage> createState() => _TicketTestPageState();
}

class _TicketTestPageState extends State<TicketTestPage> {
  late Future<List<TopicQuestion>> _questionsFuture;
  final List<int?> _answers = <int?>[];
  TicketTestDraft? _savedDraft;
  int? _shuffleSeed;
  int _currentIndex = 0;
  int? _selectedIndex;
  bool _resultShown = false;
  bool _shuffleQuestions = false;
  bool _autoAdvanceEnabled = true;
  List<TopicQuestion>? _loadedQuestions;
  List<int> _currentOptionOrder = <int>[];
  final Map<String, String> _audioOverrides = {};
  late String _accessToken;
  String? _languageCode;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _questionCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _accessToken = widget.session.accessToken;
    _languageCode = AppLanguageStore.currentCode;
    _questionsFuture = _loadQuestions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLanguage = AppLanguageScope.of(context).languageCode;
    if (_languageCode == currentLanguage) return;
    _languageCode = currentLanguage;
    setState(() {
      _questionsFuture = _loadQuestions();
      _answers.clear();
      _savedDraft = null;
      _shuffleSeed = null;
      _currentIndex = 0;
      _selectedIndex = null;
      _resultShown = false;
      _loadedQuestions = null;
      _currentOptionOrder = <int>[];
    });
  }

  Future<List<TopicQuestion>> _loadQuestions() async {
    final settings = await QuestionPageSettingsStore.load();
    if (!mounted) return const <TopicQuestion>[];
    _shuffleQuestions = settings.shuffleQuestions;
    _autoAdvanceEnabled = settings.autoAdvance;
    final savedProgress = await TicketTestProgressStore.load(widget.ticket.id);
    if (!mounted) return const <TopicQuestion>[];
    _savedDraft = null;
    _shuffleSeed = _shuffleQuestions
        ? savedProgress?.draft?.shuffleSeed ??
              DateTime.now().microsecondsSinceEpoch
        : null;
    _resultShown = false;
    if (savedProgress?.draft != null) {
      await TicketTestProgressStore.clearDraft(widget.ticket.id);
    }

    try {
      final questions = await ApiClient.ticketQuestions(
        accessToken: _accessToken,
        ticketId: widget.ticket.id,
      );
      unawaited(
        OfflineCacheStore.prefetchAudioUrls(
          audioUrls: questions.map((question) => question.audio),
        ),
      );
      final result = _prepareQuestions(questions, _savedDraft);
      _restoreQuestionState(result, _savedDraft);
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

      final questions = await ApiClient.ticketQuestions(
        accessToken: active.accessToken,
        ticketId: widget.ticket.id,
      );
      unawaited(
        OfflineCacheStore.prefetchAudioUrls(
          audioUrls: questions.map((question) => question.audio),
        ),
      );
      final result = _prepareQuestions(questions, _savedDraft);
      _restoreQuestionState(result, _savedDraft);
      return result;
    }
  }

  String _audioUrlForQuestion(TopicQuestion question) {
    return _audioOverrides[question.id] ?? question.audio;
  }

  void _updateQuestionAudio(String questionId, String? audioUrl) {
    if (!mounted) return;
    setState(() {
      final value = audioUrl?.trim() ?? '';
      if (value.isEmpty) {
        _audioOverrides.remove(questionId);
      } else {
        _audioOverrides[questionId] = value;
      }
    });
  }

  List<TopicQuestion> _prepareQuestions(
    List<TopicQuestion> questions,
    TicketTestDraft? draft,
  ) {
    final result = List<TopicQuestion>.from(questions);
    final orderIds = draft?.questionOrderIds;
    if (orderIds != null &&
        orderIds.length == result.length &&
        orderIds.isNotEmpty) {
      final byId = <String, TopicQuestion>{
        for (final question in result) question.id.trim(): question,
      };
      final ordered = <TopicQuestion>[];
      var matches = true;
      for (final id in orderIds) {
        final question = byId[id.trim()];
        if (question == null) {
          matches = false;
          break;
        }
        ordered.add(question);
      }
      if (matches && ordered.length == result.length) {
        result
          ..clear()
          ..addAll(ordered);
      }
    } else if (_shuffleQuestions) {
      final seed = _shuffleSeed ?? DateTime.now().microsecondsSinceEpoch;
      result.shuffle(math.Random(seed));
    }

    return result;
  }

  void _restoreQuestionState(
    List<TopicQuestion> questions,
    TicketTestDraft? draft,
  ) {
    final answers = List<int?>.filled(questions.length, null);
    if (draft != null) {
      for (var index = 0; index < questions.length; index++) {
        final questionId = questions[index].id.trim();
        final answer = draft.answersByQuestionId[questionId];
        if (answer != null) {
          answers[index] = answer;
        }
      }
    }

    setState(() {
      _loadedQuestions = questions;
      _answers
        ..clear()
        ..addAll(answers);
      final maxIndex = questions.isEmpty ? 0 : questions.length - 1;
      _currentIndex = draft == null
          ? 0
          : draft.currentIndex.clamp(0, maxIndex).toInt();
      _selectedIndex = _answerFor(_currentIndex);
      _resultShown = draft?.completed ?? false;
    });
    _refreshCurrentOptionOrder(forceNew: false);
  }

  List<int> _buildCurrentOptionOrder(TopicQuestion question, {required bool forceNew}) {
    final order = List<int>.generate(question.options.length, (index) => index);
    if (!_shuffleQuestions || order.length < 2) {
      return order;
    }

    final baseSeed = _shuffleSeed ?? DateTime.now().microsecondsSinceEpoch;
    final visitSeed = forceNew ? DateTime.now().microsecondsSinceEpoch : (_currentIndex + 1);
    order.shuffle(math.Random(baseSeed ^ _stableHash(question.id.trim()) ^ visitSeed));
    return order;
  }

  void _refreshCurrentOptionOrder({required bool forceNew}) {
    final questions = _loadedQuestions;
    if (!mounted || questions == null || questions.isEmpty) return;
    if (_currentIndex < 0 || _currentIndex >= questions.length) return;

    final question = questions[_currentIndex];
    final nextOrder = _buildCurrentOptionOrder(question, forceNew: forceNew);
    final canonicalAnswer = _answerFor(_currentIndex);
    final nextSelectedIndex = canonicalAnswer == null ? null : nextOrder.indexOf(canonicalAnswer);

    setState(() {
      _currentOptionOrder = nextOrder;
      _selectedIndex = nextSelectedIndex != null && nextSelectedIndex >= 0 ? nextSelectedIndex : null;
    });
  }

  int? _canonicalAnswerForDisplayIndex(int displayIndex) {
    if (displayIndex < 0 || displayIndex >= _currentOptionOrder.length) return null;
    return _currentOptionOrder[displayIndex];
  }

  int? _displayIndexForCanonicalAnswer(int canonicalIndex) {
    if (canonicalIndex < 0 || canonicalIndex >= _currentOptionOrder.length) return null;
    final displayIndex = _currentOptionOrder.indexOf(canonicalIndex);
    return displayIndex < 0 ? null : displayIndex;
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
                    title: 'Bu biletda testlar mavjud emas',
                    subtitle:
                        'Hozircha ushbu bilet uchun savollar qo‘shilmagan.',
                    buttonText: 'Ortga qaytish',
                    onPressed: () => Navigator.of(context).pop(),
                  );
                }

                final questions = snapshot.data ?? const <TopicQuestion>[];
                if (questions.isEmpty) {
                  return _EmptyState(
                    title: 'Bu biletda testlar mavjud emas',
                    subtitle:
                        'Hozircha ushbu bilet uchun savollar qo‘shilmagan.',
                    buttonText: 'Ortga qaytish',
                    onPressed: () => Navigator.of(context).pop(),
                  );
                }

                _loadedQuestions = questions;
                final question = questions[_currentIndex];
                final optionOrder = _currentOptionOrder.length == question.options.length
                    ? _currentOptionOrder
                    : List<int>.generate(question.options.length, (index) => index);
                final locked = _resultShown;
                return Column(
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
                                widget.ticket.title,
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
                                '${_currentIndex + 1}/${questions.length} savol',
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
                                _persistDraft();
                                _scrollCurrentQuestionIntoView();
                              },
                            ),
                            const SizedBox(height: 14),
                            Container(
                              key: _questionCardKey,
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
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
                              final isCorrect = index == _displayIndexForCanonicalAnswer(question.correctIndex);
                              final showResult = _selectedIndex != null;
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
                                  ? AppColors.primary.withValues(alpha: 0.28)
                                  : AppColors.border.withValues(alpha: 0.72);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Material(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  child: InkWell(
                                    onTap: locked
                                        ? () => _showLockedRestartModal()
                                        : _answerFor(_currentIndex) != null
                                        ? null
                                        : () {
                                            final canonicalIndex = _canonicalAnswerForDisplayIndex(index);
                                            if (canonicalIndex == null) return;
                                            setState(() {
                                              _selectedIndex = index;
                                            });
                                            _saveAnswer(_currentIndex, canonicalIndex);
                                            final questions = _loadedQuestions;
                                            if (_autoAdvanceEnabled &&
                                                questions != null &&
                                                _currentIndex <
                                                    questions.length - 1) {
                                              _advanceToNextQuestion();
                                            }
                                          },
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
                                                  : AppColors.surfaceSoft,
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
                                              question.options[optionOrder[index]],
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
                      audioUrl: _audioUrlForQuestion(question),
                      audioAdminContext: widget.session.isAdmin
                          ? QuestionAudioAdminContext(
                              accessToken: _accessToken,
                              sourceKind: 'ticket',
                              sourceId: widget.ticket.id.toString(),
                              questionId: question.id,
                            )
                          : null,
                      onAudioChanged: (updatedUrl) {
                        _updateQuestionAudio(question.id, updatedUrl);
                      },
                      onFinish: locked
                          ? () => _showLockedRestartModal()
                          : () => _finishNow(questions),
                      onRestart: _restartTest,
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
    return resolveQuestionImageUrl(question.image);
  }

  Widget _buildQuestionImage(TopicQuestion question) {
    final imageUrl = _questionImageUrl(question);
    const imageHeight = 220.0;
    if (imageUrl == 'assets/default.png') {
      return SizedBox(
        width: double.infinity,
        height: imageHeight,
        child: Image.asset(
          imageUrl,
          width: double.infinity,
          height: imageHeight,
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: imageHeight,
      child: Image.network(
        imageUrl,
        width: double.infinity,
        height: imageHeight,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: double.infinity,
            height: imageHeight,
            color: AppColors.surfaceSoft,
            alignment: Alignment.center,
            child: SizedBox(
              height: 28,
              width: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.primary,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/default.png',
            width: double.infinity,
            height: imageHeight,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          );
        },
      ),
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
    _persistDraft();
    final questions = _loadedQuestions;
    if (questions != null) {
      _syncProgress(questions, silent: true);
    }
  }

  Future<void> _persistDraft({bool completed = false}) async {
    final questions = _loadedQuestions;
    if (questions == null || questions.isEmpty) return;

    final payload = <String, int>{};
    for (var index = 0; index < questions.length; index++) {
      if (index >= _answers.length) continue;
      final answer = _answers[index];
      final questionId = questions[index].id.trim();
      if (answer != null && questionId.isNotEmpty) {
        payload[questionId] = answer;
      }
    }

    await TicketTestProgressStore.saveDraft(
      ticketId: widget.ticket.id,
      draft: TicketTestDraft(
        questionOrderIds: questions.map((item) => item.id.trim()).toList(),
        answersByQuestionId: payload,
        currentIndex: _currentIndex,
        completed: completed,
        shuffleSeed: _shuffleQuestions ? _shuffleSeed : null,
      ),
    );
  }

  void _goToNextQuestion() {
    final questions = _loadedQuestions;
    if (questions == null || _currentIndex >= questions.length - 1) return;
    setState(() {
      _currentIndex += 1;
    });
    _refreshCurrentOptionOrder(forceNew: true);
    _persistDraft();
    _scrollCurrentQuestionIntoView();
  }

  void _goToPreviousQuestion() {
    if (_currentIndex <= 0) return;
    setState(() {
      _currentIndex -= 1;
    });
    _refreshCurrentOptionOrder(forceNew: true);
    _persistDraft();
    _scrollCurrentQuestionIntoView();
  }

  Future<void> _restartTest() async {
    await TicketTestProgressStore.clearDraft(widget.ticket.id);
    setState(() {
      _currentIndex = 0;
      _selectedIndex = null;
      _answers.clear();
      _resultShown = false;
      _loadedQuestions = null;
      _savedDraft = null;
      _currentOptionOrder = <int>[];
      _questionsFuture = _loadQuestions();
    });
  }

  Future<void> _showLockedRestartModal() {
    return showTestLockedRestartSheet(
      context: context,
      title: 'Test tugadi',
      message: 'Bu test yakunlangan. Davom etish uchun uni qayta boshlang.',
      onRestart: () async => _restartTest(),
      restartLabel: 'Qayta boshlash',
    );
  }

  void _advanceToNextQuestion() {
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      _goToNextQuestion();
    });
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

  Future<void> _finishNow(List<TopicQuestion> questions) async {
    if (_selectedIndex != null) {
      _saveAnswer(_currentIndex, _selectedIndex!);
    }

    final correct = _countCorrect(questions, _answers);
    final total = questions.length;
    final answered = _countAnswered(questions, _answers);
    final wrong = answered - correct;
    final unanswered = total - answered;
    final percent = total == 0 ? 0 : ((correct / total) * 100).round();
    await _syncProgress(questions);
    final draft = TicketTestDraft(
      questionOrderIds: questions.map((item) => item.id.trim()).toList(),
      answersByQuestionId: _answersByQuestionId(questions),
      currentIndex: _currentIndex,
      completed: true,
      shuffleSeed: _shuffleQuestions ? _shuffleSeed : null,
    );
    await TicketTestProgressStore.saveResult(
      ticketId: widget.ticket.id,
      draft: draft,
      result: TicketTestResult(
        correct: correct,
        wrong: wrong,
        total: total,
        unanswered: unanswered,
        percent: percent,
        updatedAt: DateTime.now(),
      ),
    );
    if (!_resultShown && mounted) {
      _resultShown = true;
      await _showResultModal(
        correct: correct,
        wrong: wrong,
        total: total,
        unanswered: unanswered,
        percent: percent,
      );
    }
  }

  int _stableHash(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = 0x1fffffff & (hash + codeUnit);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= (hash >> 6);
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= (hash >> 11);
    hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
    return hash;
  }

  Map<String, int> _answersByQuestionId(List<TopicQuestion> questions) {
    final payload = <String, int>{};
    for (var index = 0; index < questions.length; index++) {
      if (index >= _answers.length) continue;
      final answer = _answers[index];
      final questionId = questions[index].id.trim();
      if (answer != null && questionId.isNotEmpty) {
        payload[questionId] = answer;
      }
    }
    return payload;
  }

  Future<void> _syncProgress(
    List<TopicQuestion> questions, {
    bool silent = false,
  }) async {
    final payload = _answersByQuestionId(questions);
    if (payload.isEmpty) return;
    try {
      await ApiClient.saveTicketProgress(
        accessToken: _accessToken,
        ticketId: widget.ticket.id,
        answers: payload,
      );
    } on ApiException catch (error) {
      final refreshToken = widget.session.refreshToken;
      if (error.statusCode != 401 ||
          refreshToken == null ||
          refreshToken.isEmpty) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            SnackBar(
              content: Text(
                friendlyErrorMessage(
                  context,
                  error.message,
                  fallbackKey: 'load_failed',
                ),
              ),
            ),
          );
        }
        return;
      }
      final refreshed = await ApiClient.refresh(refreshToken);
      if (!mounted) return;
      final active = refreshed.copyWith(user: widget.session.user);
      setState(() {
        _accessToken = active.accessToken;
      });
      widget.onSessionUpdated?.call(active);
      await ApiClient.saveTicketProgress(
        accessToken: active.accessToken,
        ticketId: widget.ticket.id,
        answers: payload,
      );
    } catch (error) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              friendlyErrorMessage(
                context,
                error,
                fallbackKey: 'load_failed',
              ),
            ),
          ),
        );
      }
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

  int _countAnswered(List<TopicQuestion> questions, List<int?> answers) {
    var answered = 0;
    for (var index = 0; index < questions.length; index++) {
      final answer = index < answers.length ? answers[index] : null;
      if (answer != null) {
        answered += 1;
      }
    }
    return answered;
  }

  Future<void> _showResultModal({
    required int correct,
    required int wrong,
    required int total,
    required int unanswered,
    required int percent,
  }) {
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
                  'Natija',
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
                    ResultPieChart(
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
                            label: 'To‘g‘ri javoblar',
                            value: '$correct',
                          ),
                          const SizedBox(height: 10),
                          _ResultRow(
                            label: 'Noto‘g‘ri javoblar',
                            value: '$wrong',
                          ),
                          const SizedBox(height: 10),
                          _ResultRow(label: 'Jami savollar', value: '$total'),
                          const SizedBox(height: 10),
                          _ResultRow(
                            label: 'Belgilanmagan',
                            value: '$unanswered',
                          ),
                          const SizedBox(height: 10),
                          _ResultRow(label: 'Foiz', value: '$percent%'),
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
                    onPressed: () {
                      Navigator.of(modalContext).pop();
                      if (pageContext.mounted) {
                        Navigator.of(pageContext).pop(true);
                      }
                    },
                    child: Text('Yopish'),
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

class ResultPieChart extends StatelessWidget {
  const ResultPieChart({
    super.key,
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
                  'progress',
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

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(Icons.settings_outlined, size: 22, color: AppColors.text),
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
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.menu_book_rounded,
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
                child: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
