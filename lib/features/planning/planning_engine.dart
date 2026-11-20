import 'dart:math' as math;

typedef Minutes = ({int start, int end});

String clockLabel(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

String intervalLabel(int start, int end) =>
    '${clockLabel(start)}–${clockLabel(end)}';

enum BlockKind { task, commitment, pause, unavailable }

class PlanBlock {
  const PlanBlock(this.id, this.title, this.start, this.end, this.kind);

  factory PlanBlock.fromJson(Map<String, dynamic> json) => PlanBlock(
    json['id'] as String,
    json['title'] as String,
    json['start'] as int,
    json['end'] as int,
    BlockKind.values.byName(json['kind'] as String),
  );

  final String id, title;
  final int start, end;
  final BlockKind kind;
  Minutes get interval => (start: start, end: end);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'start': start,
    'end': end,
    'kind': kind.name,
  };
}

class PlanningTask {
  const PlanningTask(
    this.id,
    this.title,
    this.minutes,
    this.due,
    this.blockers,
  );
  final String id, title;
  final int minutes;
  final String? due;
  final List<String> blockers;
}

enum ChangeKind { added, moved, preserved, deferred, removed }

typedef PlanChange = ({
  String id,
  String title,
  ChangeKind kind,
  String? before,
  String? after,
  String reason,
});

class ScheduleResult {
  const ScheduleResult(this.blocks, this.changes);
  final List<PlanBlock> blocks;
  final List<PlanChange> changes;
}

typedef Interruption = ({String id, int start, int end});

class PlanningEngine {
  const PlanningEngine();

  ScheduleResult compute({
    required List<PlanningTask> tasks,
    required List<PlanBlock> previous,
    required List<PlanBlock> commitments,
    required Minutes workday,
    required int cutoff,
    Interruption? interruption,
    List<PlanBlock>? previousCommitments,
    int? earliest,
  }) {
    bool overlaps(Minutes a, Minutes b) => a.start < b.end && b.start < a.end;
    final obstacles = [
      ...commitments,
      if (interruption != null)
        PlanBlock(
          interruption.id,
          'Interruption',
          interruption.start,
          interruption.end,
          BlockKind.unavailable,
        ),
    ];
    final preserved = <PlanBlock>[];
    final elapsed = <String, int>{};
    for (final block in previous) {
      if (block.start >= cutoff) continue;
      final end = math.min(block.end, cutoff);
      preserved.add(
        PlanBlock(block.id, block.title, block.start, end, block.kind),
      );
      elapsed.update(
        block.id,
        (sum) => sum + end - block.start,
        ifAbsent: () => end - block.start,
      );
    }
    final available = <Minutes>[];
    var cursor = math.max(workday.start, earliest ?? cutoff);
    final blocked = [...obstacles, ...preserved]
      ..sort((a, b) => a.start.compareTo(b.start));
    for (final block in blocked) {
      if (block.end <= cursor || block.start >= workday.end) continue;
      if (block.start > cursor) {
        available.add((start: cursor, end: block.start));
      }
      cursor = math.max(cursor, block.end);
    }
    if (cursor < workday.end) available.add((start: cursor, end: workday.end));

    final priority = [...tasks]
      ..sort((a, b) {
        final date = (a.due ?? '9999').compareTo(b.due ?? '9999');
        return date == 0 ? a.id.compareTo(b.id) : date;
      });
    final next = [...preserved];
    final deferred = <String, String>{};
    for (final task in priority) {
      final remaining = task.minutes - (elapsed[task.id] ?? 0);
      if (remaining <= 0) continue;
      if (task.blockers.isNotEmpty) {
        deferred[task.id] = 'Complete ${task.blockers.join(', ')} first.';
        continue;
      }
      final index = available.indexWhere(
        (gap) => gap.end - gap.start >= remaining,
      );
      if (index < 0) {
        deferred[task.id] =
            'Needs $remaining uninterrupted minutes within working hours after commitments and breaks.';
        continue;
      }
      final gap = available[index];
      final end = gap.start + remaining;
      next.add(PlanBlock(task.id, task.title, gap.start, end, BlockKind.task));
      available[index] = (start: end, end: gap.end);
    }
    next.sort((a, b) => a.start.compareTo(b.start));
    String? describe(List<PlanBlock> items, String id) {
      final times = items
          .where((block) => block.id == id)
          .map((block) => intervalLabel(block.start, block.end))
          .toList();
      return times.isEmpty ? null : times.join(', ');
    }

    final titles = {
      for (final block in previous) block.id: block.title,
      for (final task in priority) task.id: task.title,
    };
    final changes = <PlanChange>[];
    for (final entry in titles.entries) {
      final old = describe(previous, entry.key);
      final updated = describe(next, entry.key);
      final deferredReason = deferred[entry.key];
      final previousBlocks = previous.where((block) => block.id == entry.key);
      final conflict = obstacles
          .where(
            (item) => previousBlocks.any(
              (block) => overlaps(block.interval, item.interval),
            ),
          )
          .firstOrNull;
      final kind = deferredReason != null
          ? ChangeKind.deferred
          : old == updated
          ? ChangeKind.preserved
          : old == null
          ? ChangeKind.added
          : updated == null
          ? ChangeKind.removed
          : ChangeKind.moved;
      changes.add((
        id: entry.key,
        title: entry.value,
        kind: kind,
        before: old,
        after: updated,
        reason:
            deferredReason ??
            switch (kind) {
              ChangeKind.preserved => 'The previous slot is still in the plan.',
              ChangeKind.added => 'The task fits in an available slot.',
              ChangeKind.removed =>
                'The task is no longer pending on this day.',
              ChangeKind.moved =>
                conflict != null
                    ? 'The previous slot overlaps ${conflict.title}.'
                    : 'The task fits at a different time within the available hours.',
              ChangeKind.deferred => throw StateError(
                'Missing deferral reason.',
              ),
            },
      ));
    }
    final oldReserved = {
      for (final block in previousCommitments ?? commitments) block.id: block,
    };
    final newReserved = {for (final block in obstacles) block.id: block};
    for (final id in {...oldReserved.keys, ...newReserved.keys}) {
      final oldBlock = oldReserved[id];
      final newBlock = newReserved[id];
      final block = newBlock ?? oldBlock!;
      final before = oldBlock == null
          ? null
          : intervalLabel(oldBlock.start, oldBlock.end);
      final after = newBlock == null
          ? null
          : intervalLabel(newBlock.start, newBlock.end);
      final kind = oldBlock == null
          ? ChangeKind.added
          : newBlock == null
          ? ChangeKind.removed
          : before == after &&
                oldBlock.title == newBlock.title &&
                oldBlock.kind == newBlock.kind
          ? ChangeKind.preserved
          : ChangeKind.moved;
      changes.add((
        id: id,
        title: block.title,
        kind: kind,
        before: before,
        after: after,
        reason: newBlock == null
            ? 'This reserved time was released.'
            : block.kind == BlockKind.pause
            ? 'Reserved break.'
            : 'Reserved time.',
      ));
    }
    return ScheduleResult(List.unmodifiable(next), List.unmodifiable(changes));
  }
}
