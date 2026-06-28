import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/app_colors.dart';
import '../models/auth_session.dart';
import '../models/topic_summary.dart';
import '../models/video_lesson.dart';
import '../services/api_client.dart';
import 'topic_test_page.dart';

const Map<String, String> _videoRequestHeaders = <String, String>{
  'Referer': 'https://topshirdi.uz/',
  'Origin': 'https://topshirdi.uz',
  'User-Agent': 'Topshirdi/1.0 (Flutter)',
};

class VideosPage extends StatefulWidget {
  const VideosPage({super.key, required this.session, this.onSessionUpdated});

  final AuthSession session;
  final ValueChanged<AuthSession>? onSessionUpdated;

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage> {
  late Future<List<VideoLesson>> _videosFuture;
  late AuthSession _activeSession;
  late String _accessToken;
  VideoLesson? _activeVideo;
  String _playbackUrl = "";
  bool _loadingPlayback = false;
  String _playbackError = "";

  @override
  void initState() {
    super.initState();
    _activeSession = widget.session;
    _accessToken = _activeSession.accessToken;
    _videosFuture = _loadVideos();
  }

  Future<List<VideoLesson>> _loadVideos() async {
    try {
      return await ApiClient.videos(_accessToken);
    } on ApiException catch (error) {
      final refreshToken = _activeSession.refreshToken;
      if (error.statusCode != 401 ||
          refreshToken == null ||
          refreshToken.isEmpty) {
        rethrow;
      }

      final refreshed = await ApiClient.refresh(refreshToken);
      if (!mounted) return const <VideoLesson>[];
      final active = refreshed.copyWith(user: _activeSession.user);
      setState(() {
        _activeSession = active;
        _accessToken = active.accessToken;
      });
      widget.onSessionUpdated?.call(active);
      return ApiClient.videos(active.accessToken);
    }
  }

  void _openTopic(VideoLesson video) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TopicTestPage(
          session: _activeSession,
          topic: TopicSummary(
            id: video.topicId,
            title: video.topicTitle,
            completed: false,
          ),
          onSessionUpdated: widget.onSessionUpdated,
        ),
      ),
    );
  }

  Future<void> _openVideo(VideoLesson video) async {
    setState(() {
      _activeVideo = video;
      _playbackUrl = "";
      _playbackError = "";
      _loadingPlayback = true;
    });

    try {
      final url = await ApiClient.videoPlaybackUrl(
        accessToken: _accessToken,
        videoId: video.id,
      );
      if (!mounted) return;
      setState(() {
        _playbackUrl = url;
        _loadingPlayback = false;
      });
    } on ApiException catch (error) {
      if (error.statusCode == 401 &&
          _activeSession.refreshToken != null &&
          _activeSession.refreshToken!.isNotEmpty) {
        try {
          final refreshed = await ApiClient.refresh(
            _activeSession.refreshToken!,
          );
          if (!mounted) return;
          final active = refreshed.copyWith(user: _activeSession.user);
          setState(() {
            _activeSession = active;
            _accessToken = active.accessToken;
          });
          widget.onSessionUpdated?.call(active);
          final url = await ApiClient.videoPlaybackUrl(
            accessToken: active.accessToken,
            videoId: video.id,
          );
          if (!mounted) return;
          setState(() {
            _playbackUrl = url;
            _loadingPlayback = false;
          });
          return;
        } on ApiException catch (refreshError) {
          if (!mounted) return;
          setState(() {
            _playbackError = refreshError.message;
            _loadingPlayback = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(refreshError.message)));
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _playbackError = error.message;
        _loadingPlayback = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _playbackError = error.toString();
        _loadingPlayback = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
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
                            _videosFuture = _loadVideos();
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
                        final active = _activeVideo?.id == video.id;
                        return _VideoCard(
                          video: video,
                          isActive: active,
                          playbackUrl: active ? _playbackUrl : "",
                          loadingPlayback: active ? _loadingPlayback : false,
                          playbackError: active ? _playbackError : "",
                          onOpenVideo: () => _openVideo(video),
                          onOpenTopic: () => _openTopic(video),
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

class _VideoCard extends StatefulWidget {
  const _VideoCard({
    required this.video,
    required this.isActive,
    required this.playbackUrl,
    required this.loadingPlayback,
    required this.playbackError,
    required this.onOpenVideo,
    required this.onOpenTopic,
  });

  final VideoLesson video;
  final bool isActive;
  final String playbackUrl;
  final bool loadingPlayback;
  final String playbackError;
  final VoidCallback onOpenVideo;
  final VoidCallback onOpenTopic;

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _initializing = false;
  bool _ready = false;
  bool _error = false;

  @override
  void didUpdateWidget(covariant _VideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && oldWidget.isActive) {
      _disposePlayer();
    }
  }

  Future<void> _ensurePlayer() async {
    if (_chewieController != null ||
        _initializing ||
        widget.playbackUrl.isEmpty) {
      return;
    }
    _initializing = true;
    _error = false;

    try {
      final videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.playbackUrl),
        formatHint: VideoFormat.hls,
        httpHeaders: _videoRequestHeaders,
      );
      await videoController.initialize().timeout(const Duration(seconds: 20));
      final chewieController = ChewieController(
        videoPlayerController: videoController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        showControlsOnInitialize: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primary,
          bufferedColor: AppColors.primaryPressed,
          backgroundColor: AppColors.border,
          handleColor: AppColors.primary,
        ),
      );
      if (!mounted) {
        chewieController.dispose();
        await videoController.dispose();
        return;
      }
      setState(() {
        _videoPlayerController = videoController;
        _chewieController = chewieController;
        _ready = true;
        _initializing = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error = true;
        _initializing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _initializing = false;
      });
    }
  }

  void _disposePlayer() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    _chewieController = null;
    _videoPlayerController = null;
    _initializing = false;
    _ready = false;
    _error = false;
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onOpenVideo,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRect(
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 10.2,
                    child: widget.isActive
                        ? _buildPlayer()
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              if (widget.video.videoThumbnail.isNotEmpty)
                                Image.network(
                                  widget.video.videoThumbnail,
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
                                color: Colors.black.withValues(alpha: 0.12),
                              ),
                              const Center(
                                child: CircleAvatar(
                                  radius: 29,
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    Icons.play_arrow_rounded,
                                    color: Color(0xFF4C8DFF),
                                    size: 30,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: InkWell(
                onTap: widget.onOpenTopic,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.video.title.isNotEmpty
                            ? widget.video.title
                            : widget.video.topicTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16.8,
                          height: 1.24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    if (widget.playbackError.isNotEmpty) {
      return Container(
        color: const Color(0xFF0B1220),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Video ochilmadi',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.playbackError,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (widget.loadingPlayback || widget.playbackUrl.isEmpty) {
      return Container(
        color: const Color(0xFF0B1220),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }

    if (_chewieController == null || !_ready) {
      final future = _ensurePlayer();
      return FutureBuilder<void>(
        future: future,
        builder: (context, snapshot) {
          if (_error) {
            return Container(
              color: const Color(0xFF0B1220),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Video ochilmadi',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          if (_chewieController == null || !_ready) {
            return Container(
              color: const Color(0xFF0B1220),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            );
          }
          return Chewie(controller: _chewieController!);
        },
      );
    }

    return Chewie(controller: _chewieController!);
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
