import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_constants.dart';
import '../models/auth_session.dart';
import '../models/mistake_question.dart';
import '../models/video_lesson.dart';
import '../models/topic_question.dart';
import '../models/topic_summary.dart';
import '../models/ticket_summary.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  static Map<String, String> _jsonHeaders({String? accessToken}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    return headers;
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
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/topics'),
      headers: _jsonHeaders(accessToken: accessToken),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Mavzular yuklanmadi',
      );
    }
    final rawTopics = body['topics'];
    if (rawTopics is! List) return const [];
    return rawTopics
        .whereType<Map>()
        .map((topic) => TopicSummary.fromJson(Map<String, dynamic>.from(topic)))
        .toList();
  }

  static Future<List<TicketSummary>> tickets(String accessToken) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/tickets'),
      headers: _jsonHeaders(accessToken: accessToken),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Biletlar yuklanmadi',
      );
    }
    final rawTickets = body['tickets'];
    if (rawTickets is! List) return const [];
    return rawTickets
        .whereType<Map>()
        .map(
          (ticket) => TicketSummary.fromJson(Map<String, dynamic>.from(ticket)),
        )
        .toList();
  }

  static Future<List<TicketSummary>> customTests(String accessToken) async {
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
    final rawTests = body['customTests'];
    if (rawTests is! List) return const [];
    return rawTests
        .whereType<Map>()
        .map((test) => TicketSummary.fromJson(Map<String, dynamic>.from(test)))
        .toList();
  }

  static Future<List<VideoLesson>> videos(String accessToken) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/video-lessons'),
      headers: _jsonHeaders(accessToken: accessToken),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Video darslar yuklanmadi',
      );
    }
    final rawVideos = body['videos'];
    if (rawVideos is! List) return const [];
    return rawVideos
        .whereType<Map>()
        .map((video) => VideoLesson.fromJson(Map<String, dynamic>.from(video)))
        .toList();
  }

  static Future<String> videoPlaybackUrl({
    required String accessToken,
    required String videoId,
  }) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/video-lessons/$videoId/playback'),
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
  }

  static Future<Map<String, dynamic>?> exam(String accessToken) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/exam'),
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
      Uri.parse('$apiBaseUrl/api/exam/start'),
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
      Uri.parse('$apiBaseUrl/api/exam/progress'),
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
      Uri.parse('$apiBaseUrl/api/exam/reset'),
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
    final uri = Uri.parse(
      '$apiBaseUrl/api/answers',
    ).replace(queryParameters: params);
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
    return body;
  }

  static Future<List<MistakeQuestion>> mistakes(String accessToken) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/mistakes'),
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
      Uri.parse('$apiBaseUrl/api/mistakes/progress'),
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
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/tickets/$ticketId'),
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
    final questions = ticket['questions'];
    if (questions is! List) return const [];
    return questions
        .whereType<Map>()
        .map(
          (question) =>
              TopicQuestion.fromJson(Map<String, dynamic>.from(question)),
        )
        .toList();
  }

  static Future<List<TopicQuestion>> customTestQuestions({
    required String accessToken,
    required String testId,
  }) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/custom-tests/$testId'),
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
    final questions = customTest['questions'];
    if (questions is! List) return const [];
    return questions
        .whereType<Map>()
        .map(
          (question) =>
              TopicQuestion.fromJson(Map<String, dynamic>.from(question)),
        )
        .toList();
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
    for (final path in paths) {
      final response = await http.get(
        Uri.parse('$apiBaseUrl$path'),
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

      final questions = _extractQuestions(body);
      if (questions.isNotEmpty) return questions;
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
      Uri.parse('$apiBaseUrl/api/topic-progress/$topicId'),
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

  static Future<void> saveTicketProgress({
    required String accessToken,
    required String ticketId,
    required Map<String, int> answers,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/api/progress/$ticketId'),
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
      Uri.parse('$apiBaseUrl/api/custom-test-progress/$testId'),
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

  static List<TopicQuestion> _extractQuestions(Map<String, dynamic> body) {
    final candidates = <dynamic>[
      body['questions'],
      body['topic'] is Map ? (body['topic'] as Map)['questions'] : null,
      body['data'] is Map ? (body['data'] as Map)['questions'] : null,
      body['data'],
    ];

    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<Map>()
            .map(
              (item) => TopicQuestion.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
    }
    return const <TopicQuestion>[];
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
