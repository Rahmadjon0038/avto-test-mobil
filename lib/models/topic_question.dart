class TopicQuestion {
  TopicQuestion({
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.image,
  });

  final String text;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String image;

  factory TopicQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    return TopicQuestion(
      text: (json['text'] ?? '').toString(),
      options: rawOptions is List
          ? rawOptions.map((option) => option.toString()).toList()
          : const <String>[],
      correctIndex: int.tryParse(json['correctIndex']?.toString() ?? '') ?? 0,
      explanation: (json['explanation'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
    );
  }
}
