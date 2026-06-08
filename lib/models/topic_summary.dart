class TopicSummary {
  TopicSummary({
    required this.id,
    required this.title,
    required this.completed,
  });

  final String id;
  final String title;
  final bool completed;

  factory TopicSummary.fromJson(Map<String, dynamic> json) {
    return TopicSummary(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      completed: json['completed'] == true,
    );
  }
}
