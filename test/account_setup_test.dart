import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_project/core/services/app_session.dart';
import 'package:mobile_project/features/account/account_setup.dart';

class SetupDisk implements SharedPreferencesAsync {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  final values = <String, String>{};
  @override
  Future<String?> getString(String key) async => values[key];
  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  testWidgets(
    'manual setup remains usable without AI; drafts resume after offline failure',
    (tester) async {
      final disk = SetupDisk();
      var online = false;
      var aiCalls = 0;
      final profile = {
        'id': 'setup-test',
        'name': 'Test',
        'email': 'test@example.test',
        'timezone': 'Africa/Tunis',
        'language': 'en',
        'preferences': {'theme': 'system', 'cloud_ai': false},
      };
      final session =
          AppSession(
              client: MockClient((req) async {
                if (req.url.path.endsWith('-assist')) aiCalls++;
                if (!online) throw http.ClientException('offline');
                return http.Response(
                  jsonEncode({
                    'revision': 1,
                    'status': 'draft',
                    'draft': jsonDecode(req.body)['draft'],
                  }),
                  200,
                );
              }),
            )
            ..account = Account.fromJson(profile)
            ..restoring = false;
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSetupPage(session: session, storage: disk),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'I prefer French and dark mode',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ask AI for suggestions'));
      await tester.pumpAndSettle();
      expect(aiCalls, 0);
      expect(find.textContaining('Enable Cloud AI in Privacy'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSetupPage(session: session, storage: disk),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('I prefer French and dark mode'), findsOneWidget);
      online = true;
      await tester.ensureVisible(find.text('Save draft for later'));
      await tester.tap(find.text('Save draft for later'));
      await tester.pumpAndSettle();
      expect(jsonDecode(disk.values.values.single)['pending'], false);
      expect(session.account?.theme, 'system');
      expect(tester.takeException(), isNull);
    },
  );
}
