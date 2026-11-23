import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tasks/task_store.dart';
import 'calendar_clock.dart';
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
    this.windows = const {},
  });

  factory DayPlan.fromJson(Map<String, dynamic> json) => DayPlan(
    workday: (start: json['start'] as int, end: json['end'] as int),
    reserved: parseBlocks(json['reserved']),
    approved: parseBlocks(json['approved']),
    history: (json['history'] as List).cast<Map<String, dynamic>>(),
    version: json['version'] as int,
    windows: parseWindows(json['windows']),
  );

  final Minutes workday;
  final List<PlanBlock> reserved, approved;
  final List<Map<String, dynamic>> history;
  final int version;
  final Map<String, Minutes> windows;

  Map<String, dynamic> snapshot() => {
    'start': workday.start,
    'end': workday.end,
    'version': version,
    'reserved': reserved.map((block) => block.toJson()).toList(),
    'approved': approved.map((block) => block.toJson()).toList(),
    if (windows.isNotEmpty) 'windows': encodeWindows(windows),
  };

  Map<String, dynamic> toJson() => {...snapshot(), 'history': history};
}

List<PlanBlock> parseBlocks(Object? data) => (data as List)
    .map((item) => PlanBlock.fromJson(item as Map<String, dynamic>))
    .toList();

Map<String, Minutes> parseWindows(Object? value) => {
  if (value is Map)
    for (final entry in value.entries)
      entry.key as String: (
        start: entry.value['start'] as int,
        end: entry.value['end'] as int,
      ),
};

Map<String, Map<String, int>> encodeWindows(Map<String, Minutes> windows) => {
  for (final entry in windows.entries)
    entry.key: {'start': entry.value.start, 'end': entry.value.end},
};

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
    required this.base,
    required this.generation,
    required this.zone,
    required this.windows,
    this.interruption,
    this.preferred = const [],
  });
  final String day, reason;
  final int version, taskVersion, cutoff;
  final Minutes workday;
  final List<PlanBlock> reserved;
  final ScheduleResult result;
  final DayPlan base;
  final int generation;
  final String? zone;
  final Map<String, Minutes> windows;
  final Interruption? interruption;
  final List<PlanBlock> preferred;
  String? get interruptionId => interruption?.id;
}

class PlanningStore extends ChangeNotifier {
  PlanningStore(
    this.storage,
    this.tasks, {
    DateTime Function()? now,
    String? accountId,
    String? Function()? timezone,
  }) : clock = CalendarClock(timezone ?? (() => null)),
       _now = now ?? DateTime.now,
       _key = accountId == null
           ? 'planify.planning.v1'
           : 'planify.planning.v1.$accountId';

  final SharedPreferencesAsync storage;
  final TaskStore tasks;
  final CalendarClock clock;
  int _generation = 0;
  DateTime get localNow => clock.local(_now());
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
    return [...visibleApproved(date), ...plan.reserved]
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  Iterable<PlanBlock> visibleApproved(String date) => day(date).approved.where(
    (block) => !isSharedTaskKey(block.id) || tasks.get(block.id) != null,
  );

  Iterable<({String date, PlanBlock block})> upcomingFor(
    Set<String> ids,
  ) sync* {
    final dates = _days.keys.toList()..sort();
    for (final date in dates) {
      final cutoff = cutoffFor(date);
      for (final block in visibleApproved(date)) {
        if (block.end > cutoff && ids.contains(block.id)) {
          yield (date: date, block: block);
        }
      }
    }
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
    _generation++;
    notifyListeners();
  }

  int cutoffFor(String date) {
    final now = localNow;
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

  List<PlanningTask> candidatesFor(String date) {
    return [
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
  }

  List<({String title, String reason})> unscheduled(String date) {
    final current = day(date);
    final changes = {
      if (current.history.isNotEmpty)
        for (final change in current.history.last['changes'] as List)
          change['id']: change,
    };
    final placed = current.approved.map((block) => block.id).toSet();
    return [
      for (final task in candidatesFor(date))
        if (!placed.contains(task.id) ||
            changes[task.id]?['kind'] == 'deferred')
          (
            title: task.title,
            reason: task.blockers.isNotEmpty
                ? 'Complete ${task.blockers.join(', ')} first.'
                : changes[task.id]?['kind'] == 'deferred'
                ? changes[task.id]['reason'] as String
                : 'No approved time on this date.',
          ),
    ];
  }

  void validateInterval(String date, Minutes interval) {
    validate(interval);
    clock.validateZone();
    if (clock.unavailable(date).any((time) => _overlap(time, interval))) {
      throw StateError(
        'Choose times outside skipped or repeated hours on this date.',
      );
    }
  }

  static bool _overlap(Minutes a, Minutes b) =>
      a.start < b.end && b.start < a.end;

  static bool _sameBlock(PlanBlock? a, PlanBlock? b) =>
      a?.id == b?.id &&
      a?.title == b?.title &&
      a?.interval == b?.interval &&
      a?.kind == b?.kind;

  PlanDraft preview(
    String date, {
    Minutes? workday,
    PlanBlock? constraint,
    Interruption? interruption,
    List<PlanBlock>? reservedOverride,
    Map<String, Minutes>? windowsOverride,
    List<PlanBlock> preferred = const [],
    String? reason,
  }) {
    CalendarClock.validateDate(date);
    clock.validateZone();
    final current = day(date);
    final hours = workday ?? current.workday;
    validate(hours);
    final unavailable = clock.unavailable(date);
    if (unavailable.any(
      (interval) =>
          (interval.start <= hours.start && hours.start < interval.end) ||
          (interval.start < hours.end && hours.end < interval.end),
    )) {
      throw StateError(
        'Working hours must start and end outside skipped or repeated time.',
      );
    }
    final now = cutoffFor(date);
    if (now >= 1440) throw StateError('Choose today or a future date to plan.');
    if (interruption != null) {
      validateInterval(date, (
        start: interruption.start,
        end: interruption.end,
      ));
      if (current.history.any(
        (entry) => entry['interruptionId'] == interruption.id,
      )) {
        throw StateError('This interruption has already been applied.');
      }
    }
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
    final ids = <String>{};
    final oldReserved = {for (final block in current.reserved) block.id: block};
    for (final block in reserved) {
      if (!ids.add(block.id)) {
        throw StateError('Reserved time appears twice in this proposal.');
      }
      if (_sameBlock(block, oldReserved[block.id])) continue;
      validateInterval(date, block.interval);
      final isInterruption =
          block.id == interruption?.id ||
          current.history.any((entry) => entry['interruptionId'] == block.id);
      if (isInterruption) continue;
      if (block.start < now) {
        throw StateError('Reserve a time from now onward.');
      }
      final overlap = reserved
          .where(
            (other) =>
                other.id != block.id &&
                _overlap(other.interval, block.interval),
          )
          .firstOrNull;
      if (overlap != null) {
        throw StateError(
          'This time overlaps ${overlap.title}. Choose a different interval.',
        );
      }
    }
    for (final previous in current.reserved) {
      if (previous.start < now &&
          !reserved.any((block) => _sameBlock(block, previous))) {
        throw StateError(
          'Reserved time that has already started cannot be changed.',
        );
      }
    }
    final windows = windowsOverride ?? current.windows;
    for (final window in windows.entries) {
      if (window.value != current.windows[window.key]) {
        validateInterval(date, window.value);
      }
    }
    final completedIds = {
      for (final block in current.approved)
        if (tasks.get(block.id) case final task?)
          if (tasks.completed(task)) block.id,
    };
    return PlanDraft(
      day: date,
      version: current.version,
      taskVersion: tasks.revision,
      cutoff: now,
      base: current,
      generation: _generation,
      zone: clock.zone(),
      windows: Map.unmodifiable(windows),
      preferred: List.unmodifiable(preferred),
      workday: hours,
      reserved: List.unmodifiable(reserved),
      result: const PlanningEngine().compute(
        tasks: candidatesFor(date),
        previous: current.approved,
        commitments: reserved
            .where((block) => block.id != interruption?.id)
            .toList(),
        workday: hours,
        cutoff: now,
        interruption: interruption,
        previousCommitments: current.reserved,
        unavailable: unavailable,
        windows: windows,
        preferred: preferred,
        completedIds: completedIds,
      ),
      reason:
          reason ??
          (interruption != null
              ? 'Interruption'
              : workday != null ||
                    constraint != null ||
                    reservedOverride != null ||
                    windowsOverride != null
              ? 'Scheduling request'
              : 'Schedule generation'),
      interruption: interruption,
    );
  }

  bool isStale(PlanDraft draft) {
    final current = day(draft.day);
    final now = cutoffFor(draft.day);
    if (draft.generation != _generation ||
        draft.zone != clock.zone() ||
        draft.version != current.version ||
        draft.taskVersion != tasks.revision ||
        now >= 1440) {
      return true;
    }
    final bases = {for (final block in current.reserved) block.id: block};
    final proposed = {for (final block in draft.reserved) block.id: block};
    final changedReservations = [
      for (final id in {...bases.keys, ...proposed.keys})
        if (!_sameBlock(bases[id], proposed[id])) ...[
          ?bases[id],
          ?proposed[id],
        ],
    ];
    return changedReservations.any(
          (block) => block.start >= draft.cutoff && block.start < now,
        ) ||
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

  PlanDraft restoreRevision(String date, Map<String, dynamic> entry) {
    final historical = entry['snapshot'];
    if (historical is! Map<String, dynamic>) {
      throw StateError('This earlier revision only has a change log.');
    }
    final cutoff = cutoffFor(date);
    final retained = day(date).reserved
        .where((block) => block.start < cutoff)
        .toList();
    final ids = retained.map((block) => block.id).toSet();
    final reserved = [
      ...retained,
      for (final block in parseBlocks(historical['reserved']))
        if (block.start >= cutoff && !ids.contains(block.id)) block,
    ];
    return preview(
      date,
      workday: (
        start: historical['start'] as int,
        end: historical['end'] as int,
      ),
      reservedOverride: reserved,
      windowsOverride: parseWindows(historical['windows']),
      preferred: parseBlocks(historical['approved']),
      reason: 'Restore revision ${entry['revision']}',
    );
  }

  PlanDraft recalculate(PlanDraft draft) {
    final current = day(draft.day);
    final old = {for (final block in draft.base.reserved) block.id: block};
    final desired = {
      for (final block in draft.reserved)
        if (block.id != draft.interruptionId) block.id: block,
    };
    final merged = {for (final block in current.reserved) block.id: block};
    for (final id in {...old.keys, ...desired.keys}) {
      if (_sameBlock(old[id], desired[id])) continue;
      if (!_sameBlock(merged[id], old[id]) &&
          !_sameBlock(merged[id], desired[id])) {
        throw StateError(
          'Reserved time changed on another revision. Discard this proposal and reopen the event.',
        );
      }
      if (desired[id] case final block?) {
        merged[id] = block;
      } else {
        merged.remove(id);
      }
    }
    final hoursChanged = draft.workday != draft.base.workday;
    if (hoursChanged &&
        current.workday != draft.base.workday &&
        current.workday != draft.workday) {
      throw StateError(
        'Working hours changed. Reopen the working-hours editor.',
      );
    }
    final windows = {...current.windows};
    for (final id in {...draft.base.windows.keys, ...draft.windows.keys}) {
      if (draft.base.windows[id] == draft.windows[id]) continue;
      if (windows[id] != draft.base.windows[id] &&
          windows[id] != draft.windows[id]) {
        throw StateError('A task time window changed. Reopen its constraints.');
      }
      if (draft.windows[id] case final window?) {
        windows[id] = window;
      } else {
        windows.remove(id);
      }
    }
    return preview(
      draft.day,
      workday: hoursChanged ? draft.workday : null,
      reservedOverride: merged.values.toList(),
      windowsOverride: windows,
      interruption: draft.interruption,
      preferred: draft.preferred,
      reason: draft.reason,
    );
  }

  Future<void> approve(PlanDraft draft) async {
    if (draft.result.blocks.any(
      (block) => isSharedTaskKey(block.id) && block.start >= draft.cutoff,
    )) {
      await tasks.refreshShared?.call();
    }
    await _apply(draft);
  }

  Future<void> _apply(PlanDraft draft) => _save(draft.day, (current) {
    if (isStale(draft)) {
      throw StateError(
        'The schedule or tasks changed. Generate a fresh preview.',
      );
    }
    return DayPlan(
      workday: draft.workday,
      reserved: draft.reserved,
      approved: draft.result.blocks,
      windows: draft.windows,
      version: current.version + 1,
      history: [
        ...current.history,
        {
          'revision': current.version + 1,
          'reason': draft.reason,
          'time': _now().toUtc().toIso8601String(),
          'snapshot': DayPlan(
            workday: draft.workday,
            reserved: draft.reserved,
            approved: draft.result.blocks,
            windows: draft.windows,
            version: current.version + 1,
          ).snapshot(),
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
