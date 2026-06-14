import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/app_colors.dart';
import '../models/auth_session.dart';
import '../models/topic_summary.dart';
import '../models/video_lesson.dart';
import '../services/api_client.dart';
import 'topic_test_page.dart';

class VideosPage extends StatefulWidget {
  const VideosPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage> {
  late Future<List<VideoLesson>> _videosFuture;

  @override
  void initState() {
    super.initState();
    _videosFuture = ApiClient.videos(widget.session.accessToken);
  }

  String _buildWatchUrl(String youtubeId) {
    return 'https://www.youtube.com/watch?v=$youtubeId&rel=0&playsinline=1';
  }

  Future<void> _openVideo(VideoLesson video) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _VideoPlayerPage(
          session: widget.session,
          topicId: video.topicId.toString(),
          title: video.topicTitle,
          watchUrl: _buildWatchUrl(video.youtubeId),
        ),
      ),
    );
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
              _VideosHeader(onBack: () => Navigator.of(context).pop()),
              const SizedBox(height: 18),
              Expanded(
                child: FutureBuilder<List<VideoLesson>>(
                  future: _videosFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _VideosError(
                        message: snapshot.error.toString(),
                        onRetry: () {
                          setState(() {
                            _videosFuture = ApiClient.videos(
                              widget.session.accessToken,
                            );
                          });
                        },
                      );
                    }

                    final videos = snapshot.data ?? const <VideoLesson>[];
                    if (videos.isEmpty) {
                      return const _VideosEmpty();
                    }

                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: videos.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final video = videos[index];
                        return _VideoCard(
                          video: video,
                          onOpenVideo: () => _openVideo(video),
                          onOpenTopic: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TopicTestPage(
                                  session: widget.session,
                                  topic: TopicSummary(
                                    id: video.topicId,
                                    title: video.topicTitle,
                                    completed: false,
                                  ),
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

class _VideosHeader extends StatelessWidget {
  const _VideosHeader({required this.onBack});

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
        const Expanded(
          child: Text(
            'Video darsliklar',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.video,
    required this.onOpenVideo,
    required this.onOpenTopic,
  });

  final VideoLesson video;
  final VoidCallback onOpenVideo;
  final VoidCallback onOpenTopic;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpenVideo,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.75)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (video.thumbnailUrl.isNotEmpty)
                        Image.network(
                          video.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFFEAF1FF),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.play_circle_fill_rounded,
                                color: Color(0xFF4C8DFF),
                                size: 64,
                              ),
                            );
                          },
                        )
                      else
                        Container(
                          color: const Color(0xFFEAF1FF),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.play_circle_fill_rounded,
                            color: Color(0xFF4C8DFF),
                            size: 64,
                          ),
                        ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x11000000), Color(0x55000000)],
                          ),
                        ),
                      ),
                      const Center(
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Color(0xFF4C8DFF),
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: onOpenTopic,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          video.topicTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onOpenTopic,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF0B74FF),
                  ),
                  child: const Text(
                    'Mavzuga doir testlarni ishlash',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoPlayerPage extends StatefulWidget {
  const _VideoPlayerPage({
    required this.session,
    required this.topicId,
    required this.title,
    required this.watchUrl,
  });

  final AuthSession session;
  final String topicId;
  final String title;
  final String watchUrl;

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
  late final WebViewController _controller;
  bool _fullscreen = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadRequest(Uri.parse(widget.watchUrl));
  }

  Future<void> _setFullscreen(bool value) async {
    if (!mounted) return;
    setState(() => _fullscreen = value);
    await SystemChrome.setEnabledSystemUIMode(
      value ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = ClipRRect(
      borderRadius: BorderRadius.circular(_fullscreen ? 0 : 18),
      child: WebViewWidget(controller: _controller),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: !_fullscreen,
        bottom: !_fullscreen,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(_fullscreen ? 0 : 16),
                child: Column(
                  children: [
                    if (!_fullscreen)
                      Row(
                        children: [
                          Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: () {
                                if (_fullscreen) {
                                  _setFullscreen(false);
                                } else {
                                  Navigator.of(context).pop();
                                }
                              },
                              customBorder: const CircleBorder(),
                              child: const SizedBox(
                                width: 46,
                                height: 46,
                                child: Icon(Icons.arrow_back_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _setFullscreen(!_fullscreen),
                            icon: Icon(
                              _fullscreen
                                  ? Icons.fullscreen_exit_rounded
                                  : Icons.fullscreen_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    if (!_fullscreen) const SizedBox(height: 14),
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: player,
                        ),
                      ),
                    ),
                    if (!_fullscreen) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TopicTestPage(
                                  session: widget.session,
                                  topic: TopicSummary(
                                    id: widget.topicId,
                                    title: widget.title,
                                    completed: false,
                                  ),
                                ),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            foregroundColor: const Color(0xFF6EA0FF),
                          ),
                          child: const Text(
                            'Mavzuga doir testlarni ishlash',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_fullscreen)
              Positioned(
                top: 8,
                left: 8,
                child: SafeArea(
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => _setFullscreen(false),
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(Icons.fullscreen_exit_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideosError extends StatelessWidget {
  const _VideosError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger),
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

class _VideosEmpty extends StatelessWidget {
  const _VideosEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Hozircha video darslar yo‘q',
        style: TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}
