import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:mobile_project/app/app.dart';
import 'package:mobile_project/core/services/app_session.dart';
import 'package:mobile_project/features/account/account_screens.dart';

Map<String, dynamic> account({
  String language = 'en',
  String theme = 'light',
}) => {
  'id': 'eya',
  'name': 'Eya',
  'email': 'eya@example.com',
  'email_verified_at': null,
  'timezone': 'Africa/Tunis',
  'language': language,
  'preferences': {'theme': theme, 'cloud_ai': false},
};
void main() {
  setUp(() {
    tz.initializeTimeZones();
    FlutterSecureStorage.setMockInitialValues({});
  });
  testWidgets('registration validation and truthful recovery on phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = AppSession()..restoring = false;
    addTearDown(session.dispose);
    await tester.pumpWidget(PlanifyApp(session: session));
    await tester.pumpAndSettle();
    expect(find.text('Planify'), findsOneWidget);
    await tester.ensureVisible(find.text('Create an account'));
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create my account'));
    await tester.tap(find.text('Create my account'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Use 2–80 characters.'), findsOneWidget);
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Forgot password?'));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No reset email has been sent.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'authenticated navigation, preference save, localization, privacy and insights',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <http.Request>[];
      final session =
          AppSession(
              client: MockClient((request) async {
                requests.add(request);
                if (request.url.path.endsWith('analytics')) {
                  return http.Response(
                    jsonEncode({
                      'status': 'unavailable',
                      'generated_at': '2026-10-20T10:00:00Z',
                    }),
                    200,
                  );
                }
                final changes = request.body.isEmpty
                    ? <String, dynamic>{}
                    : jsonDecode(request.body) as Map<String, dynamic>;
                return http.Response(
                  jsonEncode(
                    account(
                      language: changes['language'] as String? ?? 'en',
                      theme: changes['theme'] as String? ?? 'light',
                    ),
                  ),
                  200,
                );
              }),
            )
            ..restoring = false
            ..account = Account.fromJson(account());
      addTearDown(session.dispose);
      await tester.pumpWidget(PlanifyApp(session: session));
      await tester.pumpAndSettle();
      expect(find.text('Hello, Eya.'), findsOneWidget);
      await tester.tap(find.text('Preferences'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save preferences'));
      await tester.tap(find.text('Save preferences'));
      await tester.pumpAndSettle();
      expect(requests.last.method, 'PATCH');
      expect(session.account!.theme, 'dark');
      await tester.tap(find.text('Privacy'));
      await tester.pumpAndSettle();
      expect(find.text('Cloud AI, only if you choose'), findsOneWidget);
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();
      expect(find.text('Your story is taking shape.'), findsOneWidget);
      expect(requests.last.url.queryParameters['from'], isNotNull);
      expect(tester.takeException(), isNull);
      session.account = Account.fromJson(account(language: 'fr'));
      session.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('Statistiques'), findsWidgets);
    },
  );
  testWidgets('account pages fit narrow phones with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = AppSession()
      ..restoring = false
      ..account = Account.fromJson(account());
    addTearDown(session.dispose);
    await tester.pumpWidget(PlanifyApp(session: session));
    await tester.pumpAndSettle();
    expect(find.text('Hello, Eya.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Preferences'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  test('week and month ranges respect DST and calendar boundaries', () {
    final spring = analyticsRange(
      'Europe/Paris',
      'week',
      DateTime.utc(2026, 3, 29, 12),
    );
    expect(spring.from, DateTime.utc(2026, 3, 22, 23));
    expect(spring.to, DateTime.utc(2026, 3, 29, 22));
    final january = analyticsRange(
      'Africa/Tunis',
      'month',
      DateTime.utc(2026, 1, 1, 1),
    );
    expect(january.from, DateTime.utc(2025, 12, 31, 23));
    expect(january.to, DateTime.utc(2026, 1, 1, 23));
  });
  test(
    'session restores from secure storage and clears on server revocation',
    () async {
      final expires = DateTime.now()
          .add(const Duration(days: 1))
          .toIso8601String();
      FlutterSecureStorage.setMockInitialValues({
        AppSession.tokenKey: jsonEncode({
          'token': 'secret',
          'expires_at': expires,
        }),
      });
      var revoked = false;
      final session = AppSession(
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer secret');
          return revoked
              ? http.Response(
                  jsonEncode({
                    'error': {'message': 'Session ended', 'fields': {}},
                  }),
                  401,
                )
              : http.Response(jsonEncode(account()), 200);
        }),
      );
      addTearDown(session.dispose);
      await session.restore();
      expect(session.account!.id, 'eya');
      revoked = true;
      await expectLater(
        session.request('GET', '/users/me'),
        throwsA(isA<ApiFailure>()),
      );
      expect(session.account, isNull);
      expect(await session.storage.read(key: AppSession.tokenKey), isNull);
    },
  );
  test(
    'offline logout clears local token even when revocation fails',
    () async {
      FlutterSecureStorage.setMockInitialValues({AppSession.tokenKey: 'saved'});
      final session = AppSession(
        client: MockClient((_) async => throw http.ClientException('offline')),
      )..account = Account.fromJson(account());
      addTearDown(session.dispose);
      expect(await session.signOut(), false);
      expect(session.account, isNull);
      expect(await session.storage.read(key: AppSession.tokenKey), isNull);
    },
  );
}
