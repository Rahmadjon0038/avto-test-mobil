class MistakeQuestion {
  MistakeQuestion({
    required this.id,
    required this.kind,
    required this.sourceId,
    required this.sourceTitle,
    required this.questionIndex,
    required this.text,
    required this.image,
    required this.options,
    required this.correctIndex,
    required this.correctAnswer,
    required this.explanation,
    required this.hasImage,
    required this.wrongAnswer,
  });

  final String id;
  final String kind;
  final String sourceId;
  final String sourceTitle;
  final int questionIndex;
  final String text;
  final String image;
  final List<String> options;
  final int correctIndex;
  final String correctAnswer;
  final String explanation;
  final bool hasImage;
  final int? wrongAnswer;

  factory MistakeQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final options = rawOptions is List
        ? rawOptions.map((option) => option.toString()).toList()
        : const <String>[];
    return MistakeQuestion(
      id: (json['id'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      sourceId: (json['sourceId'] ?? '').toString(),
      sourceTitle: (json['sourceTitle'] ?? '').toString(),
      questionIndex: int.tryParse(json['questionIndex']?.toString() ?? '') ?? 0,
      text: (json['text'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      options: options,
      correctIndex: int.tryParse(json['correctIndex']?.toString() ?? '') ?? 0,
      correctAnswer: (json['correctAnswer'] ?? '').toString(),
      explanation: (json['explanation'] ?? '').toString(),
      hasImage: json['hasImage'] == true,
      wrongAnswer: json['wrongAnswer'] == null
          ? null
          : int.tryParse(json['wrongAnswer'].toString()),
    );
  }
}
