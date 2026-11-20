import '../planning/planning_engine.dart';
import '../planning/planning_store.dart';
import '../tasks/task_store.dart';

/// A planned task can have multiple slots on a date. Keep the exact slot
/// selected at setup, even when a later calendar revision moves the task.
class ScheduledFocus {
  const ScheduledFocus({
    required this.taskId,
    required this.date,
    required this.start,
    required this.end,
    this.timezone,
  });

  factory ScheduledFocus.fromBlock(
    PlanBlock block,
    String date,
    String? timezone,
  ) => ScheduledFocus(
    taskId: block.id,
    date: date,
    start: block.start,
    end: block.end,
    timezone: timezone,
  );

  factory ScheduledFocus.fromJson(Map<String, dynamic> json) => ScheduledFocus(
    taskId: json['taskId'] as String,
    date: json['date'] as String,
    start: json['start'] as int,
    end: json['end'] as int,
    timezone: json['timezone'] as String?,
  );

  final String taskId, date;
  final int start, end;
  final String? timezone;

  bool sameSlot(ScheduledFocus? other) =>
      other?.taskId == taskId &&
      other?.date == date &&
      other?.start == start &&
      other?.end == end &&
      other?.timezone == timezone;

  String get label =>
      '$date · ${intervalLabel(start, end)}'
      '${timezone == null ? '' : ' · $timezone'}';

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'date': date,
    'start': start,
    'end': end,
    if (timezone != null) 'timezone': timezone,
  };
}

class FocusTaskContext {
  const FocusTaskContext(this.tasks, this.plan);
  final TaskStore tasks;
  final PlanningStore plan;

  Task eligibleTask(ScheduledFocus slot) {
    final task = tasks.get(slot.taskId);
    if (task == null || task.skipped) {
      throw StateError('This scheduled task is no longer available.');
    }
    if (slot.timezone != plan.clock.zone() ||
        !plan
            .day(slot.date)
            .approved
            .any(
              (block) =>
                  block.kind == BlockKind.task &&
                  block.id == slot.taskId &&
                  block.start == slot.start &&
                  block.end == slot.end,
            )) {
      throw StateError(
        'This block changed. Go back to the plan and select the current slot.',
      );
    }
    final now = plan.localNow;
    final today = dayKey(now);
    if (slot.date.compareTo(today) < 0 ||
        (slot.date == today && slot.end <= now.hour * 60 + now.minute)) {
      throw StateError(
        'This block has ended. Choose another slot or start unassigned focus.',
      );
    }
    if (tasks.completed(task)) throw StateError('This task is already done.');
    if (tasks.children(task.id).isNotEmpty || !tasks.ready(task)) {
      throw StateError(
        'This task is blocked. Open Tasks to review its prerequisites and subtasks.',
      );
    }
    return task;
  }
}
