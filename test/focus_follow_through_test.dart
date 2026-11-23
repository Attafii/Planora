import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/features/focus/focus_store.dart';
import 'package:mobile_project/features/focus/focus_task_link.dart';
import 'package:mobile_project/features/focus/pages.dart';
import 'package:mobile_project/features/planning/planning_engine.dart';
import 'package:mobile_project/features/planning/planning_page.dart';
import 'package:mobile_project/features/planning/planning_store.dart';
import 'package:mobile_project/features/tasks/task_store.dart';

import 'widget_test.dart' show MemoryPreferences;

class TestDisk extends MemoryPreferences {
  TestDisk({this.fail = _never});
  final bool Function(String key) fail;
  static bool _never(String key) => false;

  @override
  Future<void> setString(String key, String value) async {
    if (fail(key)) throw StateError('Device write failed');
    await super.setString(key, value);
  }
}

class Fixture {
  Fixture([MemoryPreferences? storage]) : storage = storage ?? TestDisk() {
    tasks = TaskStore(this.storage);
    plan = PlanningStore(this.storage, tasks, now: () => now);
    focus = makeFocus();
    addTearDown(tasks.dispose);
    addTearDown(plan.dispose);
    addTearDown(focus.dispose);
  }

  static const date = '2026-06-02';
  static const task = Task(id: 'task', title: 'Prepare notes');
  final MemoryPreferences storage;
  DateTime now = DateTime(2026, 6, 2, 8);
  late final TaskStore tasks;
  late final PlanningStore plan;
  late final FocusStore focus;
  late final ScheduledFocus slot;
  FocusStore makeFocus() => FocusStore(
    storage: storage,
    clock: () => now,
    taskContext: FocusTaskContext(tasks, plan),
  );

  Future<void> schedule() async {
    await tasks.save(task);
    await plan.approve(plan.preview(date));
    slot = ScheduledFocus.fromBlock(plan.day(date).approved.single, date, null);
  }

  void advance(int millis) {
    now = now.add(Duration(milliseconds: millis));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('project planning and focus reuse the shared task without storing a personal copy', () async {
    final fixture = Fixture();
    final task = Task(
      id: sharedTaskKey('record'),
      title: sharedTaskLabel('record'),
    );
    var completed = false;
    fixture.tasks.completeShared = (id) async {
      expect(id, 'record');
      completed = true;
      fixture.tasks.setSharedTasks([
        task.patch({'done': true}),
      ]);
    };
    fixture.tasks.setSharedTasks([task]);
    expect(fixture.tasks.inbox, isEmpty);
    final draft = fixture.plan.preview(Fixture.date);
    await fixture.plan.approve(draft);
    final block = fixture.plan
        .calendarEntries(Fixture.date)
        .singleWhere((block) => block.id == task.id);
    expect(block.id, task.id);
    expect(fixture.storage.values['planify.tasks.v1'], isNull);
    final slot = ScheduledFocus.fromBlock(block, Fixture.date, null);
    final session = fixture.focus.startScheduled(slot, 25, 'Countdown');
    fixture.advance(3000);
    fixture.focus.finish();
    await fixture.focus.settled;
    expect(fixture.focus.recordedSecondsFor({task.id}), 3);
    expect(completed, isFalse);
    await fixture.focus.completeLinkedTask(session.id);
    expect(completed, isTrue);
    fixture.tasks.setSharedTasks([]);
    expect(
      fixture.plan
          .calendarEntries(Fixture.date)
          .where((block) => block.id == task.id),
      isEmpty,
    );
    expect(fixture.plan.day(Fixture.date).approved.single.id, task.id);
    expect(
      () => fixture.focus.startScheduled(slot, 25, 'Countdown'),
      throwsStateError,
    );
    expect(fixture.focus.recordedSecondsFor({task.id}), 3);
  });

  test('proposal approval revalidates shared access and preserves the existing plan', () async {
    final fixture = Fixture();
    await fixture.schedule();
    final task = Task(
      id: sharedTaskKey('record'),
      title: sharedTaskLabel('record'),
    );
    fixture.tasks.setSharedTasks([task]);
    final draft = fixture.plan.preview(Fixture.date);
    fixture.tasks.refreshShared = () async => fixture.tasks.setSharedTasks([]);
    await expectLater(fixture.plan.approve(draft), throwsStateError);
    expect(fixture.plan.day(Fixture.date).version, 1);
    expect(
      fixture.plan.visibleApproved(Fixture.date).single.id,
      Fixture.task.id,
    );
  });

  test(
    'changed, expired, blocked, and removed blocks cannot start focus',
    () async {
      final f = Fixture();
      await f.schedule();
      f.now = DateTime(2026, 6, 2, 10);
      expect(
        () => f.focus.startScheduled(f.slot, 25, 'Countdown'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'reason',
            contains('has ended'),
          ),
        ),
      );
      f.now = DateTime(2026, 6, 2, 8);
      await f.tasks.save(const Task(id: 'gate', title: 'Get approval'));
      await f.tasks.save(
        Fixture.task.patch({
          'requires': ['gate'],
        }),
      );
      expect(
        () => f.focus.startScheduled(f.slot, 25, 'Countdown'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'reason',
            contains('blocked'),
          ),
        ),
      );
      await f.tasks.save(Fixture.task);
      await f.plan.approve(
        f.plan.preview(
          Fixture.date,
          constraint: const PlanBlock(
            'event',
            'Meeting',
            540,
            570,
            BlockKind.commitment,
          ),
        ),
      );
      expect(
        () => f.focus.startScheduled(f.slot, 25, 'Countdown'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'reason',
            contains('block changed'),
          ),
        ),
      );
      final newSlot = ScheduledFocus.fromBlock(
        f.plan
            .day(Fixture.date)
            .approved
            .firstWhere((b) => b.id == Fixture.task.id),
        Fixture.date,
        null,
      );
      await f.tasks.remove(Fixture.task);
      expect(
        () => f.focus.startScheduled(newSlot, 25, 'Countdown'),
        throwsStateError,
      );
      expect(f.focus.sessions, isEmpty);
    },
  );

  test('restart retains the slot and only active time across pauses, breaks and repeated resume', () async {
    final f = Fixture();
    await f.schedule();
    final active = f.focus.startScheduled(f.slot, 25, 'Countdown');
    expect(
      () => f.focus.startScheduled(f.slot, 25, 'Countdown'),
      throwsStateError,
    );
    f.advance(10500);
    f.focus.pause();
    await f.focus.settled;
    final restored = f.makeFocus();
    addTearDown(restored.dispose);
    f.advance(60000);
    await restored.load();
    expect(restored.active!.id, active.id);
    expect(restored.active!.scheduled!.sameSlot(f.slot), isTrue);
    expect(restored.active!.elapsed(f.now), 10);
    restored.resume();
    f.advance(4200);
    restored.resume();
    f.advance(1600);
    restored.takeBreak();
    f.advance(120000);
    restored.resume();
    f.advance(4600);
    final early = restored.finish()!;
    expect(early.statusLabel, 'Ended early');
    expect(early.accumulatedMillis, 20900);
    expect(early.seconds, 20);
    expect(restored.finish(), isNull);
    await restored.settled;
    expect(restored.recordedSecondsFor({'task'}), 20);
    expect(f.tasks.completed(f.tasks.get('task')!), isFalse);
  });

  test('finishing persists time once, survives retries and requires explicit task completion', () async {
    var rejectFocusWrite = false;
    final disk = TestDisk(
      fail: (key) => rejectFocusWrite && key.startsWith('planify.oumayma'),
    );
    final f = Fixture(disk);
    await f.schedule();
    final session = f.focus.startScheduled(f.slot, 25, 'Stopwatch');
    await f.focus.settled;
    f.advance(75000);
    rejectFocusWrite = true;
    expect(f.focus.finish()!.status, 'completed');
    await f.focus.settled;
    expect(f.focus.error, isNotNull);
    expect(f.focus.recordedSecondsFor({'task'}), 0);
    await expectLater(f.focus.completeLinkedTask(session.id), throwsStateError);
    expect(f.tasks.completed(f.tasks.get('task')!), isFalse);

    rejectFocusWrite = false;
    f.focus.save();
    f.focus.save();
    await f.focus.settled;
    expect(f.focus.error, isNull);
    expect(f.focus.recordedSecondsFor({'task'}), 75);
    expect(f.tasks.completed(f.tasks.get('task')!), isFalse);
    final stored = jsonDecode(disk.values['planify.oumayma.v1']!) as Map;
    expect((stored['sessions'] as List).single['id'], session.id);
    await f.focus.completeLinkedTask(session.id);
    await f.focus.completeLinkedTask(session.id);
    expect(f.tasks.completed(f.tasks.get('task')!), isTrue);
  });

  test('abandoned time and the original slot remain in history without adding task progress', () async {
    final f = Fixture();
    await f.schedule();
    final session = f.focus.startScheduled(f.slot, 5, 'Countdown');
    f.advance(12000);
    f.focus.log('Interruption', 'A call');
    f.advance(40000);
    await f.plan.approve(
      f.plan.preview(
        Fixture.date,
        constraint: const PlanBlock(
          'event',
          'Meeting',
          540,
          570,
          BlockKind.commitment,
        ),
      ),
    );
    f.focus.finish(cancelled: true);
    await f.focus.settled;

    final restored = f.makeFocus();
    addTearDown(restored.dispose);
    await restored.load();
    final stored = restored.sessions.single;
    expect(stored.id, session.id);
    expect(stored.scheduled!.sameSlot(f.slot), isTrue);
    expect(stored.interrupted, isTrue);
    expect(stored.statusLabel, 'Abandoned');
    expect(stored.seconds, 12);
    expect(restored.recordedSecondsFor({'task'}), 0);
    await expectLater(
      restored.completeLinkedTask(session.id),
      throwsStateError,
    );
  });

  testWidgets(
    'Calendar starts the selected task and reflection offers explicit completion',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final f = Fixture();
      await f.schedule();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => PlanningPage(
              store: f.plan,
              onStartFocus: (date, block) {
                openFocus(
                  context,
                  f.focus,
                  scheduled: ScheduledFocus.fromBlock(block, date, null),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(ListTile, 'Prepare notes'),
      );
      await tester.tap(find.widgetWithText(ListTile, 'Prepare notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start focus'));
      await tester.pumpAndSettle();
      expect(find.textContaining('09:00–09:25'), findsOneWidget);
      expect(find.text('25 min scheduled'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Begin focus'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Begin focus'));
      await tester.pumpAndSettle();
      expect(f.focus.active!.scheduled!.sameSlot(f.slot), isTrue);
      f.advance(21000);
      await tester.ensureVisible(find.text('Finish session'));
      await tester.tap(find.text('Finish session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End early'));
      await tester.pumpAndSettle();
      expect(find.text('Ended early'), findsOneWidget);
      expect(find.text('00:21'), findsOneWidget);
      expect(f.tasks.completed(f.tasks.get('task')!), isFalse);
      await tester.ensureVisible(find.text('Mark task done'));
      await tester.tap(find.text('Mark task done'));
      await tester.pumpAndSettle();
      expect(f.tasks.completed(f.tasks.get('task')!), isFalse);
      await tester.tap(find.text('Mark done'));
      await tester.pumpAndSettle();
      expect(find.text('Linked task is done.'), findsOneWidget);
      expect(f.tasks.completed(f.tasks.get('task')!), isTrue);
    },
  );
}
