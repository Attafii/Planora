import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Energy { low, medium, high }

enum ActivityType { general, work, study, movement, personal }

enum Repeat { once, daily, weekly }

String dayKey(DateTime day) => day.toIso8601String().substring(0, 10);

class Task {
  const Task({
    required this.id,
    required this.title,
    this.minutes = 25,
    this.activity = ActivityType.general,
    this.energy = Energy.medium,
    this.due,
    this.done = false,
    this.skipped = false,
    this.parent,
    this.requires = const [],
    this.repeat = Repeat.once,
    this.until,
    this.seriesId,
    this.occurrenceOverride = false,
  });

  factory Task.fromJson(Map<String, dynamic> row) => Task(
    id: row['id'] as String,
    title: row['title'] as String,
    activity:
        ActivityType.values
            .where((type) => type.name == row['activity'])
            .firstOrNull ??
        ActivityType.general,
    minutes: row['minutes'] as int,
    energy: Energy.values.byName(row['energy'] as String),
    due: row['due'] as String?,
    done: row['done'] as bool,
    skipped: row['skipped'] as bool,
    parent: row['parent'] as String?,
    requires: List<String>.from((row['requires'] as List?) ?? const [])
        .toSet()
        .toList(),
    repeat: Repeat.values.byName(row['repeat'] as String? ?? 'once'),
    until: row['until'] as String?,
    seriesId: row['seriesId'] as String?,
    occurrenceOverride: row['occurrenceOverride'] == true,
  );

  final String id, title;
  final int minutes;
  final Energy energy;
  final ActivityType activity;
  final String? due, parent, until, seriesId;
  final bool done, skipped, occurrenceOverride;
  final List<String> requires;
  final Repeat repeat;

  bool get occurrence => id.contains('@');

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'minutes': minutes,
    'energy': energy.name,
    'activity': activity.name,
    'due': due,
    'done': done,
    'skipped': skipped,
    'parent': parent,
    'requires': requires,
    'repeat': repeat.name,
    'until': until,
    'seriesId': seriesId,
    if (occurrenceOverride) 'occurrenceOverride': true,
  };

  Task patch(Map<String, dynamic> values) =>
      Task.fromJson({...toJson(), ...values});
}

class TaskStore extends ChangeNotifier {
  TaskStore(this._storage, {String? accountId})
    : _key = accountId == null
          ? 'planify.tasks.v1'
          : 'planify.tasks.v1.$accountId';
  final SharedPreferencesAsync _storage;
  final String _key;
  Map<String, Task> _saved = {};
  Future<void> _pending = Future.value();
  int _sequence = 0;
  int revision = 0;
  bool _disposed = false;
  Future<void> get settled => _pending;

  String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';

  Future<void> load() async {
    final value = await _storage.getString(_key);
    if (_disposed) return;
    _saved = value == null
        ? {}
        : {
            for (final json in jsonDecode(value) as List)
              (json as Map<String, dynamic>)['id'] as String: Task.fromJson(
                json,
              ),
          };
    revision++;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<Task> get skippedOccurrences =>
      _saved.values.where((task) => task.occurrence && task.skipped).toList()
        ..sort((a, b) => b.due!.compareTo(a.due!));

  List<Task> get prerequisites => _saved.values
      .where(
        (t) => t.repeat == Repeat.once && !t.occurrence && t.parent == null,
      )
      .toList();

  List<Task> get inbox {
    final today = DateTime.now();
    final first = DateTime.utc(today.year, today.month, today.day);
    return _taskList(first, -30, 60);
  }

  List<Task> forPlanningDate(String date) =>
      _taskList(DateTime.parse('${date}T00:00:00Z'), 0, 0);

  List<Task> _taskList(DateTime first, int from, int through) {
    final tasks = <String, Task>{
      for (final task in _saved.values)
        if (task.parent == null && task.repeat == Repeat.once) task.id: task,
    };
    for (final series in _saved.values.where((t) => t.repeat != Repeat.once)) {
      for (var offset = from; offset <= through; offset++) {
        final date = first.add(Duration(days: offset));
        if (!_occursOn(series, date)) continue;
        final key = dayKey(date);
        final id = '${series.seriesId ?? series.id}@$key';
        tasks.putIfAbsent(id, () => _occurrence(series, id, key));
      }
    }
    return tasks.values.where((t) => !t.skipped).toList()
      ..sort((a, b) => (a.due ?? '9999').compareTo(b.due ?? '9999'));
  }

  bool _occursOn(Task series, DateTime date) {
    final anchor = DateTime.tryParse('${series.due}T00:00:00Z');
    return anchor != null &&
        !date.isBefore(anchor) &&
        (series.until == null || dayKey(date).compareTo(series.until!) < 0) &&
        (series.repeat != Repeat.weekly ||
            date.difference(anchor).inDays % 7 == 0);
  }

  Task _occurrence(Task series, String id, String day) => series.patch({
    'id': id,
    'due': day,
    'repeat': Repeat.once.name,
    'until': null,
  });

  Task? get(String id) {
    final saved = _saved[id];
    if (saved != null || !id.contains('@')) return saved;
    final parts = id.split('@');
    if (parts.length != 2) return null;
    final date = DateTime.tryParse('${parts.last}T00:00:00Z');
    if (date == null || dayKey(date) != parts.last) return null;
    final series = _seriesAt(parts.first, date);
    return series == null ? null : _occurrence(series, id, parts.last);
  }

  Task? _seriesAt(String root, DateTime date) => _saved.values
      .where(
        (task) =>
            task.repeat != Repeat.once &&
            (task.seriesId ?? task.id) == root &&
            _occursOn(task, date),
      )
      .firstOrNull;
  List<Task> children(String id) =>
      _saved.values.where((t) => t.parent == id).toList();

  bool completed(Task task) => _completed(task, {});

  bool _completed(Task task, Map<String, bool> memo) {
    if (memo.containsKey(task.id)) return memo[task.id]!;
    // Treat a repeated visit as incomplete for cyclic legacy snapshots.
    memo[task.id] = false;
    if (task.skipped ||
        !task.requires.every((id) {
          final prerequisite = _saved[id];
          return prerequisite != null && _completed(prerequisite, memo);
        })) {
      return false;
    }
    final steps = children(task.id);
    return memo[task.id] = steps.isEmpty
        ? task.done
        : steps.every((step) => _completed(step, memo));
  }

  List<Task> blockers(Task task) => [
    for (final id in {...task.requires, ...?_saved[task.parent]?.requires})
      if (_saved[id] == null)
        Task(id: id, title: 'Unavailable prerequisite')
      else if (!completed(_saved[id]!))
        _saved[id]!,
  ];

  bool ready(Task task) {
    if (task.skipped || completed(task) || blockers(task).isNotEmpty) {
      return false;
    }
    final steps = children(task.id);
    return steps.isEmpty ||
        steps.any((step) => !completed(step) && blockers(step).isEmpty);
  }

  /// Actionable leaves in deterministic order. Earlier due dates win ties
  /// before best use of the available time and the stable task ID.
  List<Task> nextActions({
    required int minutes,
    required Energy energy,
    required String today,
  }) {
    final candidates = [
      for (final parent in inbox)
        if ((!parent.occurrence || parent.due!.compareTo(today) <= 0) &&
            ready(parent))
          for (final action
              in children(parent.id).isEmpty ? [parent] : children(parent.id))
            if (ready(action) &&
                action.minutes <= minutes &&
                action.energy.index <= energy.index)
              action,
    ];
    String due(Task task) => task.due ?? _saved[task.parent]?.due ?? '9999';
    return candidates..sort((a, b) {
      final deadline = due(a).compareTo(due(b));
      if (deadline != 0) return deadline;
      final fit = b.minutes.compareTo(a.minutes);
      return fit != 0 ? fit : a.id.compareTo(b.id);
    });
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
      if (!_disposed) notifyListeners();
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
      for (final target in task.requires) {
        if (!tasks.containsKey(target) &&
            (_saved[id]?.requires.contains(target) ?? false)) {
          continue;
        }
        visit(target);
      }
      for (final child in childIds[id] ?? const <String>[]) {
        visit(child);
      }
      active.remove(id);
      visited.add(id);
    }

    for (final id in tasks.keys) {
      visit(id);
    }
  }

  Future<void> save(Task task, {bool future = false, int? expectedRevision}) =>
      _write((next) {
        if (expectedRevision != null && expectedRevision != revision) {
          throw StateError(
            'Tasks changed while this editor was open. Copy your changes and reopen the task.',
          );
        }
        if (!future) {
          final current = get(task.id);
          if (task.occurrence && current == null) {
            throw StateError('This occurrence has changed. Reopen the task.');
          }
          next[task.id] = task.occurrence
              ? task.patch({
                  'due': current!.due,
                  'done': current.done,
                  'skipped': current.skipped,
                  'occurrenceOverride': true,
                })
              : task;
          return;
        }
        final parts = task.id.split('@');
        final date = DateTime.tryParse('${parts.last}T00:00:00Z');
        final previous = parts.length == 2 && date != null
            ? _seriesAt(parts.first, date)
            : null;
        if (previous == null) {
          throw StateError('This series has changed. Reopen the occurrence.');
        }
        next[previous.id] = previous.patch({'until': parts.last});
        final id = task.id.replaceFirst('@', ':segment:');
        for (final entry in next.entries.toList()) {
          final item = entry.value;
          if (item.occurrence &&
              item.id.startsWith('${parts.first}@') &&
              item.due!.compareTo(parts.last) >= 0 &&
              (previous.until == null ||
                  item.due!.compareTo(previous.until!) < 0) &&
              !item.skipped &&
              !item.done &&
              !completed(item) &&
              !(children(item.id).isNotEmpty &&
                  children(item.id).every((step) => step.done)) &&
              (item.id == task.id ||
                  (!item.occurrenceOverride &&
                      !_differsFromSeries(item, previous)))) {
            next[entry.key] = item.patch({
              'title': task.title,
              'minutes': task.minutes,
              'energy': task.energy.name,
              'activity': task.activity.name,
              'requires': task.requires,
              'occurrenceOverride': false,
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
          'due': parts.last,
          'occurrenceOverride': false,
        });
      });

  bool _differsFromSeries(Task occurrence, Task series) =>
      occurrence.title != series.title ||
      occurrence.minutes != series.minutes ||
      occurrence.energy != series.energy ||
      occurrence.activity != series.activity ||
      !setEquals(occurrence.requires.toSet(), series.requires.toSet());

  Future<void> restoreOccurrence(String id) => _write((next) {
    final current = next[id];
    if (current != null && current.occurrence && current.skipped) {
      next[id] = current.patch({'skipped': false});
    }
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
      final current = get(task.id);
      if (current != null) next[task.id] = current.patch({'skipped': true});
      return;
    }
    final removed = {task.id, ...children(task.id).map((child) => child.id)};
    if (next.values.any(
      (item) =>
          !removed.contains(item.id) && item.requires.any(removed.contains),
    )) {
      throw StateError(
        'Remove this prerequisite from dependent tasks before deleting it.',
      );
    }
    next.removeWhere((id, _) => removed.contains(id));
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
    final unique = children(current.id)
        .map((task) => task.title.trim().toLowerCase())
        .toSet();
    if (titles.any((title) => !unique.add(title.trim().toLowerCase()))) {
      throw StateError('Use a different title for each subtask.');
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
        activity: current.activity,
      );
    }
  });
}
