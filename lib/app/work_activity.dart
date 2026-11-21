import 'package:flutter/foundation.dart';

import '../features/focus/focus_store.dart';
import '../features/planning/planning_engine.dart';
import '../features/planning/planning_store.dart';
import '../features/tasks/task_store.dart';

class WorkActivity {
  const WorkActivity({
    required this.tasks,
    required this.planning,
    required this.focus,
    required this.openCalendar,
    required this.openTask,
    required this.syncPersonal,
  });

  final TaskStore tasks;
  final PlanningStore planning;
  final FocusStore focus;
  final Future<void> Function() openCalendar, syncPersonal;
  final Future<void> Function(String id) openTask;

  Listenable get changes => Listenable.merge([tasks, planning, focus]);
  Iterable<({String date, PlanBlock block})> upcoming(Set<String> taskIds) =>
      planning.upcomingFor(_withSubtasks(taskIds));
  int focusSeconds(Set<String> taskIds) =>
      focus.recordedSecondsFor(_withSubtasks(taskIds));

  Set<String> _withSubtasks(Set<String> ids) => {
    ...ids,
    for (final id in ids) ...tasks.children(id).map((task) => task.id),
  };
}
