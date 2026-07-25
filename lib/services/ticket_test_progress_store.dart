import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TicketTestResult {
  const TicketTestResult({
    required this.correct,
    required this.wrong,
    required this.total,
    required this.unanswered,
    required this.percent,
    required this.updatedAt,
  });

  final int correct;
  final int wrong;
  final int total;
  final int unanswered;
  final int percent;
  final DateTime updatedAt;

  factory TicketTestResult.fromJson(Map<String, dynamic> json) {
    final total = (json['total'] as num?)?.toInt() ?? 0;
    final correct = (json['correct'] as num?)?.toInt() ?? 0;
    final wrong = (json['wrong'] as num?)?.toInt() ?? 0;
    return TicketTestResult(
      correct: correct,
      wrong: wrong,
      total: total,
      unanswered:
          (json['unanswered'] as num?)?.toInt() ??
          (total - correct - wrong).clamp(0, total).toInt(),
      percent: (json['percent'] as num?)?.toInt() ?? 0,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'correct': correct,
      'wrong': wrong,
      'total': total,
      'unanswered': unanswered,
      'percent': percent,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class TicketTestDraft {
  const TicketTestDraft({
    required this.questionOrderIds,
    required this.answersByQuestionId,
    required this.currentIndex,
    required this.completed,
    this.shuffleSeed,
  });

  final List<String> questionOrderIds;
  final Map<String, int> answersByQuestionId;
  final int currentIndex;
  final bool completed;
  final int? shuffleSeed;

  factory TicketTestDraft.fromJson(Map<String, dynamic> json) {
    final rawAnswers = json['answersByQuestionId'];
    final answers = <String, int>{};
    if (rawAnswers is Map) {
      rawAnswers.forEach((key, value) {
        final answer = (value as num?)?.toInt();
        if (answer != null) {
          answers[key.toString()] = answer;
        }
      });
    }

    final rawOrder = json['questionOrderIds'];
    final order = rawOrder is List
        ? rawOrder.map((item) => item.toString()).toList()
        : const <String>[];

    return TicketTestDraft(
      questionOrderIds: order,
      answersByQuestionId: answers,
      currentIndex: (json['currentIndex'] as num?)?.toInt() ?? 0,
      completed: json['completed'] == true,
      shuffleSeed: (json['shuffleSeed'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'questionOrderIds': questionOrderIds,
      'answersByQuestionId': answersByQuestionId,
      'currentIndex': currentIndex,
      'completed': completed,
      if (shuffleSeed != null) 'shuffleSeed': shuffleSeed,
    };
  }
}

class TicketTestProgress {
  const TicketTestProgress({this.draft, this.result});

  final TicketTestDraft? draft;
  final TicketTestResult? result;

  factory TicketTestProgress.fromJson(Map<String, dynamic> json) {
    final draft = json['draft'];
    final result = json['result'];
    return TicketTestProgress(
      draft: draft is Map
          ? TicketTestDraft.fromJson(Map<String, dynamic>.from(draft))
          : null,
      result: result is Map
          ? TicketTestResult.fromJson(Map<String, dynamic>.from(result))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (draft != null) 'draft': draft!.toJson(),
      if (result != null) 'result': result!.toJson(),
    };
  }
}

class TicketTestProgressStore {
  static const String _prefsKey = 'ticket_test_progress_store_v1';

  static Future<Map<String, TicketTestProgress>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return <String, TicketTestProgress>{};

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return <String, TicketTestProgress>{};

    final result = <String, TicketTestProgress>{};
    decoded.forEach((key, value) {
      if (value is Map) {
        result[key.toString()] = TicketTestProgress.fromJson(
          Map<String, dynamic>.from(value),
        );
      }
    });
    return result;
  }

  static Future<TicketTestProgress?> load(String ticketId) async {
    final all = await loadAll();
    return all[ticketId];
  }

  static Future<void> saveDraft({
    required String ticketId,
    required TicketTestDraft draft,
  }) async {
    final all = await loadAll();
    final existing = all[ticketId];
    all[ticketId] = TicketTestProgress(draft: draft, result: existing?.result);
    await _writeAll(all);
  }

  static Future<void> saveResult({
    required String ticketId,
    required TicketTestDraft draft,
    required TicketTestResult result,
  }) async {
    final all = await loadAll();
    all[ticketId] = TicketTestProgress(draft: draft, result: result);
    await _writeAll(all);
  }

  static Future<void> clearDraft(String ticketId) async {
    final all = await loadAll();
    final existing = all[ticketId];
    if (existing == null) return;
    all[ticketId] = TicketTestProgress(result: existing.result);
    await _writeAll(all);
  }

  static Future<void> clear(String ticketId) async {
    final all = await loadAll();
    if (!all.containsKey(ticketId)) return;
    all.remove(ticketId);
    await _writeAll(all);
  }

  static Future<void> _writeAll(Map<String, TicketTestProgress> values) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      for (final entry in values.entries) entry.key: entry.value.toJson(),
    };
    await prefs.setString(_prefsKey, jsonEncode(payload));
  }
}
