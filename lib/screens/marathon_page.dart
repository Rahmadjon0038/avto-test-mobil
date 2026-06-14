import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_constants.dart';
import '../models/answer_question.dart';
import '../models/auth_session.dart';
import '../services/api_client.dart';
import '../services/question_page_settings_store.dart';
import '../widgets/question_explanation_footer.dart';
import '../widgets/question_swipe_detector.dart';

class MarathonPage extends StatefulWidget {
  const MarathonPage({super.key, required this.session, this.onSessionUpdated});

  final AuthSession session;
  final ValueChanged<AuthSession>? onSessionUpdated;

  @override
  State<MarathonPage> createState() => _MarathonPageState();
}

class _MarathonPageState extends State<MarathonPage> {
  late String _accessToken;
  final List<AnswerQuestion> _bank = <AnswerQuestion>[];
  final List<AnswerQuestion> _visibleQuestions = <AnswerQuestion>[];
  final Map<String, int> _answers = <String, int>{};
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _questionCardKey = GlobalKey();

  int _currentIndex = 0;
  int _nextBankIndex = 3;
  bool _hasMoreBank = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _sessionExpired = false;
  bool _resultShown = false;
  bool _shuffleQuestions = false;
  bool _autoAdvanceEnabled = true;
  Timer? _advanceTimer;

  @override
  void initState() {
    super.initState();
    _accessToken = widget.session.accessToken;
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _advanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final settings = await QuestionPageSettingsStore.load();
    if (!mounted) return;
    _shuffleQuestions = settings.shuffleQuestions;
    _autoAdvanceEnabled = settings.autoAdvance;

    setState(() {
      _isLoading = true;
      _resultShown = false;
      _answers.clear();
      _bank.clear();
      _visibleQuestions.clear();
      _currentIndex = 0;
      _nextBankIndex = 3;
      _hasMoreBank = true;
      _sessionExpired = false;
    });

    try {
      final body = await ApiClient.answers(
        accessToken: _accessToken,
        offset: 0,
        limit: 20,
      );
      final fetched = _parseQuestions(body);
      if (_shuffleQuestions) {
        fetched.shuffle();
      }
      if (!mounted) return;
      setState(() {
        _bank.addAll(fetched);
        _hasMoreBank = body['hasMore'] == true;
        _visibleQuestions.addAll(fetched.take(3));
        _nextBankIndex = _visibleQuestions.length;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (error.statusCode == 401 &&
          widget.session.refreshToken != null &&
          widget.session.refreshToken!.isNotEmpty) {
        try {
          final refreshed = await ApiClient.refresh(
            widget.session.refreshToken!,
          );
          if (!mounted) return;
          final active = refreshed.copyWith(user: widget.session.user);
          setState(() {
            _accessToken = active.accessToken;
          });
          widget.onSessionUpdated?.call(active);
          await _loadInitial();
          return;
        } on ApiException catch (_) {
          if (!mounted) return;
          setState(() {
            _sessionExpired = true;
            _isLoading = false;
          });
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      rethrow;
    }
  }

  Future<List<AnswerQuestion>> _loadMoreBank() async {
    if (_isLoadingMore || !_hasMoreBank || _sessionExpired) {
      return const <AnswerQuestion>[];
    }
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final body = await ApiClient.answers(
        accessToken: _accessToken,
        offset: _bank.length,
        limit: 20,
      );
      final fetched = _parseQuestions(body);
      if (_shuffleQuestions) {
        fetched.shuffle();
      }
      if (!mounted) return const <AnswerQuestion>[];
      setState(() {
        _bank.addAll(fetched);
        _hasMoreBank = body['hasMore'] == true;
      });
      return fetched;
    } on ApiException catch (error) {
      if (error.statusCode == 401 &&
          widget.session.refreshToken != null &&
          widget.session.refreshToken!.isNotEmpty) {
        try {
          final refreshed = await ApiClient.refresh(
            widget.session.refreshToken!,
          );
          if (!mounted) return const <AnswerQuestion>[];
          final active = refreshed.copyWith(user: widget.session.user);
          setState(() {
            _accessToken = active.accessToken;
          });
          widget.onSessionUpdated?.call(active);
          return _loadMoreBank();
        } on ApiException catch (_) {
          if (!mounted) return const <AnswerQuestion>[];
          setState(() {
            _sessionExpired = true;
          });
          return const <AnswerQuestion>[];
        }
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  List<AnswerQuestion> _parseQuestions(Map<String, dynamic> body) {
    final rawItems = body['questions'];
    return rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) =>
                    AnswerQuestion.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <AnswerQuestion>[];
  }

  AnswerQuestion? get _currentQuestion =>
      _currentIndex >= 0 && _currentIndex < _visibleQuestions.length
      ? _visibleQuestions[_currentIndex]
      : null;

  void _saveAnswer(int questionIndex, int answerIndex) {
    if (questionIndex < 0 || questionIndex >= _visibleQuestions.length) return;
    _answers[_visibleQuestions[questionIndex].id] = answerIndex;
  }

  int _countCorrect() {
    var correct = 0;
    for (final question in _visibleQuestions) {
      final selected = _answers[question.id];
      if (selected != null && selected == question.correctIndex) {
        correct += 1;
      }
    }
    return correct;
  }

  void _scheduleAdvance(int nextIndex) {
    _advanceTimer?.cancel();
    _advanceTimer = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() {
        if (nextIndex - 1 == _currentIndex) {
          _currentIndex = nextIndex;
        }
      });
      _scrollCurrentQuestionIntoView();
    });
  }

  Future<void> _answerCurrent(int optionIndex) async {
    final question = _currentQuestion;
    if (question == null) return;
    if (_answers.containsKey(question.id)) return;

    setState(() {
      _answers[question.id] = optionIndex;
    });

    final isCorrect = optionIndex == question.correctIndex;
    if (!isCorrect) {
      if (_autoAdvanceEnabled && _currentIndex < _visibleQuestions.length - 1) {
        _scheduleAdvance(_currentIndex + 1);
      }
      return;
    }

    if (_nextBankIndex >= _bank.length && _hasMoreBank) {
      await _loadMoreBank();
    }

    if (_nextBankIndex < _bank.length) {
      final nextQuestion = _bank[_nextBankIndex];
      setState(() {
        _visibleQuestions.add(nextQuestion);
        _nextBankIndex += 1;
      });
      if (_autoAdvanceEnabled) {
        _scheduleAdvance(_currentIndex + 1);
      }
      return;
    }

    if (_autoAdvanceEnabled && _currentIndex < _visibleQuestions.length - 1) {
      _scheduleAdvance(_currentIndex + 1);
    }
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

  Future<void> _showFinishModal() async {
    if (_resultShown) return;
    final correct = _countCorrect();
    final total = _visibleQuestions.length;
    final wrong = total - correct;
    final percent = total == 0 ? 0 : ((correct / total) * 100).round();
    _resultShown = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String _questionImageUrl(AnswerQuestion question) {
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

  Widget _buildQuestionImage(AnswerQuestion question) {
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
    final question = _currentQuestion;

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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _visibleQuestions.isEmpty || question == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Marafon rejimi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hozircha savollar topilmadi.',
                          style: TextStyle(
                            color: AppColors.text.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : Column(
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
                                const Text(
                                  'Marafon rejimi',
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
                                  '${_currentIndex + 1}/${_visibleQuestions.length} savol',
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
                      if (_sessionExpired)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Sessiya tugadi',
                                  style: TextStyle(
                                    color: AppColors.text,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Qayta kirish kerak.',
                                  style: TextStyle(
                                    color: AppColors.text.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 40,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: _visibleQuestions.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(width: 6),
                                    itemBuilder: (context, index) {
                                      final answered = _answers.containsKey(
                                        _visibleQuestions[index].id,
                                      );
                                      final isCurrent = index == _currentIndex;
                                      final isCorrect =
                                          answered &&
                                          _answers[_visibleQuestions[index]
                                                  .id] ==
                                              _visibleQuestions[index]
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
                                          onTap: _resultShown
                                              ? () => _showLockedRestartModal()
                                              : () {
                                                  setState(() {
                                                    _currentIndex = index;
                                                  });
                                                  _scrollCurrentQuestionIntoView();
                                                },
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Container(
                                            width: 34,
                                            height: 34,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: backgroundColor,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: borderColor,
                                                width: 1,
                                              ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          child: _buildQuestionImage(question),
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
                                      ? AppColors.primary.withValues(
                                          alpha: 0.28,
                                        )
                                      : AppColors.border.withValues(
                                          alpha: 0.72,
                                        );

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Material(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      child: InkWell(
                                        onTap: _resultShown
                                            ? () => _showLockedRestartModal()
                                            : _answers.containsKey(question.id)
                                            ? null
                                            : () {
                                                _answerCurrent(index);
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
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
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
                                                          (isCorrect ||
                                                              selected)
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
                                                    color:
                                                        showResult && isCorrect
                                                        ? const Color(
                                                            0xFF178343,
                                                          )
                                                        : showResult && selected
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
                                const SizedBox(height: 8),
                                QuestionExplanationFooter(
                                  questionText: question.text,
                                  correctAnswer: question.correctAnswer,
                                  explanation: question.explanation,
                                  audioUrl: question.audio,
                                  onFinish: _resultShown
                                      ? () => _showLockedRestartModal()
                                      : () async {
                                          if (_answers.containsKey(
                                            question.id,
                                          )) {
                                            _saveAnswer(
                                              _currentIndex,
                                              _answers[question.id]!,
                                            );
                                          }
                                          await _showFinishModal();
                                        },
                                  onRestart: _loadInitial,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  void _goToNextQuestion() {
    if (_currentIndex >= _visibleQuestions.length - 1) return;
    setState(() {
      _currentIndex += 1;
    });
    _scrollCurrentQuestionIntoView();
  }

  void _goToPreviousQuestion() {
    if (_currentIndex <= 0) return;
    setState(() {
      _currentIndex -= 1;
    });
    _scrollCurrentQuestionIntoView();
  }

  Future<void> _showLockedRestartModal() {
    return showTestLockedRestartSheet(
      context: context,
      title: 'Test tugadi',
      message: 'Bu test yakunlangan. Davom etish uchun uni qayta boshlang.',
      onRestart: () async => _loadInitial(),
      restartLabel: 'Qayta boshlash',
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
