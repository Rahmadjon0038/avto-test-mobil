class VideoLesson {
  VideoLesson({
    required this.id,
    required this.topicId,
    required this.topicTitle,
    required this.title,
    required this.description,
    required this.category,
    required this.premiumOnly,
    required this.bunnyVideoId,
    required this.bunnyLibraryId,
    required this.videoStatus,
    required this.videoDuration,
    required this.videoThumbnail,
    required this.playbackUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String topicId;
  final String topicTitle;
  final String title;
  final String description;
  final String category;
  final bool premiumOnly;
  final String bunnyVideoId;
  final String bunnyLibraryId;
  final String videoStatus;
  final int videoDuration;
  final String videoThumbnail;
  final String playbackUrl;
  final String? createdAt;
  final String? updatedAt;

  factory VideoLesson.fromJson(Map<String, dynamic> json) {
    return VideoLesson(
      id: (json['id'] ?? '').toString(),
      topicId: (json['topicId'] ?? '').toString(),
      topicTitle: (json['topicTitle'] ?? '').toString(),
      title: (json['title'] ?? json['topicTitle'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      premiumOnly:
          json['premiumOnly'] == true ||
          json['premiumOnly'] == 1 ||
          json['premiumOnly']?.toString() == '1',
      bunnyVideoId: (json['bunnyVideoId'] ?? '').toString(),
      bunnyLibraryId: (json['bunnyLibraryId'] ?? '').toString(),
      videoStatus: (json['videoStatus'] ?? 'processing').toString(),
      videoDuration: int.tryParse((json['videoDuration'] ?? 0).toString()) ?? 0,
      videoThumbnail: (json['videoThumbnail'] ?? json['thumbnailUrl'] ?? '')
          .toString(),
      playbackUrl: (json['playbackUrl'] ?? '').toString(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }
}
