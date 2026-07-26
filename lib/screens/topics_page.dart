import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/auth_session.dart';
import '../models/topic_progress_summary.dart';
import '../models/topic_summary.dart';
import '../l10n/app_strings.dart';
import '../services/api_client.dart';
import '../utils/friendly_error_message.dart';
import 'topic_test_page.dart';

class TopicsPage extends StatefulWidget {
  const TopicsPage({super.key, required this.session, this.onSessionUpdated});

  final AuthSession session;
  final ValueChanged<AuthSession>? onSessionUpdated;

  @override
  State<TopicsPage> createState() => _TopicsPageState();
}

class _TopicsPageState extends State<TopicsPage> {
  late Future<List<TopicSummary>> _topicsFuture;
  late AuthSession _activeSession;
  late String _accessToken;
  String? _languageCode;
  final ScrollController _scrollController = ScrollController();
  final Map<String, TopicProgressSummary> _progressByTopicId = {};
  bool _progressHydrationQueued = false;

  @override
  void initState() {
    super.initState();
    _activeSession = widget.session;
    _accessToken = _activeSession.accessToken;
    _languageCode = AppLanguageStore.currentCode;
    _topicsFuture = _loadTopics();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLanguage = AppLanguageScope.of(context).languageCode;
    if (_languageCode == currentLanguage) return;
    _languageCode = currentLanguage;
    setState(() {
      _topicsFuture = _loadTopics();
      _progressByTopicId.clear();
      _progressHydrationQueued = false;
    });
  }

  Future<List<TopicSummary>> _loadTopics() async {
    try {
      return await ApiClient.topics(_accessToken);
    } on ApiException catch (error) {
      final refreshToken = _activeSession.refreshToken;
      if (error.statusCode != 401 ||
          refreshToken == null ||
          refreshToken.isEmpty) {
        rethrow;
      }

      final refreshed = await ApiClient.refresh(refreshToken);
      if (!mounted) return const <TopicSummary>[];
      final active = refreshed.copyWith(user: _activeSession.user);
      setState(() {
        _activeSession = active;
        _accessToken = active.accessToken;
      });
      widget.onSessionUpdated?.call(active);
      return await ApiClient.topics(active.accessToken);
    }
  }

  Future<void> _hydrateProgress(List<TopicSummary> topics) async {
    if (_progressHydrationQueued) return;
    _progressHydrationQueued = true;

    final results = await Future.wait(
      topics.map((topic) async {
        try {
          final progress = await _loadTopicProgress(topic.id);
          return MapEntry<String, TopicProgressSummary?>(topic.id, progress);
        } catch (_) {
          return MapEntry<String, TopicProgressSummary?>(topic.id, null);
        }
      }),
    );

    if (!mounted) return;
    setState(() {
      for (final entry in results) {
        if (entry.value != null) {
          _progressByTopicId[entry.key] = entry.value!;
        }
      }
    });
  }

  Future<TopicProgressSummary?> _loadTopicProgress(String topicId) async {
    try {
      return await ApiClient.topicProgress(
        accessToken: _accessToken,
        topicId: topicId,
      );
    } on ApiException catch (error) {
      final refreshToken = _activeSession.refreshToken;
      if (error.statusCode != 401 ||
          refreshToken == null ||
          refreshToken.isEmpty) {
        rethrow;
      }

      final refreshed = await ApiClient.refresh(refreshToken);
      if (!mounted) return null;
      final active = refreshed.copyWith(user: _activeSession.user);
      setState(() {
        _activeSession = active;
        _accessToken = active.accessToken;
      });
      widget.onSessionUpdated?.call(active);
      return await ApiClient.topicProgress(
        accessToken: active.accessToken,
        topicId: topicId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TopicsHeader(onBack: () => Navigator.of(context).pop()),
              const SizedBox(height: 18),
              Expanded(
                child: FutureBuilder<List<TopicSummary>>(
                  future: _topicsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _TopicsLoader();
                    }
                    if (snapshot.hasError) {
                      return _TopicsError(
                        message: friendlyErrorMessage(context, snapshot.error),
                        onRetry: () {
                          setState(() {
                            _topicsFuture = _loadTopics();
                          });
                        },
                      );
                    }

                    final topics = snapshot.data ?? const <TopicSummary>[];
                    if (topics.isEmpty) {
                      return const _TopicsEmpty();
                    }

                    if (!_progressHydrationQueued) {
                      _progressHydrationQueued = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _hydrateProgress(topics);
                        }
                      });
                    }

                    return ListView.separated(
                      key: const PageStorageKey<String>('topics-list'),
                      controller: _scrollController,
                      itemCount: topics.length,
                      physics: const BouncingScrollPhysics(),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final topic = topics[index];
                        return _TopicCard(
                          topic: topic,
                          totalCount: topic.questionCount,
                          progress:
                              topic.progress ?? _progressByTopicId[topic.id],
                          marked: topic.completed,
                          onTap: () async {
                            final shouldRefresh = await Navigator.of(context)
                                .push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => TopicTestPage(
                                      session: _activeSession,
                                      topic: topic,
                                      onSessionUpdated: widget.onSessionUpdated,
                                    ),
                                  ),
                                );
                            if (shouldRefresh != false && mounted) {
                              setState(() {
                                _topicsFuture = _loadTopics();
                                _progressByTopicId.clear();
                                _progressHydrationQueued = false;
                              });
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicsHeader extends StatelessWidget {
  const _TopicsHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final isDark = AppColors.isDarkMode;
    return Row(
      children: [
        Material(
          color: isDark ? AppColors.surfaceSoft : AppColors.surface,
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
        Text(
          strings.t('topics'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.topic,
    required this.totalCount,
    required this.progress,
    required this.marked,
    required this.onTap,
  });

  final TopicSummary topic;
  final int totalCount;
  final TopicProgressSummary? progress;
  final bool marked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final isDark = AppColors.isDarkMode;
    final cardColor = marked ? AppColors.surfaceSoft : AppColors.surface;
    final iconBackground = marked
        ? AppColors.surfaceTint
        : (isDark ? const Color(0xFF1A2740) : const Color(0xFFEAF1FF));
    final iconColor = marked
        ? (isDark ? const Color(0xFF7EE2A8) : const Color(0xFF20B26B))
        : AppColors.primary;
    final cardShadow = isDark
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 18,
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
    final answeredCount = progress?.answers.length ?? 0;
    final correctCount = progress?.score ?? 0;
    final wrongCount = math.max(0, answeredCount - correctCount);
    final unansweredCount = math.max(0, totalCount - answeredCount);
    final hasProgress = totalCount > 0;
    final progressValue = hasProgress
        ? (correctCount / totalCount).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: marked
                  ? (isDark ? const Color(0xFF172A25) : const Color(0xFFEAF7EF))
                  : cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: marked
                    ? (isDark
                          ? const Color(0xFF2F6E4C)
                          : const Color(0xFFB7E6C8))
                    : AppColors.border.withValues(alpha: isDark ? 0.95 : 0.75),
              ),
              boxShadow: cardShadow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    marked
                        ? Icons.check_circle_rounded
                        : Icons.description_rounded,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              topic.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                      if (hasProgress) ...[
                        const SizedBox(height: 8),
                        Text(
                          '$correctCount ${strings.t('correct_short')} · $wrongCount ${strings.t('wrong_short')} · $unansweredCount ${strings.t('unanswered_short')}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progressValue,
                            minHeight: 4,
                            backgroundColor: AppColors.surfaceTint,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF4D4F),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSoft,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopicsLoader extends StatelessWidget {
  const _TopicsLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _TopicsEmpty extends StatelessWidget {
  const _TopicsEmpty();

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Center(
      child: Text(
        strings.t('no_content'),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _TopicsError extends StatelessWidget {
  const _TopicsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: Text(strings.t('retry_load')),
            ),
          ],
        ),
      ),
    );
  }
}
