class TopicProgressSummary {
  TopicProgressSummary({
    required this.answers,
    required this.completed,
    required this.score,
    required this.updatedAt,
  });

  final Map<String, int> answers;
  final bool completed;
  final int score;
  final DateTime? updatedAt;

  factory TopicProgressSummary.fromJson(Map<String, dynamic> json) {
    final rawAnswers = json['answers'];
    final answers = <String, int>{};
    if (rawAnswers is Map) {
      for (final entry in rawAnswers.entries) {
        final value = int.tryParse(entry.value?.toString() ?? '');
        if (value != null) {
          answers[entry.key.toString()] = value;
        }
      }
    }

    return TopicProgressSummary(
      answers: answers,
      completed: json['completed'] == true,
      score: int.tryParse(json['score']?.toString() ?? '') ?? 0,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'].toString()),
    );
  }
}
