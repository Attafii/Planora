import 'dart:convert';

import 'package:http/http.dart' as http;

import 'task_store.dart';

class TaskAgent {
  static const _url = String.fromEnvironment(
    'TASK_AI_URL',
    defaultValue: 'http://localhost:5141',
  );

  Future<Map<String, dynamic>> propose(
    String kind,
    Map<String, Object?> input,
  ) async {
    final response = await http
        .post(
          Uri.parse('$_url/propose'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'kind': kind, ...input}),
        )
        .timeout(const Duration(seconds: 45));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw StateError(data['error'] as String? ?? 'AI unavailable.');
    }
    return data;
  }

  Future<List<String>> decompose(Task task, List<Task> steps) async {
    final result = await propose('decompose', {
      'title': task.title,
      'minutes': task.minutes,
      'existing': steps.take(20).map((step) => step.title).toList(),
    });
    return List<String>.from(result['steps'] as List);
  }

  Future<(String, String)> recommend(
    List<Task> eligible,
    int minutes,
    Energy energy,
  ) async {
    final result = await propose('next_action', {
      'minutes': minutes,
      'energy': energy.name,
      'candidates': eligible
          .map(
            (task) => {
              'id': task.id,
              'title': task.title,
              'minutes': task.minutes,
              'energy': task.energy.name,
              'due': task.due,
            },
          )
          .toList(),
    });
    return (result['id'] as String, result['reason'] as String);
  }
}
