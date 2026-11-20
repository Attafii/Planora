import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tasks/task_store.dart';
import 'planning_engine.dart';

class DayPlan {
  const DayPlan({
    this.workday = (start: 540, end: 1020),
    this.reserved = const [
      PlanBlock('lunch', 'Lunch', 720, 780, BlockKind.pause),
    ],
    this.approved = const [],
    this.history = const [],
    this.version = 0,
  });

  factory DayPlan.fromJson(Map<String, dynamic> json) => DayPlan(
    workday: (start: json['start'] as int, end: json['end'] as int),
    reserved: parseBlocks(json['reserved']),
    approved: parseBlocks(json['approved']),
    history: (json['history'] as List).cast<Map<String, dynamic>>(),
    version: json['version'] as int,
  );

  final Minutes workday;
  final List<PlanBlock> reserved, approved;
  final List<Map<String, dynamic>> history;
  final int version;

  Map<String, dynamic> toJson() => {
    'start': workday.start,
    'end': workday.end,
    'version': version,
    'reserved': reserved.map((block) => block.toJson()).toList(),
    'approved': approved.map((block) => block.toJson()).toList(),
    'history': history,
  };
}

List<PlanBlock> parseBlocks(Object? data) => (data as List)
    .map((item) => PlanBlock.fromJson(item as Map<String, dynamic>))
    .toList();

class PlanDraft {
  const PlanDraft({
    required this.day,
    required this.version,
    required this.taskVersion,
    required this.cutoff,
    required this.workday,
    required this.reserved,
    required this.result,
    required this.reason,
    this.interruptionId,
  });
  final String day, reason;
  final int version, taskVersion, cutoff;
  final Minutes workday;
  final List<PlanBlock> reserved;
  final ScheduleResult result;
  final String? interruptionId;
}

class PlanningStore extends ChangeNotifier {
  PlanningStore(
    this.storage,
    this.tasks, {
    DateTime Function()? now,
    String? accountId,
  }) : _now = now ?? DateTime.now,
       _key = accountId == null
           ? 'planify.planning.v1'
           : 'planify.planning.v1.$accountId';

  final SharedPreferencesAsync storage;
  final TaskStore tasks;
  final DateTime Function() _now;
  final String _key;
  Map<String, DayPlan> _days = {};
  Future<void> _pending = Future.value();
  bool _disposed = false;
  Future<void> get settled => _pending;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  DayPlan day(String date) => _days[date] ?? const DayPlan();

  List<PlanBlock> calendarEntries(String date) {
    final plan = _days[date];
    if (plan == null) return const [];
    return [...plan.approved, ...plan.reserved]
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  Future<void> load() async {
    final stored = await storage.getString(_key);
    if (_disposed) return;
    _days = stored == null
        ? {}
        : (jsonDecode(stored) as Map<String, dynamic>).map(
            (key, value) =>
                MapEntry(key, DayPlan.fromJson(value as Map<String, dynamic>)),
          );
    notifyListeners();
  }

  int cutoffFor(String date) {
    final now = _now();
    final comparison = date.compareTo(dayKey(now));
    if (comparison < 0) return 1440;
    if (comparison > 0) return 0;
    return math.min(1440, now.hour * 60 + now.minute + 1);
  }

  Future<void> _save(String date, DayPlan Function(DayPlan) update) {
    final write = _pending.then((_) async {
      final next = {..._days, date: update(day(date))};
      await storage.setString(
        _key,
        jsonEncode(next.map((k, v) => MapEntry(k, v.toJson()))),
      );
      _days = next;
      if (!_disposed) notifyListeners();
    });
    _pending = write.then<void>(
      (_) {},
      onError: (Object _, StackTrace stack) {},
    );
    return write;
  }

  static void validate(Minutes interval) {
    if (interval.start < 0 ||
        interval.end > 1440 ||
        interval.end <= interval.start) {
      throw StateError('Choose a valid time range within one day.');
    }
  }

  PlanDraft preview(
    String date, {
    Minutes? workday,
    PlanBlock? constraint,
    Interruption? interruption,
    List<PlanBlock>? reservedOverride,
  }) {
    final current = day(date);
    final hours = workday ?? current.workday;
    validate(hours);
    if (constraint != null) validate(constraint.interval);
    final now = cutoffFor(date);
    if (now >= 1440) throw StateError('Choose today or a future date to plan.');
    if (interruption != null) {
      validate((start: interruption.start, end: interruption.end));
      if (current.history.any(
        (entry) => entry['interruptionId'] == interruption.id,
      )) {
        throw StateError('This interruption has already been applied.');
      }
    }
    final cutoff = interruption?.start ?? now;
    final reserved = [
      ...(reservedOverride ?? current.reserved),
      ?constraint,
      if (interruption != null)
        PlanBlock(
          interruption.id,
          'Interruption',
          interruption.start,
          interruption.end,
          BlockKind.unavailable,
        ),
    ];
    final candidates = [
      for (final parent in tasks.forPlanningDate(date))
        if (!parent.occurrence || parent.due == date)
          for (final task
              in tasks.children(parent.id).isEmpty
                  ? [parent]
                  : tasks.children(parent.id))
            if (!tasks.completed(task) || tasks.blockers(task).isNotEmpty)
              PlanningTask(
                task.id,
                task.title,
                task.minutes,
                task.due ?? parent.due,
                tasks.blockers(task).map((blocker) => blocker.title).toList(),
              ),
    ];
    return PlanDraft(
      day: date,
      version: current.version,
      taskVersion: tasks.revision,
      cutoff: cutoff,
      workday: hours,
      reserved: List.unmodifiable(reserved),
      result: const PlanningEngine().compute(
        tasks: candidates,
        previous: current.approved,
        commitments: reserved
            .where((block) => block.id != interruption?.id)
            .toList(),
        workday: hours,
        cutoff: cutoff,
        interruption: interruption,
        previousCommitments: current.reserved,
        earliest: math.max(now, cutoff),
      ),
      reason: interruption != null
          ? 'Interruption'
          : workday != null || constraint != null || reservedOverride != null
          ? 'Scheduling request'
          : 'Schedule generation',
      interruptionId: interruption?.id,
    );
  }

  bool isStale(PlanDraft draft) {
    final current = day(draft.day);
    final now = cutoffFor(draft.day);
    return draft.version != current.version ||
        draft.taskVersion != tasks.revision ||
        now >= 1440 ||
        draft.result.blocks.any(
          (block) =>
              block.start >= draft.cutoff &&
              block.start < now &&
              !current.approved.any(
                (previous) =>
                    previous.id == block.id &&
                    previous.start == block.start &&
                    previous.end == block.end,
              ),
        );
  }

  Future<void> approve(PlanDraft draft) => _save(draft.day, (current) {
    if (isStale(draft)) {
      throw StateError(
        'The schedule or tasks changed. Generate a fresh preview.',
      );
    }
    return DayPlan(
      workday: draft.workday,
      reserved: draft.reserved,
      approved: draft.result.blocks,
      version: current.version + 1,
      history: [
        ...current.history,
        {
          'revision': current.version + 1,
          'reason': draft.reason,
          'time': _now().toIso8601String(),
          'interruptionId': draft.interruptionId,
          'changes': draft.result.changes
              .map(
                (change) => {
                  'id': change.id,
                  'title': change.title,
                  'kind': change.kind.name,
                  'before': change.before,
                  'after': change.after,
                  'reason': change.reason,
                },
              )
              .toList(),
        },
      ],
    );
  });
}
