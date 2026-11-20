import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/features/tasks/task_agent.dart';
import 'package:mobile_project/features/tasks/task_store.dart';
import 'package:mobile_project/features/tasks/tasks_page.dart';

import 'widget_test.dart' show MemoryPreferences;

class FailingPreferences extends MemoryPreferences {
  FailingPreferences(this.takeFailure);
  final bool Function() takeFailure;

  @override
  Future<void> setString(String key, String value) async {
    if (takeFailure()) {
      throw StateError('Device storage is temporarily unavailable.');
    }
    await super.setString(key, value);
  }
}

class DraftAgent extends TaskAgent {
  DraftAgent(this.response);
  final Future<List<String>> response;

  @override
  Future<List<String>> decompose(Task task, List<Task> steps) => response;
}

void main() {
  testWidgets(
    'AI review edits, reorders, removes and adds steps, retaining draft on failed save',
    (tester) async {
      var failNext = false;
      final disk = FailingPreferences(() {
        final fails = failNext;
        failNext = false;
        return fails;
      });
      final store = TaskStore(disk);
      addTearDown(store.dispose);
      const parent = Task(id: 'parent', title: 'Prepare meeting');
      await store.save(parent);
      await tester.pumpWidget(
        MaterialApp(
          home: TasksPage(
            store: store,
            agent: DraftAgent(Future.value(['Outline', 'Invite', 'Discard'])),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(parent.title));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Draft subtasks with AI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(store.children(parent.id), isEmpty);

      await tester.enterText(
        find.widgetWithText(TextField, 'Subtask 1'),
        'Write outline',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Move step up').at(1));
      await tester.tap(find.byTooltip('Move step up').at(1));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Remove step').last);
      await tester.tap(find.byTooltip('Remove step').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add a step'));
      await tester.tap(find.text('Add a step'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(TextField, 'Subtask 3'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Subtask 3'),
        'Share agenda',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      failNext = true;
      await tester.tap(find.text('Save subtasks'));
      await tester.pumpAndSettle();
      expect(find.text('Review subtasks'), findsOneWidget);
      expect(store.children(parent.id), isEmpty);
      expect(find.text('Share agenda'), findsOneWidget);
      await tester.tap(find.text('Save subtasks'));
      await tester.pumpAndSettle();
      expect(store.children(parent.id).map((task) => task.title), [
        'Invite',
        'Write outline',
        'Share agenda',
      ]);
      expect(store.get(parent.id)!.title, parent.title);
    },
  );

  testWidgets('cancelling an in-flight AI draft cannot create steps', (
    tester,
  ) async {
    final request = Completer<List<String>>();
    final store = TaskStore(MemoryPreferences());
    addTearDown(store.dispose);
    const parent = Task(id: 'parent', title: 'Draft me');
    await store.save(parent);
    await tester.pumpWidget(
      MaterialApp(
        home: TasksPage(store: store, agent: DraftAgent(request.future)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(parent.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Draft subtasks with AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Drafting subtasks…'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    request.complete(['Never commit']);
    await tester.pumpAndSettle();
    expect(store.children(parent.id), isEmpty);
    expect(find.text('Review subtasks'), findsNothing);
  });

  testWidgets(
    'recommendations react to prerequisites and dismissal while the dialog is open',
    (tester) async {
      final store = TaskStore(MemoryPreferences());
      addTearDown(store.dispose);
      const prerequisite = Task(
        id: 'a',
        title: 'Prerequisite task',
        minutes: 5,
      );
      const dependent = Task(id: 'b', title: 'Dependent task', requires: ['a']);
      await store.save(prerequisite);
      await store.save(dependent);
      await tester.pumpWidget(MaterialApp(home: TasksPage(store: store)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Find my next action'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(prerequisite.title),
        ),
        findsOneWidget,
      );
      await store.toggle(prerequisite);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(dependent.title),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Dismiss suggestion'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No other actions fit'), findsOneWidget);
      expect(store.get(dependent.id)!.done, isFalse);
    },
  );

  test('recurrence retains overrides, skips and completions across a repeated future save', () async {
    final disk = MemoryPreferences();
    final store = TaskStore(disk);
    addTearDown(store.dispose);
    await store.save(
      const Task(
        id: 'weekly',
        title: 'Original',
        due: '2026-03-06',
        repeat: Repeat.weekly,
      ),
    );
    final first = store.get('weekly@2026-03-06')!;
    final split = store.get('weekly@2026-03-13')!;
    final skipped = store.get('weekly@2026-03-20')!;
    final override = store.get('weekly@2026-03-27')!;
    final complete = store.get('weekly@2026-04-03')!;
    await store.toggle(first);
    await store.remove(skipped);
    await store.save(override.patch({'title': 'One date only'}));
    await store.toggle(complete);
    final edit = split.patch({'title': 'Future'});
    await store.save(edit, future: true);
    final updated = disk.values.values.single;
    await store.save(edit, future: true);
    expect(disk.values.values.single, updated);

    final restored = TaskStore(disk);
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.completed(restored.get(first.id)!), isTrue);
    expect(restored.get(split.id)!.title, 'Future');
    expect(restored.get(override.id)!.title, 'One date only');
    expect(restored.get(complete.id)!.title, 'Original');
    expect(restored.completed(restored.get(complete.id)!), isTrue);
    expect(restored.get('weekly@2026-04-10')!.title, 'Future');
    expect(restored.skippedOccurrences.single.id, skipped.id);
    await restored.restoreOccurrence(skipped.id);
    expect(restored.get(skipped.id)!.skipped, isFalse);
    expect(restored.get('weekly@2026-03-28'), isNull);
  });

  test('an older missing prerequisite is explained and can be repaired without losing the task', () async {
    final disk = MemoryPreferences();
    const task = Task(id: 'old', title: 'Older task', requires: ['missing']);
    await disk.setString('planify.tasks.v1', jsonEncode([task.toJson()]));
    final store = TaskStore(disk);
    addTearDown(store.dispose);
    await store.load();
    expect(store.blockers(task).single.title, 'Unavailable prerequisite');
    expect(store.ready(task), isFalse);
    await store.save(const Task(id: 'another', title: 'Another task'));
    await expectLater(
      store.save(
        task.patch({
          'requires': ['old'],
        }),
      ),
      throwsStateError,
    );
    await store.save(task.patch({'requires': []}));
    expect(store.ready(store.get(task.id)!), isTrue);
  });

  test('next actions honor time and energy and favor due work', () async {
    final store = TaskStore(MemoryPreferences());
    addTearDown(store.dispose);
    for (final task in const [
      Task(id: 'deadline', title: 'Deadline', due: '2026-11-20', minutes: 10),
      Task(id: 'long', title: 'Long task', minutes: 45),
      Task(id: 'hard', title: 'High energy', energy: Energy.high, minutes: 15),
      Task(id: 'fit', title: 'Closest fit', minutes: 25),
      Task(id: 'done', title: 'Done', done: true),
    ]) {
      await store.save(task);
    }
    final ranked = store.nextActions(
      minutes: 30,
      energy: Energy.medium,
      today: '2026-11-20',
    );
    expect(ranked.map((task) => task.id), ['deadline', 'fit']);
  });
}
