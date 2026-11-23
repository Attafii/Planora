import '../../core/services/app_session.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'planning_engine.dart';
import 'planning_store.dart';

class PlanningAgent {
  const PlanningAgent({this.session, this.accountId});
  final AppSession? session;
  final String? accountId;
  bool get cloudAiEnabled =>
      session == null || session?.account?.cloudAi == true;
  static const _url = String.fromEnvironment(
    'TASK_AI_URL',
    defaultValue: 'http://localhost:5141',
  );

  Future<Map<String, dynamic>> _request(Map<String, Object?> payload) async {
    final account = session;
    if (account != null) {
      if (accountId != null && account.account?.id != accountId) {
        throw const ApiFailure(AppSession.ended, status: 401);
      }
      if (!cloudAiEnabled) {
        throw const ApiFailure(
          'Cloud AI is off. Enable it in Privacy to interpret requests.',
          status: 403,
        );
      }
      return account.request('POST', '/agents/planning', payload);
    }
    final response = await http
        .post(
          Uri.parse('$_url/planning/propose'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 40));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw StateError(
        data['error'] as String? ?? 'Planning AI is unavailable.',
      );
    }
    return data;
  }

  Future<({String kind, Minutes? interval, String? question})> interpret(
    String input,
    String date,
    Minutes hours,
    int cutoff, {
    String? timezone,
  }) async {
    final data = await _request({
      'kind': 'interpret',
      'input': input,
      'date': date,
      'cutoff': cutoff,
      'timezone': ?timezone,
      'workday': {'start': hours.start, 'end': hours.end},
    });
    final kind = data['kind'] as String;
    if (kind == 'clarify') {
      return (kind: kind, interval: null, question: data['question'] as String);
    }
    if (kind != 'unavailable' && kind != 'workday') {
      throw StateError(
        'The planning assistant returned an unsupported constraint.',
      );
    }
    final interval = (start: data['start'] as int, end: data['end'] as int);
    PlanningStore.validate(interval);
    return (kind: kind, interval: interval, question: null);
  }

  Future<List<({PlanChange change, String text})>> explain(
    PlanDraft draft,
  ) async {
    final changes = draft.result.changes.take(60).toList();
    final data = await _request({
      'kind': 'explain',
      'date': draft.day,
      'changes': [
        for (var i = 0; i < changes.length; i++)
          {
            'id': i,
            'title': changes[i].title,
            'status': changes[i].kind.name,
            'before': changes[i].before,
            'after': changes[i].after,
            'reason': changes[i].reason,
          },
      ],
    });
    return [
      for (final row in data['items'] as List)
        (change: changes[row['id'] as int], text: row['text'] as String),
    ];
  }
}
