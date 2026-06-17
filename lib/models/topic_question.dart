class TopicQuestion {
  TopicQuestion({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.image,
    required this.audio,
  });

  final String id;
  final String text;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String image;
  final String audio;

  factory TopicQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    return TopicQuestion(
      id: (json['id'] ?? json['questionKey'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      options: rawOptions is List
          ? rawOptions.map((option) => option.toString()).toList()
          : const <String>[],
      correctIndex: int.tryParse(json['correctIndex']?.toString() ?? '') ?? 0,
      explanation: (json['explanation'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      audio: (json['audio'] ?? '').toString(),
    );
  }
}
