import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../core/app_constants.dart';

class QuestionExplanationFooter extends StatelessWidget {
  const QuestionExplanationFooter({
    super.key,
    required this.questionText,
    required this.correctAnswer,
    required this.explanation,
    required this.audioUrl,
    this.showExplanationActions = true,
    this.onFinish,
    this.onRestart,
    this.finishLabel = 'Yakunlash',
    this.finishIcon = Icons.check_rounded,
    this.finishColor = const Color(0xFF0D4FC9),
    this.finishForegroundColor = Colors.white,
    this.restartColor = const Color(0xFFB62929),
    this.restartForegroundColor = Colors.white,
  });

  final String questionText;
  final String correctAnswer;
  final String explanation;
  final String audioUrl;
  final bool showExplanationActions;
  final VoidCallback? onFinish;
  final VoidCallback? onRestart;
  final String finishLabel;
  final IconData finishIcon;
  final Color finishColor;
  final Color finishForegroundColor;
  final Color restartColor;
  final Color restartForegroundColor;

  @override
  Widget build(BuildContext context) {
    final hasTextExplanation = explanation.trim().isNotEmpty;
    final hasAudio = audioUrl.trim().isNotEmpty;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
        child: Row(
          children: [
            if (showExplanationActions) ...[
              Expanded(
                child: _ActionChip(
                  icon: Icons.description_outlined,
                  label: 'Izoh',
                  onTap: hasTextExplanation
                      ? () {
                          showQuestionTextExplanationSheet(
                            context: context,
                            explanation: explanation,
                          );
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ActionChip(
                  icon: Icons.volume_up_outlined,
                  label: 'Audio',
                  onTap: hasAudio
                      ? () {
                          showQuestionAudioExplanationSheet(
                            context: context,
                            audioUrl: audioUrl,
                          );
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 42,
                child: FilledButton.tonalIcon(
                  onPressed: onFinish,
                  icon: Icon(finishIcon, size: 16),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(finishLabel, maxLines: 1),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: finishColor,
                    foregroundColor: finishForegroundColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _IconActionButton(
              icon: Icons.refresh_rounded,
              onTap: onRestart,
              backgroundColor: restartColor,
              foregroundColor: restartForegroundColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final backgroundColor = label == 'Audio'
        ? const Color(0xFF2E1F63)
        : const Color(0xFF0D4FC9);
    final borderColor = label == 'Audio'
        ? const Color(0xFF5A3FC0)
        : const Color(0xFF3B79E8);
    final iconColor = label == 'Audio' ? Colors.white : Colors.white;
    final textColor = Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: enabled ? 1 : 0.42,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            constraints: const BoxConstraints(minHeight: 42),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: iconColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.icon,
    required this.onTap,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: foregroundColor, size: 16),
        ),
      ),
    );
  }
}

Future<void> showQuestionTextExplanationSheet({
  required BuildContext context,
  required String explanation,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(dialogContext).pop(),
                child: const SizedBox.expand(),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: MediaQuery.removePadding(
                context: dialogContext,
                removeBottom: true,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(dialogContext).pop(),
                          child: Center(
                            child: Container(
                              width: 42,
                              height: 5,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD8DFEA),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.description_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 7),
                            const Text(
                              'Izoh',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          explanation.trim().isNotEmpty
                              ? explanation
                              : 'Izoh mavjud emas',
                          style: const TextStyle(
                            fontSize: 14.5,
                            height: 1.45,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showQuestionAudioExplanationSheet({
  required BuildContext context,
  required String audioUrl,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(dialogContext).pop(),
                child: const SizedBox.expand(),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _AudioExplanationSheet(audioUrl: audioUrl),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showTestLockedRestartSheet({
  required BuildContext context,
  required String title,
  required String message,
  required Future<void> Function() onRestart,
  String restartLabel = 'Qayta boshlash',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return MediaQuery.removePadding(
        context: sheetContext,
        removeBottom: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await onRestart();
                  },
                  child: Text(restartLabel),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _AudioExplanationSheet extends StatefulWidget {
  const _AudioExplanationSheet({required this.audioUrl});

  final String audioUrl;

  @override
  State<_AudioExplanationSheet> createState() => _AudioExplanationSheetState();
}

class _AudioExplanationSheetState extends State<_AudioExplanationSheet> {
  late final AudioPlayer _player;
  File? _tempAudioFile;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  PlayerState _playerState = PlayerState.stopped;
  bool _loading = true;
  bool _pluginUnavailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration);
    });
    _player.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _playerState = state);
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final source = await _prepareAudioSource(widget.audioUrl);
      if (source == null) {
        throw Exception('Audio manzili topilmadi');
      }
      _tempAudioFile = source.file;
      await _player.setSourceDeviceFile(
        source.file.path,
        mimeType: source.mimeType,
      );
      if (!mounted) return;
      setState(() => _loading = false);
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _pluginUnavailable = true;
        _error =
            'Audio player bu qurilmada ishga tushmadi. Ilovani to‘liq qayta ishga tushiring yoki tashqaridan oching.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _formatAudioError(e);
      });
    }
  }

  @override
  void dispose() {
    final tempFile = _tempAudioFile;
    if (tempFile != null) {
      unawaited(() async {
        try {
          await tempFile.parent.delete(recursive: true);
        } catch (_) {}
      }());
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_loading || _error != null) return;
    if (_playerState == PlayerState.playing) {
      await _player.pause();
      return;
    }
    await _player.resume();
  }

  Future<void> _openExternally() async {
    final uri = Uri.tryParse(_resolveDirectAudioUrl(widget.audioUrl));
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds)
              .clamp(0.0, 1.0)
              .toDouble();
    final remaining = _duration - _position;

    return MediaQuery.removePadding(
      context: context,
      removeBottom: true,
      child: Container(
        padding: const EdgeInsets.only(bottom: 30),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: SizedBox(
                  width: double.infinity,
                  height: 24,
                  child: Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8DFEA),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.volume_up_outlined,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  const Text(
                    'Audio izoh',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  if (!_loading && _error == null)
                    Text(
                      _formatDuration(_duration),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(width: 6),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 34,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDEE),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF1B7B7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFB03A3A),
                          height: 1.4,
                        ),
                      ),
                      if (_pluginUnavailable) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: FilledButton.tonal(
                            onPressed: _openExternally,
                            child: const Text('Tashqarida ochish'),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FB),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Qolgan ${_formatDuration(remaining)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 0),
                      Slider(
                        value: progress,
                        activeColor: AppColors.primary,
                        onChanged: _duration.inMilliseconds == 0
                            ? null
                            : (value) async {
                                final newPosition = Duration(
                                  milliseconds:
                                      (_duration.inMilliseconds * value)
                                          .round(),
                                );
                                await _player.seek(newPosition);
                              },
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        width: 46,
                        height: 46,
                        child: _loading
                            ? const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                ),
                              )
                            : FilledButton(
                                onPressed: _togglePlay,
                                style: FilledButton.styleFrom(
                                  shape: const CircleBorder(),
                                  padding: EdgeInsets.zero,
                                ),
                                child: Icon(
                                  _playerState == PlayerState.playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 22,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _PreparedAudioSource {
  const _PreparedAudioSource({required this.file, required this.mimeType});

  final File file;
  final String? mimeType;
}

String _formatAudioError(Object error) {
  final text = error.toString();
  if (text.startsWith('Exception: ')) {
    return text.substring('Exception: '.length);
  }
  return text;
}

String _normalizeContentType(String? contentType) {
  final value = (contentType ?? '').trim().toLowerCase();
  if (value.isEmpty) return '';
  return value.split(';').first.trim();
}

String? _mimeTypeFromAudioUrl(String url) {
  final value = url.toLowerCase();
  if (value.endsWith('.mp3')) return 'audio/mpeg';
  if (value.endsWith('.m4a') || value.endsWith('.mp4')) return 'audio/mp4';
  if (value.endsWith('.wav')) return 'audio/wav';
  if (value.endsWith('.webm')) return 'audio/webm';
  if (value.endsWith('.ogg') || value.endsWith('.oga')) return 'audio/ogg';
  return null;
}

String _extensionFromMimeType(String? mimeType) {
  final value = _normalizeContentType(mimeType);
  switch (value) {
    case 'audio/mpeg':
      return 'mp3';
    case 'audio/mp4':
      return 'm4a';
    case 'audio/wav':
      return 'wav';
    case 'audio/webm':
      return 'webm';
    case 'audio/ogg':
      return 'ogg';
    default:
      return '';
  }
}

String _extensionFromUrl(String url) {
  final uri = Uri.tryParse(url);
  final path = uri?.path ?? '';
  final lower = path.toLowerCase();
  if (lower.endsWith('.mp3')) return 'mp3';
  if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) return 'm4a';
  if (lower.endsWith('.wav')) return 'wav';
  if (lower.endsWith('.webm')) return 'webm';
  if (lower.endsWith('.ogg') || lower.endsWith('.oga')) return 'ogg';
  return 'm4a';
}

String _resolveDirectAudioUrl(String audioUrl) {
  final value = audioUrl.trim();
  if (value.isEmpty) return '';
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  if (value.startsWith('/')) return '$apiBaseUrl$value';
  return '$apiBaseUrl/$value';
}

List<String> _audioUrlCandidates(String audioUrl) {
  final direct = _resolveDirectAudioUrl(audioUrl);
  if (direct.isEmpty) return const [];
  final proxy =
      '$apiBaseUrl/api/audio-proxy?url=${Uri.encodeComponent(direct)}';
  if (proxy == direct) return [direct];
  return [proxy, direct];
}

Future<_PreparedAudioSource?> _prepareAudioSource(String audioUrl) async {
  final candidates = _audioUrlCandidates(audioUrl);
  if (candidates.isEmpty) return null;

  Object? lastError;
  for (final candidate in candidates) {
    try {
      final uri = Uri.tryParse(candidate);
      if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
        throw Exception('Audio manzili noto‘g‘ri');
      }

      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'audio/*, application/octet-stream, */*',
          'User-Agent': 'RoadTestMobile/1.0',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Audio yuklab bo‘lmadi: ${response.statusCode}');
      }

      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        throw Exception('Audio fayli bo‘sh');
      }

      final contentType = _normalizeContentType(
        response.headers['content-type'],
      );
      final mimeType = contentType.isNotEmpty
          ? contentType
          : _mimeTypeFromAudioUrl(candidate) ??
                _mimeTypeFromAudioUrl(audioUrl) ??
                'audio/mp4';
      final mimeExtension = _extensionFromMimeType(mimeType);
      final extension = mimeExtension.isNotEmpty
          ? mimeExtension
          : _extensionFromUrl(candidate);
      final tempDir = await Directory.systemTemp.createTemp('road_test_audio_');
      final file = File('${tempDir.path}/audio.$extension');
      await file.writeAsBytes(bytes, flush: true);
      return _PreparedAudioSource(file: file, mimeType: mimeType);
    } catch (error) {
      lastError = error;
    }
  }

  if (lastError != null) {
    throw lastError;
  }
  return null;
}
