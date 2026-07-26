import 'topic_progress_summary.dart';

class TopicSummary {
  TopicSummary({
    required this.id,
    required this.title,
    required this.completed,
    required this.questionCount,
    required this.progress,
  });

  final String id;
  final String title;
  final bool completed;
  final int questionCount;
  final TopicProgressSummary? progress;

  factory TopicSummary.fromJson(Map<String, dynamic> json) {
    final rawProgress = json['progress'];
    return TopicSummary(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      completed: json['completed'] == true,
      questionCount: int.tryParse(json['questionCount']?.toString() ?? '') ?? 0,
      progress: rawProgress is Map
          ? TopicProgressSummary.fromJson(
              Map<String, dynamic>.from(rawProgress),
            )
          : null,
    );
  }
}
