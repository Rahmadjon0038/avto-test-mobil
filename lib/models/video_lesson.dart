class VideoLesson {
  VideoLesson({
    required this.id,
    required this.topicId,
    required this.topicTitle,
    required this.youtubeUrl,
    required this.youtubeId,
    required this.thumbnailUrl,
  });

  final String id;
  final String topicId;
  final String topicTitle;
  final String youtubeUrl;
  final String youtubeId;
  final String thumbnailUrl;

  factory VideoLesson.fromJson(Map<String, dynamic> json) {
    return VideoLesson(
      id: (json['id'] ?? '').toString(),
      topicId: (json['topicId'] ?? '').toString(),
      topicTitle: (json['topicTitle'] ?? '').toString(),
      youtubeUrl: (json['youtubeUrl'] ?? '').toString(),
      youtubeId: (json['youtubeId'] ?? '').toString(),
      thumbnailUrl: (json['thumbnailUrl'] ?? '').toString(),
    );
  }
}
