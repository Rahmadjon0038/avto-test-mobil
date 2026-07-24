class TopicSummary {
  TopicSummary({
    required this.id,
    required this.title,
    required this.completed,
    required this.questionCount,
  });

  final String id;
  final String title;
  final bool completed;
  final int questionCount;

  factory TopicSummary.fromJson(Map<String, dynamic> json) {
    return TopicSummary(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      completed: json['completed'] == true,
      questionCount: int.tryParse(json['questionCount']?.toString() ?? '') ?? 0,
    );
  }
}
