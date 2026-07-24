import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/app_bootstrap.dart';

class CachedAudioFile {
  CachedAudioFile({required this.file, required this.mimeType});

  final File file;
  final String? mimeType;
}

class OfflineCacheStore {
  static AppBootstrapConfig? _appConfig;
  static OfflineManifest? _offlineManifest;

  static void setAppConfig(AppBootstrapConfig? config) {
    _appConfig = config;
  }

  static AppBootstrapConfig? get appConfig => _appConfig;

  static void setOfflineManifest(OfflineManifest? manifest) {
    _offlineManifest = manifest;
  }

  static OfflineManifest? get offlineManifest => _offlineManifest;

  static String get _namespace {
    final version = _offlineManifest?.version.trim() ?? '';
    return version.isNotEmpty ? version : 'legacy';
  }

  static Future<Directory> _baseDir() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/offline_cache/$_namespace');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _safeId(String value) {
    final bytes = utf8.encode(value);
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static Future<File> _sectionFile({
    required String kind,
    required String id,
    required String lang,
  }) async {
    final dir = Directory(
      '${(await _baseDir()).path}/questions/$kind/${_safeId(id)}/$lang',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/questions.json');
  }

  static Future<void> saveQuestions({
    required String kind,
    required String id,
    required String lang,
    required List<Map<String, dynamic>> questions,
  }) async {
    final file = await _sectionFile(kind: kind, id: id, lang: lang);
    await file.writeAsString(jsonEncode(questions), flush: true);
  }

  static Future<List<Map<String, dynamic>>?> loadQuestions({
    required String kind,
    required String id,
    required String lang,
  }) async {
    try {
      final file = await _sectionFile(kind: kind, id: id, lang: lang);
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> prefetchAudioUrls({
    required Iterable<String> audioUrls,
  }) async {
    if (_appConfig?.audioOfflineCache == false) return;
    for (final audioUrl in audioUrls) {
      final url = audioUrl.trim();
      if (url.isEmpty) continue;
      unawaited(cacheAudio(url));
    }
  }

  static Future<CachedAudioFile?> resolveAudio(String audioUrl) async {
    final normalized = audioUrl.trim();
    if (normalized.isEmpty) return null;
    final dir = await _audioDir();
    final cached = await _findCachedAudioFile(dir, normalized);
    if (cached != null) return cached;
    return cacheAudio(normalized);
  }

  static Future<CachedAudioFile?> cacheAudio(String audioUrl) async {
    final normalized = audioUrl.trim();
    if (normalized.isEmpty) return null;

    final existing = await _findCachedAudioFile(await _audioDir(), normalized);
    if (existing != null) return existing;

    final uri = Uri.tryParse(normalized);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    final response = await http.get(
      uri,
      headers: const {
        'Accept': 'audio/*, application/octet-stream, */*',
        'User-Agent': 'TopshirdiMobile/1.0',
      },
    );
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw HttpException('Audio yuklanmadi: ${response.statusCode}', uri: uri);
    }

    final contentType = _normalizeContentType(response.headers['content-type']);
    final mimeType = contentType.isNotEmpty ? contentType : _mimeTypeFromUrl(normalized);
    final extension = _extensionFromMimeType(mimeType) ?? _extensionFromUrl(normalized);
    final dir = await _audioDir();
    final file = File('${dir.path}/${_safeId(normalized)}.$extension');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    await _writeMeta(file, mimeType);
    return CachedAudioFile(file: file, mimeType: mimeType);
  }

  static Future<Directory> _audioDir() async {
    final root = await _baseDir();
    final dir = Directory('${root.path}/audio');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<CachedAudioFile?> _findCachedAudioFile(
    Directory dir,
    String audioUrl,
  ) async {
    final prefix = _safeId(audioUrl);
    if (!await dir.exists()) return null;
    final candidates = await dir.list().toList();
    for (final entity in candidates) {
      if (entity is! File) continue;
      if (entity.path.endsWith('.meta')) continue;
      if (!entity.path.contains(prefix)) continue;
      final meta = await _readMeta(entity);
      return CachedAudioFile(file: entity, mimeType: meta);
    }
    return null;
  }

  static Future<void> _writeMeta(File file, String? mimeType) async {
    final metaFile = File('${file.path}.meta');
    await metaFile.writeAsString(
      jsonEncode({'mimeType': mimeType}),
      flush: true,
    );
  }

  static Future<String?> _readMeta(File file) async {
    final metaFile = File('${file.path}.meta');
    if (!await metaFile.exists()) return null;
    try {
      final raw = await metaFile.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['mimeType'] != null) {
        return decoded['mimeType'].toString();
      }
    } catch (_) {}
    return null;
  }

  static String _normalizeContentType(String? contentType) {
    final value = (contentType ?? '').trim().toLowerCase();
    if (value.isEmpty) return '';
    return value.split(';').first.trim();
  }

  static String? _mimeTypeFromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) return 'audio/mp4';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.webm')) return 'audio/webm';
    if (lower.endsWith('.ogg') || lower.endsWith('.oga')) return 'audio/ogg';
    return null;
  }

  static String? _extensionFromMimeType(String? mimeType) {
    switch (_normalizeContentType(mimeType)) {
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
        return null;
    }
  }

  static String _extensionFromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.mp3')) return 'mp3';
    if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) return 'm4a';
    if (lower.endsWith('.wav')) return 'wav';
    if (lower.endsWith('.webm')) return 'webm';
    if (lower.endsWith('.ogg') || lower.endsWith('.oga')) return 'ogg';
    return 'm4a';
  }
}
