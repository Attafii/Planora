import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_project/features/focus/focus_store.dart';
import 'package:mobile_project/features/focus/smart_tools.dart';
import 'package:mobile_project/app/focus_app.dart';

class MemoryStore extends FocusStore {
  @override
  void save() {
    notifyListeners();
  }
}

Future<void> tapText(WidgetTester t, String text) async {
  await t.scrollUntilVisible(
    find.text(text),
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await t.pumpAndSettle();
  await t.ensureVisible(find.text(text));
  await t.pumpAndSettle();
  await t.tap(find.text(text));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'Tools belong to Focus and Reminders, with no separate tools tab',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final s = MemoryStore();
      addTearDown(s.dispose);
      await t.pumpWidget(MaterialApp(home: MobileShell(store: s)));
      expect(find.text('Smart tools'), findsNothing);
      await t.tap(find.text('Focus'));
      await t.pumpAndSettle();
      expect(find.byTooltip('AI focus coach'), findsOneWidget);
      await t.tap(find.byTooltip('AI focus coach'));
      await t.pumpAndSettle();
      expect(find.text('A smaller first step.'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      await t.tap(find.byTooltip('Close'));
      await t.pumpAndSettle();
      await t.tap(find.text('Reminders'));
      await t.pumpAndSettle();
      expect(find.byTooltip('AI reminder agent'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Adaptive proposal rejection changes nothing; approval starts once',
    (t) async {
      final s = MemoryStore();
      addTearDown(s.dispose);
      await t.pumpWidget(MaterialApp(home: ContextAssistSheet(store: s)));
      await t.enterText(find.byType(TextField), 'Read notes');
      await tapText(t, 'Review a suggestion');
      expect(s.active, isNull);
      await tapText(t, 'Reject');
      expect(s.sessions, isEmpty);
      await tapText(t, 'Review a suggestion');
      await tapText(t, 'Approve');
      expect(s.sessions.length, 1);
      expect(s.active!.minutes, 25);
      expect(find.text('Applied'), findsOneWidget);
    },
  );
  testWidgets(
    'Guard previews quiet-hour move and preserves weekly recurrence',
    (t) async {
      final s = MemoryStore();
      addTearDown(s.dispose);
      final d = DateTime.now().add(const Duration(days: 1));
      final r = Reminder(
        id: '100',
        title: 'Stretch',
        when: DateTime(d.year, d.month, d.day, 23),
        repeat: 'Weekly',
      );
      s.reminders.add(r);
      await t.pumpWidget(
        MaterialApp(
          home: ContextAssistSheet(
            store: s,
            initialTool: 'Reminder guard',
            reminder: r,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(r.when.hour, 23);
      await tapText(t, 'Approve');
      expect(r.when.hour, 8);
      expect(r.repeat, 'Weekly');
    },
  );
  for (final kind in ['focus', 'reminder']) {
    testWidgets(
      'AI $kind previews then applies approved action using mocked transport',
      (t) async {
        final s = MemoryStore();
        addTearDown(s.dispose);
        final client = MockClient((request) async {
          expect(jsonDecode(request.body)['kind'], kind);
          return http.Response(
            jsonEncode(
              kind == 'focus'
                  ? {
                      'kind': 'focus',
                      'title': 'Study',
                      'reason': 'Short block',
                      'minutes': 20,
                      'steps': ['Read one page', 'Write notes'],
                    }
                  : {
                      'kind': 'reminder',
                      'title': 'Stretch',
                      'reason': 'Requested time',
                      'when': DateTime.now()
                          .add(const Duration(days: 1))
                          .toUtc()
                          .toIso8601String(),
                      'repeat': 'Daily',
                    },
            ),
            200,
          );
        });
        await t.pumpWidget(
          MaterialApp(
            home: ContextAssistSheet(
              store: s,
              client: client,
              initialTool: kind == 'focus'
                  ? 'AI focus coach'
                  : 'AI reminder agent',
            ),
          ),
        );
        await t.enterText(find.byType(TextField), 'Help me plan');
        await tapText(t, 'Review a suggestion');
        expect(s.sessions, isEmpty);
        expect(s.reminders, isEmpty);
        await tapText(t, 'Approve');
        if (kind == 'focus') {
          expect(s.active!.minutes, 20);
          expect(s.active!.notes, contains('Write notes'));
        } else {
          expect(s.reminders.single.repeat, 'Daily');
        }
      },
    );
  }
  testWidgets('Unconfigured AI error cannot create a session', (t) async {
    final s = MemoryStore();
    addTearDown(s.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: ContextAssistSheet(
          store: s,
          initialTool: 'AI focus coach',
          client: MockClient(
            (_) async => http.Response('{"error":"AI is not configured"}', 503),
          ),
        ),
      ),
    );

    await t.enterText(find.byType(TextField), 'Study');
    await tapText(t, 'Review a suggestion');
    expect(find.text('AI is not configured'), findsOneWidget);
    expect(s.sessions, isEmpty);
    expect(find.text('Approve'), findsNothing);
  });
}
