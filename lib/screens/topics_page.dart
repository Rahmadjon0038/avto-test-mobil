import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_colors.dart';
import '../models/auth_session.dart';
import '../models/topic_summary.dart';
import '../services/api_client.dart';
import 'topic_test_page.dart';

class TopicsPage extends StatefulWidget {
  const TopicsPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<TopicsPage> createState() => _TopicsPageState();
}

class _TopicsPageState extends State<TopicsPage> {
  late Future<List<TopicSummary>> _topicsFuture;
  late Set<String> _markedTopicIds;
  bool _marksLoaded = false;

  @override
  void initState() {
    super.initState();
    _topicsFuture = ApiClient.topics(widget.session.accessToken);
    _markedTopicIds = <String>{};
    _loadMarkedTopics();
  }

  Future<void> _loadMarkedTopics() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_markedTopicsStorageKey) ?? <String>[];
    if (!mounted) return;
    setState(() {
      _markedTopicIds = saved.toSet();
      _marksLoaded = true;
    });
  }

  Future<void> _toggleMarkedTopic(String topicId) async {
    final nextMarked = Set<String>.from(_markedTopicIds);
    if (nextMarked.contains(topicId)) {
      nextMarked.remove(topicId);
    } else {
      nextMarked.add(topicId);
    }

    setState(() {
      _markedTopicIds = nextMarked;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_markedTopicsStorageKey, nextMarked.toList());
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
                        message: snapshot.error.toString(),
                          onRetry: () {
                            setState(() {
                              _topicsFuture = ApiClient.topics(
                                widget.session.accessToken,
                              );
                            });
                          },
                      );
                    }

                    final topics = snapshot.data ?? const <TopicSummary>[];
                    if (!_marksLoaded) {
                      return const _TopicsLoader();
                    }
                    if (topics.isEmpty) {
                      return const _TopicsEmpty();
                    }

                    return ListView.separated(
                      itemCount: topics.length,
                      physics: const BouncingScrollPhysics(),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final topic = topics[index];
                        final marked =
                            topic.completed || _markedTopicIds.contains(topic.id);
                        return _TopicCard(
                          topic: topic,
                          marked: marked,
                          onMarkToggle: () => _toggleMarkedTopic(topic.id),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TopicTestPage(
                                  session: widget.session,
                                  topic: topic,
                                ),
                              ),
                            );
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
        const Text(
          'Mavzular',
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
    required this.marked,
    required this.onMarkToggle,
    required this.onTap,
  });

  final TopicSummary topic;
  final bool marked;
  final VoidCallback onMarkToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: marked ? const Color(0xFFEAF7EF) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: marked
                  ? const Color(0xFFB7E6C8)
                  : AppColors.border.withValues(alpha: 0.75),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: marked
                      ? const Color(0xFFE8FBF2)
                      : const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  marked
                      ? Icons.check_circle_rounded
                      : Icons.description_rounded,
                  color: marked
                      ? const Color(0xFF20B26B)
                      : const Color(0xFF4C8DFF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onMarkToggle,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  marked
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: marked
                      ? const Color(0xFF20B26B)
                      : const Color(0xFFB5B8C0),
                  size: 24,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFB5B8C0),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const String _markedTopicsStorageKey = 'road_test_marked_topics';

class _TopicsLoader extends StatelessWidget {
  const _TopicsLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

class _TopicsEmpty extends StatelessWidget {
  const _TopicsEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Mavzular topilmadi',
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Qayta urinish'),
            ),
          ],
        ),
      ),
    );
  }
}
