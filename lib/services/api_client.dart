import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/app_constants.dart';
import '../l10n/app_strings.dart';
import '../models/app_bootstrap.dart';
import '../models/auth_session.dart';
import '../models/custom_test_progress_summary.dart';
import '../models/mistake_question.dart';
import '../models/topic_progress_summary.dart';
import '../models/video_lesson.dart';
import '../models/topic_question.dart';
import '../models/topic_summary.dart';
import '../models/ticket_summary.dart';
import 'offline_cache_store.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  static String _langParam() {
    final code = AppLanguageStore.currentCode;
    return code.isEmpty ? AppLanguageStore.uzLatn : code;
  }

  static Uri _uri(String path, {Map<String, String>? queryParameters}) {
    final params = <String, String>{...?queryParameters, 'lang': _langParam()};
    return Uri.parse('$apiBaseUrl$path').replace(queryParameters: params);
  }

  static Map<String, String> _jsonHeaders({String? accessToken}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    return headers;
  }

  static List<Map<String, dynamic>> _mapsFromJsonList(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static List<T> _mapModels<T>(
    List<Map<String, dynamic>> value,
    T Function(Map<String, dynamic>) factory,
  ) {
    return value.map(factory).toList();
  }

  static String? _extractRefreshToken(http.Response response) {
    final raw = response.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return null;
    final match = RegExp(r'refresh_token=([^;]+)').firstMatch(raw);
    return match?.group(1);
  }

  static Future<AuthSession> register({
    required String phone,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/api/auth/register'),
      headers: _jsonHeaders(),
      body: jsonEncode({'phone': phone, 'password': password}),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw Exception(
        body['error']?.toString() ?? 'Ro‘yxatdan o‘tish amalga oshmadi',
      );
    }
    final accessToken = body['accessToken']?.toString();
    final user = body['user'];
    if (accessToken == null || accessToken.isEmpty || user is! Map) {
      throw Exception('Noto‘g‘ri javob keldi');
    }
    return AuthSession(
      accessToken: accessToken,
      refreshToken: _extractRefreshToken(response),
      user: Map<String, dynamic>.from(user),
    );
  }

  static Future<AuthSession> login({
    required String phone,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/api/auth/login'),
      headers: _jsonHeaders(),
      body: jsonEncode({'phone': phone, 'password': password}),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw Exception(body['error']?.toString() ?? 'Kirish amalga oshmadi');
    }
    final accessToken = body['accessToken']?.toString();
    final user = body['user'];
    if (accessToken == null || accessToken.isEmpty || user is! Map) {
      throw Exception('Noto‘g‘ri javob keldi');
    }
    return AuthSession(
      accessToken: accessToken,
      refreshToken: _extractRefreshToken(response),
      user: Map<String, dynamic>.from(user),
    );
  }

  static Future<void> changePassword({
    required String accessToken,
    String? currentPassword,
    required String newPassword,
  }) async {
    final requestBody = <String, String>{'newPassword': newPassword};
    if (currentPassword != null) {
      requestBody['currentPassword'] = currentPassword;
    }
    final response = await http.post(
      Uri.parse('$apiBaseUrl/api/auth/password-change'),
      headers: _jsonHeaders(accessToken: accessToken),
      body: jsonEncode(requestBody),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw Exception(
        body['error']?.toString() ?? 'Parolni almashtirish amalga oshmadi',
      );
    }
  }

  static Future<AuthSession> refresh(String refreshToken) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/api/auth/refresh'),
      headers: {'Cookie': 'refresh_token=$refreshToken'},
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Session yangilanmadi',
      );
    }
    final accessToken = body['accessToken']?.toString();
    if (accessToken == null || accessToken.isEmpty) {
      throw ApiException(500, 'Access token qaytmadi');
    }
    return AuthSession(
      accessToken: accessToken,
      refreshToken: _extractRefreshToken(response) ?? refreshToken,
      user: const <String, dynamic>{},
    );
  }

  static Future<AuthSession> me(String accessToken) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/auth/me'),
      headers: _jsonHeaders(accessToken: accessToken),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw Exception(body['error']?.toString() ?? 'Profil topilmadi');
    }
    final user = body['user'];
    if (user is! Map) throw Exception('Noto‘g‘ri profil javobi');
    return AuthSession(
      accessToken: accessToken,
      user: Map<String, dynamic>.from(user),
    );
  }

  static Future<void> logout(String refreshToken) async {
    await http.post(
      Uri.parse('$apiBaseUrl/api/auth/logout'),
      headers: {'Cookie': 'refresh_token=$refreshToken'},
    );
  }

  static Future<void> deleteAccount(String accessToken) async {
    final response = await http.delete(
      Uri.parse('$apiBaseUrl/api/auth/account'),
      headers: _jsonHeaders(accessToken: accessToken),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw Exception(body['error']?.toString() ?? 'Account o‘chirilmadi');
    }
  }

  static Future<List<TopicSummary>> topics(String accessToken) async {
    final lang = _langParam();
    try {
      final response = await http.get(
        _uri('/api/topics'),
        headers: _jsonHeaders(accessToken: accessToken),
      );
      final body = _decodeBody(response);
      if (response.statusCode >= 400) {
        throw ApiException(
          response.statusCode,
          body['error']?.toString() ?? 'Mavzular yuklanmadi',
        );
      }
      final rawTopics = _mapsFromJsonList(body['topics']);
      if (rawTopics.isNotEmpty) {
        await OfflineCacheStore.saveQuestions(
          kind: 'topics',
          id: 'list',
          lang: lang,
          questions: rawTopics,
        );
      }
      return _mapModels(rawTopics, TopicSummary.fromJson);
    } on SocketException {
      final cached = await OfflineCacheStore.loadQuestions(
        kind: 'topics',
        id: 'list',
        lang: lang,
      );
      if (cached != null) return _mapModels(cached, TopicSummary.fromJson);
      rethrow;
    }
  }

  static Future<List<TicketSummary>> tickets(String accessToken) async {
    final lang = _langParam();
    try {
      final response = await http.get(
        _uri('/api/tickets'),
        headers: _jsonHeaders(accessToken: accessToken),
      );
      final body = _decodeBody(response);
      if (response.statusCode >= 400) {
        throw ApiException(
          response.statusCode,
          body['error']?.toString() ?? 'Biletlar yuklanmadi',
        );
      }
      final rawTickets = _mapsFromJsonList(body['tickets']);
      if (rawTickets.isNotEmpty) {
        await OfflineCacheStore.saveQuestions(
          kind: 'tickets',
          id: 'list',
          lang: lang,
          questions: rawTickets,
        );
      }
      return _mapModels(rawTickets, TicketSummary.fromJson);
    } on SocketException {
      final cached = await OfflineCacheStore.loadQuestions(
        kind: 'tickets',
        id: 'list',
        lang: lang,
      );
      if (cached != null) return _mapModels(cached, TicketSummary.fromJson);
      rethrow;
    }
  }

  static Future<List<TicketSummary>> customTests(String accessToken) async {
    final lang = _langParam();
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/custom-tests'),
        headers: _jsonHeaders(accessToken: accessToken),
      );
      final body = _decodeBody(response);
      if (response.statusCode >= 400) {
        throw ApiException(
          response.statusCode,
          body['error']?.toString() ?? 'Sozlamali testlar yuklanmadi',
        );
      }
      final rawTests = _mapsFromJsonList(body['customTests']);
      if (rawTests.isNotEmpty) {
        await OfflineCacheStore.saveQuestions(
          kind: 'custom-tests',
          id: 'list',
          lang: lang,
          questions: rawTests,
        );
      }
      return _mapModels(rawTests, TicketSummary.fromJson);
    } on SocketException {
      final cached = await OfflineCacheStore.loadQuestions(
        kind: 'custom-tests',
        id: 'list',
        lang: lang,
      );
      if (cached != null) return _mapModels(cached, TicketSummary.fromJson);
      rethrow;
    }
  }

  static Future<CustomTestProgressSummary?> customTestProgress({
    required String accessToken,
    required String testId,
  }) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/custom-test-progress/$testId'),
      headers: _jsonHeaders(accessToken: accessToken),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Progress yuklanmadi',
      );
    }
    final progress = body['progress'];
    if (progress is! Map) return null;
    return CustomTestProgressSummary.fromJson(
      Map<String, dynamic>.from(progress),
    );
  }

  static Future<List<VideoLesson>> videos(String accessToken) async {
    try {
      final response = await http.get(
        _uri('/api/video-lessons'),
        headers: _jsonHeaders(accessToken: accessToken),
      );
      final body = _decodeBody(response);
      if (response.statusCode >= 400) {
        throw ApiException(
          response.statusCode,
          body['error']?.toString() ?? 'Video darslar yuklanmadi',
        );
      }
      final rawVideos = _mapsFromJsonList(body['videos']);
      return _mapModels(rawVideos, VideoLesson.fromJson);
    } on SocketException {
      throw ApiException(
        503,
        'Video darslar uchun internet kerak. Ushbu bo‘lim oflayn ishlamaydi.',
      );
    }
  }

  static Future<AppBootstrapConfig> appConfig() async {
    final response = await http.get(_uri('/api/public/app-config'));
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Ilova sozlamalari yuklanmadi',
      );
    }
    final config = body['appConfig'];
    if (config is! Map) {
      throw ApiException(500, 'Ilova sozlamalari topilmadi');
    }
    return AppBootstrapConfig.fromJson(Map<String, dynamic>.from(config));
  }

  static Future<OfflineManifest> offlineManifest() async {
    final response = await http.get(_uri('/api/public/offline-manifest'));
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Offline manifest yuklanmadi',
      );
    }
    final manifest = body['manifest'];
    if (manifest is! Map) {
      throw ApiException(500, 'Offline manifest topilmadi');
    }
    return OfflineManifest.fromJson(Map<String, dynamic>.from(manifest));
  }

  static Future<String> uploadQuestionAudio({
    required String accessToken,
    required String audioPath,
    required String audioName,
    required String sourceKind,
    required String sourceId,
    required String questionId,
    String oldAudioUrl = '',
  }) async {
    final file = File(audioPath);
    if (!await file.exists()) {
      throw ApiException(400, 'Audio fayli topilmadi');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw ApiException(400, 'Audio fayli bo‘sh');
    }

    final response = await http.post(
      _uri('/api/upload-audio'),
      headers: _jsonHeaders(accessToken: accessToken),
      body: jsonEncode({
        'audioBase64': base64Encode(bytes),
        'audioName': audioName,
        'audioType': _audioMimeTypeFromPath(audioPath),
        'oldAudioUrl': oldAudioUrl,
        if (sourceKind == 'ticket') 'ticketId': sourceId,
        if (sourceKind == 'topic') 'topicId': sourceId,
        if (sourceKind == 'customTest') 'customTestId': sourceId,
        'questionId': questionId,
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Audio yuklash amalga oshmadi',
      );
    }
    final audioUrl = body['audioUrl']?.toString();
    if (audioUrl == null || audioUrl.isEmpty) {
      throw ApiException(500, 'Audio URL qaytmadi');
    }
    return audioUrl;
  }

  static Future<void> deleteQuestionAudio({
    required String accessToken,
    required String sourceKind,
    required String sourceId,
    required String questionId,
    required String audioUrl,
  }) async {
    final body = <String, String>{
      'audioUrl': audioUrl,
      'questionId': questionId,
    };
    if (sourceKind == 'ticket') {
      body['ticketId'] = sourceId;
    } else if (sourceKind == 'topic') {
      body['topicId'] = sourceId;
    } else if (sourceKind == 'customTest') {
      body['customTestId'] = sourceId;
    }

    final response = await http.delete(
      _uri('/api/upload-audio'),
      headers: _jsonHeaders(accessToken: accessToken),
      body: jsonEncode(body),
    );
    final decoded = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        decoded['error']?.toString() ?? 'Audio o‘chirish amalga oshmadi',
      );
    }
  }

  static Future<String> videoPlaybackUrl({
    required String accessToken,
    required String videoId,
  }) async {
    try {
      final response = await http.get(
        _uri('/api/video-lessons/$videoId/playback'),
        headers: _jsonHeaders(accessToken: accessToken),
      );
      final body = _decodeBody(response);
      if (response.statusCode >= 400) {
        throw ApiException(
          response.statusCode,
          body['error']?.toString() ?? 'Playback yuklanmadi',
        );
      }
      final playbackUrl = body['playbackUrl']?.toString();
      if (playbackUrl == null || playbackUrl.isEmpty) {
        throw ApiException(500, 'Playback URL topilmadi');
      }
      return playbackUrl;
    } on SocketException {
      throw ApiException(
        503,
        'Video darslar uchun internet kerak. Ushbu bo‘lim oflayn ishlamaydi.',
      );
    }
  }

  static String _audioMimeTypeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) return 'audio/mp4';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.webm')) return 'audio/webm';
    if (lower.endsWith('.ogg') || lower.endsWith('.oga')) return 'audio/ogg';
    return 'audio/mp4';
  }

  static Future<Map<String, dynamic>?> exam(String accessToken) async {
    final response = await http.get(
      _uri('/api/exam'),
      headers: _jsonHeaders(accessToken: accessToken),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Imtihon ma’lumoti yuklanmadi',
      );
    }
    final exam = body['exam'];
    if (exam == null || exam is! Map) return null;
    return Map<String, dynamic>.from(exam);
  }

  static Future<Map<String, dynamic>> startExam({
    required String accessToken,
    required int count,
  }) async {
    final response = await http.post(
      _uri('/api/exam/start'),
      headers: _jsonHeaders(accessToken: accessToken),
      body: jsonEncode({'count': count}),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Imtihon boshlanmadi',
      );
    }
    final exam = body['exam'];
    if (exam is! Map) {
      throw ApiException(500, 'Imtihon javobi noto‘g‘ri');
    }
    return Map<String, dynamic>.from(exam);
  }

  static Future<Map<String, dynamic>> examProgress({
    required String accessToken,
    required Map<String, int> answers,
    bool finalize = false,
  }) async {
    final response = await http.post(
      _uri('/api/exam/progress'),
      headers: _jsonHeaders(accessToken: accessToken),
      body: jsonEncode({'answers': answers, 'finalize': finalize}),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Imtihon saqlanmadi',
      );
    }
    return body;
  }

  static Future<void> examReset(String accessToken) async {
    final response = await http.post(
      _uri('/api/exam/reset'),
      headers: _jsonHeaders(accessToken: accessToken),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Imtihonni qayta boshlash amalga oshmadi',
      );
    }
  }

  static Future<Map<String, dynamic>> answers({
    required String accessToken,
    int offset = 0,
    int limit = 40,
    String search = '',
    String filter = 'all',
  }) async {
    final params = <String, String>{
      'offset': '$offset',
      'limit': '$limit',
      'q': search,
      'filter': filter,
    };
    final uri = _uri('/api/answers', queryParameters: params);
    final cacheId = '$offset|$limit|$search|$filter';
    try {
      final response = await http.get(
        uri,
        headers: _jsonHeaders(accessToken: accessToken),
      );
      final body = _decodeBody(response);
      if (response.statusCode >= 400) {
        throw ApiException(
          response.statusCode,
          body['error']?.toString() ?? 'Savollar yuklanmadi',
        );
      }
      final rawQuestions = _mapsFromJsonList(body['questions']);
      if (rawQuestions.isNotEmpty) {
        await OfflineCacheStore.saveQuestions(
          kind: 'answers',
          id: cacheId,
          lang: _langParam(),
          questions: rawQuestions,
        );
      }
      return body;
    } on SocketException {
      final cached = await OfflineCacheStore.loadQuestions(
        kind: 'answers',
        id: cacheId,
        lang: _langParam(),
      );
      if (cached != null) {
        return <String, dynamic>{
          'questions': cached,
          'total': cached.length,
          'offset': offset,
          'limit': limit,
          'hasMore': false,
        };
      }
      rethrow;
    }
  }

  static Future<List<MistakeQuestion>> mistakes(String accessToken) async {
    final response = await http.get(
      _uri('/api/mistakes'),
      headers: _jsonHeaders(accessToken: accessToken),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Xatolar yuklanmadi',
      );
    }
    final rawQuestions = body['questions'];
    if (rawQuestions is! List) return const [];
    return rawQuestions
        .whereType<Map>()
        .map(
          (question) =>
              MistakeQuestion.fromJson(Map<String, dynamic>.from(question)),
        )
        .toList();
  }

  static Future<Map<String, dynamic>> mistakesProgress({
    required String accessToken,
    required Map<String, int> answers,
  }) async {
    final response = await http.post(
      _uri('/api/mistakes/progress'),
      headers: _jsonHeaders(accessToken: accessToken),
      body: jsonEncode({'answers': answers}),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Xatolar saqlanmadi',
      );
    }
    return body;
  }

  static Future<List<TopicQuestion>> ticketQuestions({
    required String accessToken,
    required String ticketId,
  }) async {
    final lang = _langParam();
    try {
      final response = await http.get(
        _uri('/api/tickets/$ticketId'),
        headers: _jsonHeaders(accessToken: accessToken),
      );
      final body = _decodeBody(response);
      if (response.statusCode >= 400) {
        throw ApiException(
          response.statusCode,
          body['error']?.toString() ?? 'Bilet yuklanmadi',
        );
      }
      final ticket = body['ticket'];
      if (ticket is! Map) {
        throw Exception('Noto‘g‘ri bilet javobi');
      }
      final questions = _mapsFromJsonList(ticket['questions']);
      if (questions.isNotEmpty) {
        await OfflineCacheStore.saveQuestions(
          kind: 'ticket',
          id: ticketId,
          lang: lang,
          questions: questions,
        );
      }
      return _mapModels(questions, TopicQuestion.fromJson);
    } on SocketException {
      final cached = await OfflineCacheStore.loadQuestions(
        kind: 'ticket',
        id: ticketId,
        lang: lang,
      );
      if (cached != null) return _mapModels(cached, TopicQuestion.fromJson);
      rethrow;
    }
  }

  static Future<List<TopicQuestion>> customTestQuestions({
    required String accessToken,
    required String testId,
  }) async {
    final lang = _langParam();
    try {
      final response = await http.get(
        _uri('/api/custom-tests/$testId'),
        headers: _jsonHeaders(accessToken: accessToken),
      );
      final body = _decodeBody(response);
      if (response.statusCode >= 400) {
        throw ApiException(
          response.statusCode,
          body['error']?.toString() ?? 'Sozlamali test yuklanmadi',
        );
      }
      final customTest = body['customTest'];
      if (customTest is! Map) {
        throw Exception('Noto‘g‘ri sozlamali test javobi');
      }
      final questions = _mapsFromJsonList(customTest['questions']);
      if (questions.isNotEmpty) {
        await OfflineCacheStore.saveQuestions(
          kind: 'custom-test',
          id: testId,
          lang: lang,
          questions: questions,
        );
      }
      return _mapModels(questions, TopicQuestion.fromJson);
    } on SocketException {
      final cached = await OfflineCacheStore.loadQuestions(
        kind: 'custom-test',
        id: testId,
        lang: lang,
      );
      if (cached != null) return _mapModels(cached, TopicQuestion.fromJson);
      rethrow;
    }
  }

  static Future<List<TopicQuestion>> topicQuestions({
    required String accessToken,
    required String topicId,
  }) async {
    final paths = <String>[
      '/api/topics/$topicId/questions',
      '/api/topics/$topicId/quiz',
      '/api/topics/$topicId',
    ];

    Object? lastErrorBody;
    final lang = _langParam();
    for (final path in paths) {
      try {
        final response = await http.get(
          _uri(path),
          headers: _jsonHeaders(accessToken: accessToken),
        );
        final body = _decodeBody(response);
        if (response.statusCode == 404) {
          lastErrorBody = body;
          continue;
        }
        if (response.statusCode >= 400) {
          throw ApiException(
            response.statusCode,
            body['error']?.toString() ?? 'Savollar yuklanmadi',
          );
        }

        final questions = _extractQuestionMaps(body);
        if (questions.isNotEmpty) {
          await OfflineCacheStore.saveQuestions(
            kind: 'topic',
            id: topicId,
            lang: lang,
            questions: questions,
          );
          return _mapModels(questions, TopicQuestion.fromJson);
        }
      } on SocketException {
        final cached = await OfflineCacheStore.loadQuestions(
          kind: 'topic',
          id: topicId,
          lang: lang,
        );
        if (cached != null) return _mapModels(cached, TopicQuestion.fromJson);
        rethrow;
      }
    }

    throw Exception(
      (lastErrorBody is Map && lastErrorBody['error'] != null
              ? lastErrorBody['error'].toString()
              : null) ??
          'Savollar topilmadi',
    );
  }

  static Future<void> saveTopicProgress({
    required String accessToken,
    required String topicId,
    required Map<String, int> answers,
  }) async {
    final response = await http.post(
      _uri('/api/topic-progress/$topicId'),
      headers: _jsonHeaders(accessToken: accessToken),
      body: jsonEncode({'answers': answers}),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Progress saqlanmadi',
      );
    }
  }

  static Future<TopicProgressSummary?> topicProgress({
    required String accessToken,
    required String topicId,
  }) async {
    final response = await http.get(
      _uri('/api/topic-progress/$topicId'),
      headers: _jsonHeaders(accessToken: accessToken),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Progress yuklanmadi',
      );
    }
    final progress = body['progress'];
    if (progress is! Map) return null;
    return TopicProgressSummary.fromJson(Map<String, dynamic>.from(progress));
  }

  static Future<void> saveTicketProgress({
    required String accessToken,
    required String ticketId,
    required Map<String, int> answers,
  }) async {
    final response = await http.post(
      _uri('/api/progress/$ticketId'),
      headers: _jsonHeaders(accessToken: accessToken),
      body: jsonEncode({'answers': answers}),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Progress saqlanmadi',
      );
    }
  }

  static Future<void> saveCustomTestProgress({
    required String accessToken,
    required String testId,
    required Map<String, int> answers,
  }) async {
    final response = await http.post(
      _uri('/api/custom-test-progress/$testId'),
      headers: _jsonHeaders(accessToken: accessToken),
      body: jsonEncode({'answers': answers}),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Progress saqlanmadi',
      );
    }
  }

  static List<Map<String, dynamic>> _extractQuestionMaps(
    Map<String, dynamic> body,
  ) {
    final candidates = <dynamic>[
      body['questions'],
      body['topic'] is Map ? (body['topic'] as Map)['questions'] : null,
      body['data'] is Map ? (body['data'] as Map)['questions'] : null,
      body['data'],
    ];

    for (final candidate in candidates) {
      final maps = _mapsFromJsonList(candidate);
      if (maps.isNotEmpty) return maps;
    }
    return const <Map<String, dynamic>>[];
  }

  static Map<String, dynamic> _decodeBody(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{'data': decoded};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
