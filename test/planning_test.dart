import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/features/planning/planning_engine.dart';
import 'package:mobile_project/features/planning/planning_store.dart';
import 'package:mobile_project/features/tasks/task_store.dart';

import 'widget_test.dart' show MemoryPreferences;

void main() {
  test('allocation is repeatable and reports blocked or oversized work', () {
    const tasks = [
      PlanningTask('a', 'Prepare', 60, '2026-11-19', []),
      PlanningTask('b', 'Review', 30, null, ['Prepare']),
      PlanningTask('c', 'Large task', 200, null, []),
    ];
    const event = PlanBlock('event', 'Class', 600, 630, BlockKind.commitment);
    const pause = PlanBlock('break', 'Lunch', 660, 720, BlockKind.pause);
    ScheduleResult compute() => const PlanningEngine().compute(
      tasks: tasks,
      previous: [],
      commitments: [event, pause],
      workday: (start: 540, end: 780),
      cutoff: 0,
    );
    final draft = compute();
    expect(draft.blocks.single.interval, (start: 540, end: 600));
    expect(
      compute().blocks.map((block) => block.toJson()),
      draft.blocks.map((block) => block.toJson()),
    );
    final deferred = draft.changes.where(
      (change) => change.kind == ChangeKind.deferred,
    );
    expect(deferred.map((change) => change.id), ['b', 'c']);
    expect(deferred.first.reason, contains('Prepare'));
  });

  test(
    'interruption keeps elapsed work, blocks downtime and records one approval',
    () async {
      final storage = MemoryPreferences();
      final tasks = TaskStore(storage);
      final now = DateTime.now();
      final selected = DateTime(now.year, now.month, now.day + 1);
      final date = dayKey(selected);
      final store = PlanningStore(
        storage,
        tasks,
        now: () => DateTime(now.year, now.month, now.day, 8),
      );
      await tasks.save(
        Task(id: 'a', title: 'Prepare', minutes: 120, due: date),
      );
      await tasks.save(const Task(id: 'b', title: 'Review', minutes: 30));
      await store.approve(store.preview(date));
      const event = (id: 'interrupt-1', start: 600, end: 690);
      final draft = store.preview(date, interruption: event);
      final segments = draft.result.blocks.where((block) => block.id == 'a');
      expect(segments.map((block) => block.interval), [
        (start: 540, end: 600),
        (start: 780, end: 840),
      ]);
      expect(
        draft.result.blocks.where(
          (block) => block.start < 690 && block.end > 600,
        ),
        isEmpty,
      );
      expect(
        draft.result.changes.singleWhere((change) => change.id == 'a').reason,
        contains('Interruption'),
      );
      await store.approve(draft);
      await expectLater(store.approve(draft), throwsStateError);
      expect(() => store.preview(date, interruption: event), throwsStateError);
      final restored = PlanningStore(storage, tasks);
      await restored.load();
      expect(restored.day(date).history.length, 2);
      expect(
        restored.day(date).reserved.any((block) => block.id == event.id),
        isTrue,
      );
    },
  );

  test('a task edit or a calendar approval invalidates a draft', () async {
    final storage = MemoryPreferences();
    final tasks = TaskStore(storage);
    final now = DateTime.now();
    final date = dayKey(DateTime(now.year, now.month, now.day + 1));
    final store = PlanningStore(storage, tasks, now: () => now);
    final original = store.preview(date);
    await tasks.save(const Task(id: 'late', title: 'Added task'));
    expect(store.isStale(original), isTrue);
    final competing = store.preview(date);
    await store.approve(store.preview(date, workday: (start: 480, end: 960)));
    await expectLater(store.approve(competing), throwsStateError);
    expect(store.day(date).history.length, 1);
  });
}
