import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../core/app_constants.dart';
import '../l10n/app_strings.dart';
import '../services/api_client.dart';
import '../services/offline_cache_store.dart';

class QuestionAudioAdminContext {
  const QuestionAudioAdminContext({
    required this.accessToken,
    required this.sourceKind,
    required this.sourceId,
    required this.questionId,
  });

  final String accessToken;
  final String sourceKind;
  final String sourceId;
  final String questionId;
}

class QuestionExplanationFooter extends StatelessWidget {
  const QuestionExplanationFooter({
    super.key,
    required this.questionText,
    required this.correctAnswer,
    required this.explanation,
    required this.audioUrl,
    this.audioAdminContext,
    this.onAudioChanged,
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
  final QuestionAudioAdminContext? audioAdminContext;
  final ValueChanged<String?>? onAudioChanged;
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
    final strings = AppStrings.of(context);
    final hasTextExplanation = explanation.trim().isNotEmpty;
    final hasAudio = audioUrl.trim().isNotEmpty;
    final canOpenAudio = hasAudio || audioAdminContext != null;
    final effectiveFinishLabel =
        finishLabel == 'Yakunlash' ? strings.t('finish') : finishLabel;

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
                  label: strings.t('explanation'),
                  isAudio: false,
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
                  label: strings.t('audio'),
                  isAudio: true,
                  onTap: canOpenAudio
                      ? () {
                          showQuestionAudioExplanationSheet(
                            context: context,
                            audioUrl: audioUrl,
                            adminContext: audioAdminContext,
                            onAudioChanged: onAudioChanged,
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
                    child: Text(effectiveFinishLabel, maxLines: 1),
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
    required this.isAudio,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isAudio;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final backgroundColor = isAudio
        ? const Color(0xFF2E1F63)
        : const Color(0xFF0D4FC9);
    final borderColor = isAudio
        ? const Color(0xFF5A3FC0)
        : const Color(0xFF3B79E8);
    final iconColor = Colors.white;
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
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
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
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
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
  final strings = AppStrings.of(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: strings.t('dismiss'),
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
                  decoration: BoxDecoration(
                    color: AppColors.surface,
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
                                color: AppColors.border,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              strings.t('explanation'),
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
                              icon: Icon(
                                Icons.close_rounded,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          explanation.trim().isNotEmpty
                              ? explanation
                              : strings.t('no_explanation'),
                          style: TextStyle(
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
  QuestionAudioAdminContext? adminContext,
  ValueChanged<String?>? onAudioChanged,
}) {
  final strings = AppStrings.of(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: strings.t('dismiss'),
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
              child: _AudioExplanationSheet(
                audioUrl: audioUrl,
                adminContext: adminContext,
                onAudioChanged: onAudioChanged,
              ),
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
  final strings = AppStrings.of(context);
  final effectiveRestartLabel =
      restartLabel == 'Qayta boshlash' ? strings.t('restart') : restartLabel;
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
          decoration: BoxDecoration(
            color: AppColors.surface,
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: TextStyle(
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
                  child: Text(effectiveRestartLabel),
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
  const _AudioExplanationSheet({
    required this.audioUrl,
    this.adminContext,
    this.onAudioChanged,
  });

  final String audioUrl;
  final QuestionAudioAdminContext? adminContext;
  final ValueChanged<String?>? onAudioChanged;

  @override
  State<_AudioExplanationSheet> createState() => _AudioExplanationSheetState();
}

class _AudioExplanationSheetState extends State<_AudioExplanationSheet> {
  late final AudioPlayer _player;
  final AudioRecorder _recorder = AudioRecorder();
  File? _tempAudioFile;
  String? _recordedAudioPath;
  String _currentAudioUrl = '';
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Duration _recordDuration = Duration.zero;
  PlayerState _playerState = PlayerState.stopped;
  bool _loading = true;
  bool _pluginUnavailable = false;
  bool _recording = false;
  bool _uploading = false;
  bool _deleting = false;
  String? _error;
  Timer? _recordTimer;
  DateTime? _recordStartedAt;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _currentAudioUrl = widget.audioUrl.trim();
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
    if (_currentAudioUrl.isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    try {
      final source = await _prepareAudioSource(_currentAudioUrl);
      if (source == null) {
        throw Exception('Audio manzili topilmadi');
      }
      _tempAudioFile = source.temporary ? source.file : null;
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
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppStrings.of(context).t('internet_required');
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
    final draftPath = _recordedAudioPath;
    _recordTimer?.cancel();
    if (tempFile != null) {
      unawaited(() async {
        try {
          await tempFile.parent.delete(recursive: true);
        } catch (_) {}
      }());
    }
    if (draftPath != null && draftPath.isNotEmpty) {
      unawaited(() async {
        try {
          await File(draftPath).parent.delete(recursive: true);
        } catch (_) {}
      }());
    }
    _player.dispose();
    unawaited(_recorder.dispose());
    super.dispose();
  }

  bool get _isAdmin => widget.adminContext != null;
  bool get _hasPlayableAudio =>
      _recordedAudioPath != null || _currentAudioUrl.isNotEmpty;

  Future<void> _togglePlay() async {
    if (_loading || _error != null || !_hasPlayableAudio) return;
    if (_playerState == PlayerState.playing) {
      await _player.pause();
      return;
    }
    await _player.resume();
  }

  String _formatClock(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _loadFromPath(String path) async {
    await _player.stop();
    await _player.setSourceDeviceFile(path, mimeType: 'audio/mp4');
    if (!mounted) return;
    setState(() {
      _duration = Duration.zero;
      _position = Duration.zero;
      _loading = false;
      _error = null;
    });
  }

  void _startRecordTimer() {
    _recordTimer?.cancel();
    _recordStartedAt = DateTime.now();
    _recordDuration = Duration.zero;
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_recording || _recordStartedAt == null) return;
      setState(() {
        _recordDuration = DateTime.now().difference(_recordStartedAt!);
      });
    });
  }

  Future<void> _startRecording() async {
    if (!_isAdmin || _recording || _uploading || _deleting) return;
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        setState(() {
          _error =
              'Mikrofondan foydalanish uchun ruxsat bering. Qurilma sozlamalaridan audio ruxsatini yoqing.';
        });
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final dir = Directory(
        '${tempDir.path}/topshirdi_admin_audio_${DateTime.now().microsecondsSinceEpoch}',
      );
      await dir.create(recursive: true);
      final path = '${dir.path}/audio.m4a';

      await _player.stop();
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordedAudioPath = path;
        _loading = false;
        _error = null;
        _recordDuration = Duration.zero;
      });
      _startRecordTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recording = false;
        _error = _formatAudioError(e);
        _loading = false;
      });
    }
  }

  Future<void> _stopRecordingAndUpload() async {
    if (!_recording) return;
    try {
      _recordTimer?.cancel();
      _recordTimer = null;
      final path = await _recorder.stop();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _loading = false;
        if (path != null && path.isNotEmpty) {
          _recordedAudioPath = path;
        }
      });
      final draftPath = _recordedAudioPath;
      if (draftPath != null && draftPath.isNotEmpty) {
        await _loadFromPath(draftPath);
        await _uploadRecordedAudio();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recording = false;
        _error = _formatAudioError(e);
      });
    }
  }

  Future<void> _uploadRecordedAudio() async {
    final adminContext = widget.adminContext;
    final draftPath = _recordedAudioPath;
    if (adminContext == null || draftPath == null || draftPath.isEmpty) return;
    if (_recording || _uploading || _deleting) return;

    try {
      setState(() {
        _uploading = true;
        _error = null;
      });
      final uploadedUrl = await ApiClient.uploadQuestionAudio(
        accessToken: adminContext.accessToken,
        audioPath: draftPath,
        audioName: 'question_${DateTime.now().millisecondsSinceEpoch}.m4a',
        sourceKind: adminContext.sourceKind,
        sourceId: adminContext.sourceId,
        questionId: adminContext.questionId,
        oldAudioUrl: _currentAudioUrl,
      );
      if (!mounted) return;
      setState(() {
        _currentAudioUrl = uploadedUrl;
        _recordedAudioPath = null;
        _recordDuration = Duration.zero;
      });
      widget.onAudioChanged?.call(uploadedUrl);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _formatAudioError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  Future<void> _deleteAudio() async {
    final adminContext = widget.adminContext;
    if (adminContext == null) return;
    if (_recording || _uploading || _deleting) return;
    if (_currentAudioUrl.isEmpty && _recordedAudioPath == null) return;

    try {
      setState(() {
        _deleting = true;
        _error = null;
      });

      if (_currentAudioUrl.isNotEmpty) {
        await ApiClient.deleteQuestionAudio(
          accessToken: adminContext.accessToken,
          sourceKind: adminContext.sourceKind,
          sourceId: adminContext.sourceId,
          questionId: adminContext.questionId,
          audioUrl: _currentAudioUrl,
        );
      }

      final draftPath = _recordedAudioPath;
      if (draftPath != null && draftPath.isNotEmpty) {
        try {
          await File(draftPath).delete();
        } catch (_) {}
      }

      await _player.stop();
      if (!mounted) return;
      setState(() {
        _currentAudioUrl = '';
        _recordedAudioPath = null;
        _recordDuration = Duration.zero;
        _duration = Duration.zero;
        _position = Duration.zero;
        _playerState = PlayerState.stopped;
        _loading = false;
      });
      widget.onAudioChanged?.call('');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _formatAudioError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _deleting = false;
        });
      }
    }
  }

  Future<void> _openExternally() async {
    final uri = Uri.tryParse(_resolveDirectAudioUrl(_currentAudioUrl));
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
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
        decoration: BoxDecoration(
          color: AppColors.surface,
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
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.volume_up_outlined,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    strings.t('audio_explanation'),
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  if (_isAdmin)
                    Text(
                      _recording
                          ? 'Yozilmoqda'
                          : _recordedAudioPath != null
                          ? 'Qoralama'
                          : _currentAudioUrl.isNotEmpty
                          ? 'Mavjud'
                          : 'Yangi',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(width: 6),
                  if (!_loading && _error == null && _hasPlayableAudio)
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(
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
                    icon: Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        style: TextStyle(
                          color: AppColors.danger,
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
                            child: Text(strings.t('open_external')),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.8),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_hasPlayableAudio) ...[
                            Row(
                              children: [
                                Text(
                                  _formatDuration(_position),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${strings.t('remaining')} ${_formatDuration(remaining)}',
                                  style: TextStyle(
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
                                  ? Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: AppColors.primary,
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
                                        color: AppColors.text,
                                      ),
                                    ),
                            ),
                          ] else if (_isAdmin) ...[
                            Text(
                              'Hali audio yo‘q. Mikrofon bilan yozib qo‘shishingiz mumkin.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ] else ...[
                            Text(
                              strings.t('no_explanation'),
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_isAdmin) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_recording)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 2,
                                      bottom: 6,
                                    ),
                                    child: Text(
                                      _formatClock(_recordDuration),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                GestureDetector(
                                  onLongPressStart: (_) => _startRecording(),
                                  onLongPressEnd: (_) =>
                                      _stopRecordingAndUpload(),
                                  onLongPressCancel: () =>
                                      _stopRecordingAndUpload(),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: _recording
                                          ? const Color(0xFFE25555)
                                          : AppColors.primary,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        _recording
                                            ? Icons.mic_none_rounded
                                            : Icons.mic_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: FilledButton.tonal(
                              onPressed:
                                  (_currentAudioUrl.isNotEmpty ||
                                          _recordedAudioPath != null) &&
                                      !_recording &&
                                      !_uploading
                                  ? _deleteAudio
                                  : null,
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _deleting
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.delete_outline_rounded),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
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
  const _PreparedAudioSource({
    required this.file,
    required this.mimeType,
    required this.temporary,
  });

  final File file;
  final String? mimeType;
  final bool temporary;
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
  final cacheEnabled = OfflineCacheStore.appConfig?.audioOfflineCache != false;
  if (cacheEnabled) {
    final cached = await OfflineCacheStore.resolveAudio(audioUrl);
    if (cached != null) {
      return _PreparedAudioSource(
        file: cached.file,
        mimeType: cached.mimeType,
        temporary: false,
      );
    }
  }

  return _downloadAudioSource(audioUrl, cacheEnabled: cacheEnabled);
}

Future<_PreparedAudioSource?> _downloadAudioSource(
  String audioUrl, {
  required bool cacheEnabled,
}) async {
  final candidates = _audioUrlCandidates(audioUrl);
  if (candidates.isEmpty) return null;

  Object? lastError;
  for (final candidate in candidates) {
    try {
      if (!cacheEnabled) {
        final uri = Uri.tryParse(candidate);
        if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
          throw Exception('Audio manzili noto‘g‘ri');
        }

        final response = await http.get(
          uri,
          headers: const {
            'Accept': 'audio/*, application/octet-stream, */*',
            'User-Agent': 'TopshirdiMobile/1.0',
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
        final tempDir = await Directory.systemTemp.createTemp('topshirdi_audio_');
        final file = File('${tempDir.path}/audio.$extension');
        await file.writeAsBytes(bytes, flush: true);
        return _PreparedAudioSource(
          file: file,
          mimeType: mimeType,
          temporary: true,
        );
      }
      final cache = await OfflineCacheStore.cacheAudio(candidate);
      if (cache != null) {
        return _PreparedAudioSource(
          file: cache.file,
          mimeType: cache.mimeType,
          temporary: false,
        );
      }
    } catch (error) {
      lastError = error;
    }
  }

  if (lastError != null) {
    throw lastError;
  }
  return null;
}
