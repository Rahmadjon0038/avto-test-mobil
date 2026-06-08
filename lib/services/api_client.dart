import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_constants.dart';
import '../models/auth_session.dart';
import '../models/topic_question.dart';
import '../models/topic_summary.dart';
import '../models/ticket_summary.dart';

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
    required String fullName,
    required String phone,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/api/auth/register'),
      headers: _jsonHeaders(),
      body: jsonEncode({
        'fullName': fullName,
        'phone': phone,
        'password': password,
      }),
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

  static Future<AuthSession> refresh(String refreshToken) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/api/auth/refresh'),
      headers: {'Cookie': 'refresh_token=$refreshToken'},
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw Exception(body['error']?.toString() ?? 'Session yangilanmadi');
    }
    final accessToken = body['accessToken']?.toString();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Access token qaytmadi');
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

  static Future<List<TopicSummary>> topics(String accessToken) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/topics'),
      headers: _jsonHeaders(accessToken: accessToken),
    );
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      throw Exception(body['error']?.toString() ?? 'Mavzular yuklanmadi');
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
      throw Exception(body['error']?.toString() ?? 'Biletlar yuklanmadi');
    }
    final rawTickets = body['tickets'];
    if (rawTickets is! List) return const [];
    return rawTickets
        .whereType<Map>()
        .map((ticket) => TicketSummary.fromJson(Map<String, dynamic>.from(ticket)))
        .toList();
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
      throw Exception(body['error']?.toString() ?? 'Bilet yuklanmadi');
    }
    final ticket = body['ticket'];
    if (ticket is! Map) {
      throw Exception('Noto‘g‘ri bilet javobi');
    }
    final questions = ticket['questions'];
    if (questions is! List) return const [];
    return questions
        .whereType<Map>()
        .map((question) => TopicQuestion.fromJson(
              Map<String, dynamic>.from(question),
            ))
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
        throw Exception(
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
            .map((item) => TopicQuestion.fromJson(
                  Map<String, dynamic>.from(item),
                ))
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
