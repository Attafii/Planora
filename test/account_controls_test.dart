import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_project/app/theme/app_theme.dart';
import 'package:mobile_project/core/services/app_session.dart';
import 'package:mobile_project/features/account/account_controls.dart';
import 'package:timezone/data/latest.dart' as tz;

http.Response json(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status);
AppSession session(Future<http.Response> Function(http.Request) handler) =>
    AppSession(client: MockClient(handler))
      ..restoring = false
      ..account = Account.fromJson({
        'id': 'eya',
        'name': 'Eya',
        'email': 'eya@example.com',
        'timezone': 'Africa/Tunis',
        'language': 'en',
        'preferences': {'theme': 'light', 'cloud_ai': false},
      });
Widget host(Widget child, {String language = 'en'}) => MaterialApp(
  theme: PlanifyTheme.build(Brightness.light),
  locale: Locale(language),
  supportedLocales: const [Locale('en'), Locale('fr')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: child,
    ),
  ),
);
void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> modalFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() {
    tz.initializeTimeZones();
    FlutterSecureStorage.setMockInitialValues({});
  });
  testWidgets(
    'public help searches locally, handles no matches, and restores all topics',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(host(const AccountHelpPage()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'sessions');
      await tester.pumpAndSettle();
      expect(find.text('Sessions and devices'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'no-such-topic');
      await tester.pumpAndSettle();
      expect(find.textContaining('No matching topic.'), findsOneWidget);
      await tester.ensureVisible(find.text('Show all topics'));
      await tester.tap(find.text('Show all topics'));
      await tester.pumpAndSettle();
      expect(find.text('Signing in and recovery'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'session revoke requires confirmation, refreshes devices, and fits a narrow phone',
    (tester) async {
      phone(tester);
      var revoked = false;
      var deletes = 0;
      final s = session((r) async {
        if (r.method == 'DELETE') {
          revoked = true;
          deletes++;
          return json({'success': true});
        }
        if (r.url.path.endsWith('notices')) {
          return json({
            'notices': [
              if (revoked)
                {
                  'id': 'notice',
                  'type': 'session_revoked',
                  'created_at': '2026-10-20T09:00:00Z',
                  'read_at': null,
                },
            ],
          });
        }
        return json({
          'sessions': [
            {
              'id': 'current',
              'current': true,
              'device': 'Windows · Chrome',
              'created_at': '2026-10-20T09:00:00Z',
              'expires_at': '2026-10-27T09:00:00Z',
            },
            if (!revoked)
              {
                'id': 'other',
                'current': false,
                'device': 'Android · Planify app',
                'last_used_at': '2026-10-20T09:00:00Z',
              },
          ],
        });
      });
      addTearDown(s.dispose);
      await tester.pumpWidget(host(SecurityPage(session: s)));
      await modalFrame(tester);
      await tester.ensureVisible(find.text('Revoke session'));
      await tester.tap(find.text('Revoke session'));
      await modalFrame(tester);
      expect(deletes, 0);
      await tester.tap(find.text('Cancel'));
      await modalFrame(tester);
      expect(deletes, 0);
      await tester.tap(find.text('Revoke session'));
      await modalFrame(tester);
      await tester.tap(find.text('Confirm'));
      await modalFrame(tester);
      expect(deletes, 1);
      expect(find.text('Android · Planify app'), findsNothing);
      expect(find.text('A session was signed out.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('resource retry recovers after an API error', (tester) async {
    var attempts = 0;
    final s = session((_) async {
      attempts++;
      return attempts == 1
          ? json({
              'error': {'message': 'Temporarily offline', 'fields': {}},
            }, 503)
          : json({'ok': true});
    });
    addTearDown(s.dispose);
    await tester.pumpWidget(
      host(
        AccountResource(
          session: s,
          path: '/users/me/sessions',
          builder: (_, _) => const Text('Devices ready'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Temporarily offline'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Devices ready'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets(
    'privacy preview shows null as unavailable and policy status without starting actions',
    (tester) async {
      phone(tester);
      final requests = <http.Request>[];
      final s = session((r) async {
        requests.add(r);
        if (r.url.path.endsWith('data-tools')) {
          return json({'available': false, 'exports': []});
        }
        return json({
          'version': 'personal-insights-v1',
          'provider_available': false,
          'consent': {'enabled': false},
          'context': {
            'timezone': 'Africa/Tunis',
            'range': {
              'from': '2026-10-01T00:00:00Z',
              'to': '2026-10-20T00:00:00Z',
            },
            'tasks_completed': null,
            'goals_completed': null,
          },
        });
      });
      addTearDown(s.dispose);
      await tester.pumpWidget(host(AccountPrivacyPage(session: s)));
      await tester.pumpAndSettle();
      expect(find.text('Completed tasks · Unavailable'), findsOneWidget);
      expect(find.text('Allow these insight fields'), findsNothing);
      await tester.ensureVisible(find.text('Not available · policy pending'));
      await tester.pumpAndSettle();
      expect(find.text('Create secure export'), findsNothing);
      expect(find.text('Review account deletion'), findsNothing);
      expect(requests.every((r) => r.method == 'GET'), true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opting out updates purpose-specific consent and removes enabled state',
    (tester) async {
      var enabled = true;
      final methods = <String>[];
      final s = session((r) async {
        methods.add(r.method);
        if (r.method == 'PATCH') {
          expect(jsonDecode(r.body)['enabled'], false);
          enabled = false;
          return json({'enabled': false});
        }
        return json({
          'version': 'personal-insights-v1',
          'provider_available': true,
          'provider': 'Test provider',
          'retention_notice': 'No remote test calls',
          'consent': {'enabled': enabled},
          'context': {
            'timezone': 'Africa/Tunis',
            'tasks_completed': 0,
            'goals_completed': 0,
          },
        });
      });
      addTearDown(s.dispose);
      await tester.pumpWidget(host(PrivacyContextCard(session: s)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Withdraw consent'));
      await tester.tap(find.text('Withdraw consent'));
      await tester.pumpAndSettle();
      expect(find.text('Personal insights consent: off'), findsOneWidget);
      expect(methods.where((m) => m == 'PATCH').length, 1);
    },
  );

  testWidgets(
    'export requires password confirmation and shows a wrong-password error without submitting',
    (tester) async {
      var exports = 0;
      final s = session((r) async {
        if (r.url.path.endsWith('reauthenticate')) {
          return json({
            'error': {'message': 'Password is incorrect.', 'fields': {}},
          }, 403);
        }
        if (r.url.path.endsWith('export')) {
          exports++;
          return json({'id': 'test-export'});
        }
        return json({
          'available': true,
          'policy': {
            'retentionNotice': 'Fixture account records only.',
            'backupNotice': 'No fixture backups.',
            'recoverySeconds': 60,
          },
          'exports': [],
        });
      });
      addTearDown(s.dispose);
      await tester.pumpWidget(host(PersonalDataCard(session: s)));
      await modalFrame(tester);
      await tester.ensureVisible(find.text('Create secure export'));
      await tester.tap(find.text('Create secure export'));
      await modalFrame(tester);
      await tester.enterText(
        find.byType(TextField),
        'incorrect example password',
      );
      await tester.tap(find.text('Continue'));
      await modalFrame(tester);
      expect(find.text('Password is incorrect.'), findsOneWidget);
      expect(exports, 0);
      expect(s.account, isNotNull);
      await tester.tap(find.text('Cancel'));
      await modalFrame(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'approved export flows from password confirmation to a private JSON view',
    (tester) async {
      var created = false, consumed = false;
      final s = session((r) async {
        if (r.url.path.endsWith('reauthenticate')) {
          return json({'confirmed': true});
        }
        if (r.method == 'POST' && r.url.path.endsWith('/export')) {
          created = true;
          return json({'id': 'owned-export'});
        }
        if (r.url.path.endsWith('/export/owned-export')) {
          consumed = true;
          return json({
            'content': {
              'profile': {'name': 'Eya export fixture'},
            },
          });
        }
        return json({
          'available': true,
          'policy': {
            'retentionNotice': 'Test account only.',
            'backupNotice': 'No test backups.',
            'recoverySeconds': 60,
          },
          'exports': [
            if (created)
              {
                'id': 'owned-export',
                'expires_at': '2026-10-20T09:00:00Z',
                'consumed_at': consumed ? '2026-10-20T08:00:00Z' : null,
              },
          ],
        });
      });
      addTearDown(s.dispose);
      await tester.pumpWidget(host(PersonalDataCard(session: s)));
      await modalFrame(tester);
      await tester.ensureVisible(find.text('Create secure export'));
      await tester.tap(find.text('Create secure export'));
      await modalFrame(tester);
      expect(created, false);
      await tester.enterText(find.byType(TextField), 'Valid fixture password');
      await tester.tap(find.text('Continue'));
      await modalFrame(tester);
      expect(created, true);
      await tester.ensureVisible(find.text('Download JSON export'));
      await tester.tap(find.text('Download JSON export'));
      await modalFrame(tester);
      await tester.enterText(find.byType(TextField), 'Valid fixture password');
      await tester.tap(find.text('Continue'));
      await modalFrame(tester);
      expect(find.text('Your account export'), findsOneWidget);
      expect(find.textContaining('Eya export fixture'), findsOneWidget);
      expect(consumed, true);
      await tester.tap(find.text('Close'));
      await modalFrame(tester);
      expect(
        find.text('Downloaded · create a new export to download again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'approved deletion requires consequences, password and typed confirmation and can be cancelled',
    (tester) async {
      var scheduled = false;
      var deletionRequests = 0;
      final s = session((r) async {
        if (r.url.path.endsWith('reauthenticate')) {
          return json({'confirmed': true});
        }
        if (r.url.path.endsWith('/deletion')) {
          scheduled = r.method == 'POST';
          deletionRequests++;
          if (scheduled) expect(jsonDecode(r.body)['confirmation'], 'DELETE');
          return json({'success': true});
        }
        return json({
          'available': true,
          'policy': {
            'retentionNotice': 'Test account records only.',
            'backupNotice': 'No test backups.',
            'recoverySeconds': 60,
          },
          'exports': [],
          'deletion': scheduled
              ? {'status': 'scheduled', 'execute_at': '2026-10-20T09:00:00Z'}
              : null,
        });
      });
      addTearDown(s.dispose);
      await tester.pumpWidget(host(PersonalDataCard(session: s)));
      await modalFrame(tester);
      await tester.ensureVisible(find.text('Review account deletion'));
      await tester.tap(find.text('Review account deletion'));
      await modalFrame(tester);
      expect(deletionRequests, 0);
      expect(find.text('Review deletion consequences'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await modalFrame(tester);
      await tester.enterText(
        find.byType(TextField).first,
        'Valid fixture password',
      );
      await tester.enterText(find.byType(TextField).last, 'DELETE');
      await tester.tap(find.text('Continue'));
      await modalFrame(tester);
      expect(scheduled, true);
      expect(deletionRequests, 1);
      await tester.ensureVisible(find.text('Cancel deletion'));
      await tester.tap(find.text('Cancel deletion'));
      await modalFrame(tester);
      await tester.enterText(find.byType(TextField), 'Valid fixture password');
      await tester.tap(find.text('Continue'));
      await modalFrame(tester);
      expect(scheduled, false);
      expect(deletionRequests, 2);
      expect(find.text('Cancel deletion'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
