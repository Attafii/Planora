import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_project/app/app.dart';
import 'package:mobile_project/app/app_services.dart';
import 'package:mobile_project/core/network/api_client.dart';
import 'package:mobile_project/core/services/storage_service.dart';
import 'package:mobile_project/core/utils/validators.dart';

class MemoryTokens implements TokenStore {
  MemoryTokens([this.value]);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async => value = token;
  @override
  Future<void> clear() async => value = null;
}

const user = {
  'id': 'user-1',
  'name': 'Ahmed',
  'email': 'ahmed@planify.test',
  'timezone': 'Africa/Tunis',
};

class TestApi {
  int goalWrites = 0;
  bool failGoals = false;
  final List<JsonMap> goals = [];
  http.Response respond(http.Request req) {
    Object data;
    int status = 200;
    switch (req.url.path) {
      case '/auth/me':
        data = user;
      case '/auth/login':
        data = {'user': user, 'token': 'test-token'};
      case '/auth/logout':
        data = {'signed_out': true};
      case '/goals':
        if (failGoals) {
          status = 503;
          data = {
            'error': {
              'message': 'Service is temporarily unavailable.',
              'code': 'unavailable',
            },
          };
        } else if (req.method == 'POST') {
          goalWrites++;
          final d = jsonDecode(req.body) as JsonMap;
          final g = {
            ...d,
            'id': 'goal-$goalWrites',
            'progress': 0,
            'item_count': 0,
            'can_edit': true,
            'milestones': [],
            'tasks': [],
          };
          goals.add(g);
          data = g;
        } else {
          data = {'items': goals, 'has_more': false};
        }
      case '/projects':
        data = {'items': [], 'has_more': false};
      case '/assistant/conversations':
        data = {'items': [], 'has_more': false};
      case '/gamification/summary':
        data = {
          'points': 0,
          'level': 1,
          'level_progress': 0,
          'streak': 0,
          'streak_rule': 'Weekends are rest days.',
          'achievements': [],
        };
      default:
        data = {};
    }
    return http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json'},
    );
  }
}

AppServices services(TestApi backend, {bool signedIn = true}) => AppServices(
  client: ApiClient(
    client: MockClient((r) async => backend.respond(r)),
    baseUrl: 'http://planify.test',
  ),
  tokens: MemoryTokens(signedIn ? 'test-token' : null),
);
void main() {
  test('validation rejects impossible dates and accepts meaningful values', () {
    expect(Validators.date('2026-02-30'), isNotNull);
    expect(Validators.date('2026-10-13'), isNull);
    expect(Validators.minutes('0'), isNotNull);
    expect(Validators.minutes('45'), isNull);
    expect(Validators.email('ahmed@planify.test'), isNull);
    expect(Validators.required('  '), isNotNull);
  });
  testWidgets('account form validates before making an API request', (
    tester,
  ) async {
    final s = services(TestApi(), signedIn: false);
    await tester.pumpWidget(PlanifyApp(services: s));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Use at least 10 characters.'), findsWidgets);
    expect(s.session.user, isNull);
    s.api.close();
  });
  testWidgets('goal form saves a repository mutation and returns to the list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final backend = TestApi(), s = services(backend);
    await tester.pumpWidget(PlanifyApp(services: s));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New goal'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Goal title'),
      'Finish my revision',
    );
    await tester.ensureVisible(find.text('Save goal'));
    await tester.tap(find.text('Save goal'));
    await tester.pumpAndSettle();
    expect(backend.goalWrites, 1);
    expect(find.text('Finish my revision'), findsOneWidget);
    expect(tester.takeException(), isNull);
    s.api.close();
  });
  testWidgets('API failure provides a working retry and honest empty state', (
    tester,
  ) async {
    final backend = TestApi()..failGoals = true, s = services(backend);
    await tester.pumpWidget(PlanifyApp(services: s));
    await tester.pumpAndSettle();
    expect(find.text('Service is temporarily unavailable.'), findsOneWidget);
    backend.failGoals = false;
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Make space for an outcome'), findsOneWidget);
    s.api.close();
  });
  testWidgets('navigation and layouts fit phone, tablet and desktop widths', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final width in [320.0, 375.0, 414.0, 768.0, 1024.0, 1440.0, 2000.0]) {
      tester.view.physicalSize = Size(width, 1000);
      final s = services(TestApi());
      await tester.pumpWidget(PlanifyApp(key: ValueKey(width), services: s));
      await tester.pumpAndSettle();
      expect(find.text('Your goals'), findsOneWidget);
      for (final name in ['Projects', 'Assistant', 'Achievements', 'Goals']) {
        await tester.tap(find.text(name).first);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Layout or navigation failed at $width / $name',
        );
      }
      await tester.pumpWidget(const SizedBox());
      s.api.close();
    }
  });
  test('expired API token clears the authenticated session', () async {
    final tokens = MemoryTokens('expired'),
        client = ApiClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'error': {'message': 'Expired', 'code': 'unauthenticated'},
              }),
              401,
            ),
          ),
          baseUrl: 'http://planify.test',
        );
    final s = AppSession(client, tokens);
    await s.initialize();
    await Future<void>.delayed(Duration.zero);
    expect(s.user, isNull);
    expect(client.token, isNull);
    expect(tokens.value, isNull);
    client.close();
    s.dispose();
  });
}
