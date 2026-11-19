import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/features/tasks/task_store.dart';
import 'package:mobile_project/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryPreferences extends Fake implements SharedPreferencesAsync {
  final values = <String, String>{};
  @override
  Future<String?> getString(String key) async => values[key];
  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  testWidgets('opens the task module', (tester) async {
    await tester.pumpWidget(Planify(store: TaskStore(MemoryPreferences())));
    await tester.pumpAndSettle();
    expect(find.text('Planify · Tasks'), findsOneWidget);
    expect(find.text('Add task'), findsOneWidget);
  });

  test(
    'rejects cycles and updates readiness after reopening a prerequisite',
    () async {
      final store = TaskStore(MemoryPreferences());
      const first = Task(id: 'a', title: 'First');
      const second = Task(id: 'b', title: 'Second', requires: ['a']);
      await store.save(first);
      await store.save(second);
      await expectLater(
        store.save(
          first.patch({
            'requires': ['b'],
          }),
        ),
        throwsStateError,
      );
      expect(store.blockers(second).single.id, 'a');
      await store.toggle(first);
      expect(store.blockers(second), isEmpty);
      await store.toggle(first);
      expect(store.blockers(second).single.id, 'a');
    },
  );

  test('edits future instances while preserving completion and skipped occurrences', () async {
    final store = TaskStore(MemoryPreferences());
    final now = DateTime.now();
    final date = DateTime.utc(now.year, now.month, now.day);
    await store.save(
      Task(
        id: 'series',
        title: 'Old',
        repeat: Repeat.weekly,
        due: dayKey(date),
      ),
    );
    final first = store.inbox[0];
    final skipped = store.inbox[2];
    await store.toggle(first);
    await store.remove(skipped);
    final second = store.inbox[1];
    await store.save(second.patch({'title': 'New'}), future: true);
    expect(store.inbox.first.title, 'Old');
    expect(store.completed(store.inbox.first), isTrue);
    expect(store.inbox[1].id, second.id);
    expect(store.inbox[1].title, 'New');
    expect(store.inbox.any((task) => task.id == skipped.id), isFalse);
  });
}
