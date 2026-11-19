import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Energy { low, medium, high }

enum Repeat { once, daily, weekly }

String dayKey(DateTime day) => day.toIso8601String().substring(0, 10);

class Task {
  const Task({
    required this.id,
    required this.title,
    this.minutes = 25,
    this.energy = Energy.medium,
    this.due,
    this.done = false,
    this.skipped = false,
    this.parent,
    this.requires = const [],
    this.repeat = Repeat.once,
    this.until,
    this.seriesId,
  });

  factory Task.fromJson(Map<String, dynamic> row) => Task(
    id: row['id'] as String,
    title: row['title'] as String,
    minutes: row['minutes'] as int,
    energy: Energy.values.byName(row['energy'] as String),
    due: row['due'] as String?,
    done: row['done'] as bool,
    skipped: row['skipped'] as bool,
    parent: row['parent'] as String?,
    requires: List<String>.from(row['requires'] as List),
    repeat: Repeat.values.byName(row['repeat'] as String),
    until: row['until'] as String?,
    seriesId: row['seriesId'] as String?,
  );

  final String id, title;
  final int minutes;
  final Energy energy;
  final String? due, parent, until, seriesId;
  final bool done, skipped;
  final List<String> requires;
  final Repeat repeat;

  bool get occurrence => id.contains('@');

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'minutes': minutes,
    'energy': energy.name,
    'due': due,
    'done': done,
    'skipped': skipped,
    'parent': parent,
    'requires': requires,
    'repeat': repeat.name,
    'until': until,
    'seriesId': seriesId,
  };

  Task patch(Map<String, dynamic> values) =>
      Task.fromJson({...toJson(), ...values});
}

class TaskStore extends ChangeNotifier {
  TaskStore(this._storage);
  final SharedPreferencesAsync _storage;
  static const _key = 'planify.tasks.v1';
  Map<String, Task> _saved = {};
  Future<void> _pending = Future.value();
  int _sequence = 0;
  int revision = 0;

  String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';

  Future<void> load() async {
    final value = await _storage.getString(_key);
    if (value == null) return;
    _saved = {
      for (final json in jsonDecode(value) as List)
        (json as Map<String, dynamic>)['id'] as String: Task.fromJson(json),
    };
    notifyListeners();
  }

  List<Task> get prerequisites => _saved.values
      .where(
        (t) => t.repeat == Repeat.once && !t.occurrence && t.parent == null,
      )
      .toList();

  List<Task> get inbox {
    final today = DateTime.now();
    final first = DateTime.utc(today.year, today.month, today.day);
    final tasks = <String, Task>{
      for (final task in _saved.values)
        if (task.parent == null && task.repeat == Repeat.once) task.id: task,
    };
    for (final series in _saved.values.where((t) => t.repeat != Repeat.once)) {
      final anchor = DateTime.parse('${series.due}T00:00:00Z');
      for (var offset = -30; offset <= 60; offset++) {
        final date = first.add(Duration(days: offset));
        final key = dayKey(date);
        if (date.isBefore(anchor) ||
            (series.until != null && key.compareTo(series.until!) >= 0)) {
          continue;
        }
        if (series.repeat == Repeat.weekly &&
            date.difference(anchor).inDays % 7 != 0) {
          continue;
        }
        final id = '${series.seriesId ?? series.id}@$key';
        tasks.putIfAbsent(
          id,
          () => series.patch({
            'id': id,
            'due': key,
            'repeat': Repeat.once.name,
            'until': null,
          }),
        );
      }
    }
    return tasks.values.where((t) => !t.skipped).toList()
      ..sort((a, b) => (a.due ?? '9999').compareTo(b.due ?? '9999'));
  }

  Task? get(String id) =>
      _saved[id] ?? inbox.where((t) => t.id == id).firstOrNull;
  List<Task> children(String id) =>
      _saved.values.where((t) => t.parent == id).toList();

  bool completed(Task task) => _completed(task, {});
  bool _completed(Task task, Map<String, bool> memo) {
    return memo.putIfAbsent(task.id, () {
      if (task.skipped ||
          !task.requires.every((id) {
            final prerequisite = _saved[id];
            return prerequisite != null && _completed(prerequisite, memo);
          })) {
        return false;
      }
      final steps = children(task.id);
      return steps.isEmpty
          ? task.done
          : steps.every((t) => _completed(t, memo));
    });
  }

  List<Task> blockers(Task task) => [
    for (final id in {...task.requires, ...?_saved[task.parent]?.requires})
      if (_saved[id] case final Task requiredTask)
        if (!completed(requiredTask)) requiredTask,
  ];

  bool ready(Task task) {
    if (task.skipped || completed(task) || blockers(task).isNotEmpty) {
      return false;
    }
    final steps = children(task.id);
    return steps.isEmpty ||
        steps.any((step) => !completed(step) && blockers(step).isEmpty);
  }

  double progress(Task task) {
    final steps = children(task.id);
    return steps.isEmpty
        ? (completed(task) ? 1 : 0)
        : steps
                  .where((step) => completed(step) && blockers(step).isEmpty)
                  .length /
              steps.length;
  }

  Future<void> _write(void Function(Map<String, Task>) change) {
    final result = _pending.then((_) async {
      final next = {..._saved};
      change(next);
      _validateGraph(next);
      await _storage.setString(
        _key,
        jsonEncode(next.values.map((t) => t.toJson()).toList()),
      );
      _saved = next;
      revision++;
      notifyListeners();
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _validateGraph(Map<String, Task> tasks) {
    final childIds = <String, List<String>>{};
    for (final task in tasks.values) {
      if (task.parent != null) (childIds[task.parent!] ??= []).add(task.id);
    }
    final active = <String>{};
    final visited = <String>{};
    void visit(String id) {
      if (visited.contains(id)) return;
      if (!active.add(id)) {
        throw StateError('These prerequisites create a cycle.');
      }
      final task = tasks[id];
      if (task == null) throw StateError('A prerequisite no longer exists.');
      for (final target in [...task.requires, ...?childIds[id]]) {
        visit(target);
      }
      active.remove(id);
      visited.add(id);
    }

    for (final id in tasks.keys) {
      visit(id);
    }
  }

  Future<void> save(Task task, {bool future = false}) => _write((next) {
    if (!future) {
      next[task.id] = task;
      return;
    }
    final parts = task.id.split('@');
    final previous = next.values
        .where(
          (entry) =>
              entry.repeat != Repeat.once &&
              (entry.seriesId ?? entry.id) == parts.first &&
              entry.due!.compareTo(parts.last) <= 0 &&
              (entry.until == null || parts.last.compareTo(entry.until!) < 0),
        )
        .firstOrNull;
    if (previous == null ||
        previous.repeat == Repeat.once ||
        (previous.until != null &&
            parts.last.compareTo(previous.until!) >= 0)) {
      throw StateError('This series has changed. Reopen the occurrence.');
    }
    next[previous.id] = previous.patch({'until': parts.last});
    final id = newId();
    for (final entry in next.entries.toList()) {
      final item = entry.value;
      if (item.occurrence &&
          item.id.startsWith('${parts.first}@') &&
          item.due!.compareTo(parts.last) >= 0 &&
          (previous.until == null ||
              item.due!.compareTo(previous.until!) < 0) &&
          !item.skipped &&
          !completed(item)) {
        next[entry.key] = item.patch({
          'title': task.title,
          'minutes': task.minutes,
          'energy': task.energy.name,
          'requires': task.requires,
        });
      }
    }
    next[id] = task.patch({
      'id': id,
      'repeat': previous.repeat.name,
      'done': false,
      'skipped': false,
      'until': previous.until,
      'seriesId': parts.first,
    });
  });

  Future<void> toggle(Task task) => _write((next) {
    final current = get(task.id);
    if (current == null ||
        children(task.id).isNotEmpty ||
        blockers(current).isNotEmpty) {
      throw StateError('Complete the prerequisites or subtasks first.');
    }
    next[task.id] = current.patch({'done': !current.done});
  });

  Future<void> remove(Task task) => _write((next) {
    if (task.occurrence) {
      next[task.id] = task.patch({'skipped': true});
      return;
    }
    if (next.values.any((item) => item.requires.contains(task.id))) {
      throw StateError(
        'Remove this prerequisite from dependent tasks before deleting it.',
      );
    }
    next.remove(task.id);
    next.removeWhere((_, item) => item.parent == task.id);
  });

  Future<void> addSteps(
    Task parent,
    List<String> titles, {
    int? expectedRevision,
  }) => _write((next) {
    if (expectedRevision != null && expectedRevision != revision) {
      throw StateError(
        'Tasks changed while this draft was open. Generate it again.',
      );
    }
    final current = get(parent.id);
    if (current == null || current.skipped || current.parent != null) {
      throw StateError('Task unavailable.');
    }
    if (titles.isEmpty ||
        titles.any((title) => title.trim().isEmpty || title.length > 120)) {
      throw StateError('Enter a title of up to 120 characters for each step.');
    }
    next[parent.id] = current.patch({'done': false});
    for (final title in titles) {
      final id = newId();
      next[id] = Task(
        id: id,
        title: title.trim(),
        parent: parent.id,
        minutes: (current.minutes / titles.length).ceil(),
        energy: current.energy,
      );
    }
  });
}
