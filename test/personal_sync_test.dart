import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_project/core/services/app_session.dart';
import 'package:mobile_project/core/services/personal_sync.dart';
import 'package:mobile_project/features/tasks/task_store.dart';
import 'package:mobile_project/features/focus/focus_store.dart';
import 'package:mobile_project/features/focus/focus_task_link.dart';
import 'package:mobile_project/features/planning/planning_store.dart';

import 'widget_test.dart' show MemoryPreferences;

Map<String, dynamic> profile(String id) => {
  'id': id,
  'name': 'Test User',
  'email': '$id@example.test',
  'timezone': 'Africa/Tunis',
  'language': 'en',
  'preferences': {'theme': 'system', 'cloud_ai': false},
};

class TestDisk extends MemoryPreferences {
  @override
  Future<Set<String>> getKeys({Set<String>? allowList}) async =>
      values.keys.where((key) => allowList?.contains(key) ?? true).toSet();
}

class SyncDisk extends MemoryPreferences {
  SyncDisk(this.sync);
  final PersonalSync sync;

  @override
  Future<String?> getString(String key) => sync.read(key);

  @override
  Future<void> setString(String key, String value) => sync.write(key, value);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cached identity restores offline and revocation clears it', () async {
    FlutterSecureStorage.setMockInitialValues({
      AppSession.tokenKey: jsonEncode({
        'server': 'https://planify.example.test',
        'token': 'test-token',
        'expires_at': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
        'user': profile('alice'),
      }),
    });
    var offline = true;
    final session = AppSession(
      baseUrl: 'https://planify.example.test',
      client: MockClient((request) async {
        if (offline) throw http.ClientException('offline');
        return http.Response('{}', 401);
      }),
    );
    addTearDown(session.dispose);
    await session.restore();
    expect(session.account!.id, 'alice');
    await expectLater(session.refreshAccount(), throwsA(isA<ApiFailure>()));
    expect(session.account!.id, 'alice');
    offline = false;
    await expectLater(session.refreshAccount(), throwsA(isA<ApiFailure>()));
    expect(session.account, isNull);
    expect(session.sessionMessage, AppSession.ended);
    expect(await session.storage.read(key: AppSession.tokenKey), isNull);
  });

  test('expired cached session never exposes its account', () async {
    FlutterSecureStorage.setMockInitialValues({
      AppSession.tokenKey: jsonEncode({
        'server': 'https://planify.example.test',
        'token': 'expired',
        'expires_at': DateTime.now()
            .subtract(const Duration(hours: 1))
            .toIso8601String(),
        'user': profile('alice'),
      }),
    });
    final session = AppSession(
      baseUrl: 'https://planify.example.test',
      client: MockClient((_) async => throw StateError('Unexpected request')),
    );
    addTearDown(session.dispose);
    await session.restore();
    expect(session.account, isNull);
    expect(session.sessionMessage, AppSession.ended);
    expect(await session.storage.read(key: AppSession.tokenKey), isNull);
  });

  test(
    'offline edit survives restart and another account cannot read it',
    () async {
      final disk = TestDisk();
      final remote = <String, dynamic>{};
      var offline = true;
      var uploads = 0;
      AppSession session(String id) => AppSession(
        client: MockClient((request) async {
          if (offline) throw http.ClientException('offline');
          if (request.url.path == '/users/me') {
            return http.Response(jsonEncode(profile(id)), 200);
          }
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({'collections': remote[id] ?? {}}),
              200,
            );
          }
          uploads++;
          final body = jsonDecode(request.body) as Map;
          final version = {'revision': 1, 'snapshot': body['snapshot']};
          remote[id] = {'tasks': version};
          // Simulate a committed write whose response never reached the device.
          throw http.ClientException('response lost');
        }),
      )..account = Account.fromJson(profile(id));

      final alice = session('alice');
      final bob = session('bob');
      addTearDown(alice.dispose);
      addTearDown(bob.dispose);
      const key = 'planify.tasks.v1.alice';
      final first = PersonalSync(alice, disk);
      await first.open();
      final tasks = TaskStore(SyncDisk(first), accountId: 'alice');
      addTearDown(tasks.dispose);
      const task = Task(id: 'one', title: 'Offline');
      await tasks.save(task);
      await tasks.addSteps(task, ['First step', 'Second step']);
      final value = await first.read(key);
      expect(first.pending, isTrue);
      first.dispose();

      final restored = PersonalSync(alice, disk);
      addTearDown(restored.dispose);
      await restored.open();
      expect(restored.offline, isTrue);
      expect(await restored.read(key), value);
      final restoredTasks = TaskStore(SyncDisk(restored), accountId: 'alice');
      addTearDown(restoredTasks.dispose);
      await restoredTasks.load();
      expect(restoredTasks.children(task.id).map((step) => step.title), [
        'First step',
        'Second step',
      ]);
      expect(restored.pending, isTrue);

      final isolated = PersonalSync(bob, disk);
      addTearDown(isolated.dispose);
      await isolated.open();
      expect(await isolated.read('planify.tasks.v1.bob'), isNull);
      await expectLater(isolated.read(key), throwsArgumentError);

      offline = false;
      await restored.sync();
      expect(restored.pending, isTrue);
      await restored.sync();
      expect(restored.pending, isFalse);
      expect(restored.synced, isTrue);
      expect(uploads, 1);
    },
  );

  test(
    'a linked focus finish syncs once after a lost acknowledgment',
    () async {
      const date = '2026-06-02';
      var now = DateTime(2026, 6, 2, 8);
      final tasks = TaskStore(MemoryPreferences());
      final planning = PlanningStore(
        MemoryPreferences(),
        tasks,
        now: () => now,
      );
      addTearDown(tasks.dispose);
      addTearDown(planning.dispose);
      const task = Task(id: 'task', title: 'Focus task');
      await tasks.save(task);
      await planning.approve(planning.preview(date));
      final slot = ScheduledFocus.fromBlock(
        planning.day(date).approved.single,
        date,
        null,
      );

      final remote = <String, dynamic>{};
      var offline = true;
      var uploads = 0;
      final session = AppSession(
        client: MockClient((request) async {
          if (offline) throw http.ClientException('offline');
          if (request.url.path == '/users/me') {
            return http.Response(jsonEncode(profile('alice')), 200);
          }
          if (request.method == 'GET') {
            return http.Response(jsonEncode({'collections': remote}), 200);
          }
          expect(request.url.path, '/users/me/sync/focus');
          uploads++;
          final body = jsonDecode(request.body) as Map;
          remote['focus'] = {'revision': 1, 'snapshot': body['snapshot']};
          throw http.ClientException('response lost after commit');
        }),
      )..account = Account.fromJson(profile('alice'));
      addTearDown(session.dispose);
      final disk = TestDisk();
      final sync = PersonalSync(session, disk);
      addTearDown(sync.dispose);
      await sync.open();
      final focus = FocusStore(
        accountId: 'alice',
        storage: SyncDisk(sync),
        clock: () => now,
        taskContext: FocusTaskContext(tasks, planning),
      );
      addTearDown(focus.dispose);

      final started = focus.startScheduled(slot, 5, 'Countdown');
      now = now.add(const Duration(seconds: 22));
      focus.finish();
      await focus.settled;
      expect(sync.pending, isTrue);
      expect(focus.recordedSecondsFor({'task'}), 22);

      offline = false;
      await sync.sync();
      expect(sync.pending, isTrue);
      await sync.sync();
      expect(sync.pending, isFalse);
      expect(uploads, 1);
      final records = jsonDecode(remote['focus']['snapshot'] as String) as Map;
      final saved = (records['sessions'] as List).single as Map;
      expect(saved['id'], started.id);
      expect(saved['seconds'], 22);
      expect(saved['scheduled']['taskId'], task.id);
      expect(tasks.completed(tasks.get(task.id)!), isFalse);
    },
  );

  test(
    'conflict preserves both versions and archives the declined copy',
    () async {
      final disk = TestDisk();
      final alice = AppSession(
        client: MockClient((request) async {
          if (request.url.path == '/users/me') {
            return http.Response(jsonEncode(profile('alice')), 200);
          }
          expect(request.method, 'GET');
          return http.Response(
            jsonEncode({
              'collections': {
                'tasks': {'revision': 1, 'snapshot': '[{"id":"remote"}]'},
              },
            }),
            200,
          );
        }),
      )..account = Account.fromJson(profile('alice'));
      addTearDown(alice.dispose);
      const key = 'planify.tasks.v1.alice';
      await disk.setString(key, '[{"id":"local"}]');
      final sync = PersonalSync(alice, disk);
      await sync.open();
      expect(sync.updates, {'tasks': true});
      expect(await sync.read(key), '[{"id":"local"}]');
      await sync.resolve('tasks', keepLocal: false);
      expect(await sync.read(key), '[{"id":"remote"}]');
      expect(sync.versions('tasks'), ['[{"id":"local"}]']);
      sync.dispose();
      final reopened = PersonalSync(alice, disk);
      addTearDown(reopened.dispose);
      await reopened.open();
      expect(reopened.versions('tasks'), ['[{"id":"local"}]']);
      expect(reopened.pending, isFalse);
    },
  );
}
