import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_project/app/app_services.dart';
import 'package:mobile_project/core/network/api_client.dart';
import 'package:mobile_project/features/assistant/presentation/chat_page.dart';
import 'package:mobile_project/features/collaboration/presentation/project_workspace.dart';

void main() {
  testWidgets(
    'cloud errors preserve the draft and retry waits for a slow reply',
    (tester) async {
      var sends = 0;
      final messages = <JsonMap>[];
      final client = ApiClient(
        client: MockClient((req) async {
          if (req.url.path == '/assistant/messages') {
            sends++;
            expect(jsonDecode(req.body)['use_cloud'], isTrue);
            if (sends == 1) {
              return http.Response(
                jsonEncode({
                  'error': {
                    'message': 'Cloud AI is busy. Retry shortly.',
                    'code': 'ai_rate_limited',
                  },
                }),
                429,
              );
            }
            await Future<void>.delayed(const Duration(seconds: 40));
            messages.addAll([
              {'id': 'm1', 'role': 'user', 'body': 'Summarize QA work'},
              {
                'id': 'm2',
                'role': 'assistant',
                'body': 'Your QA work is ready to review.',
              },
            ]);
            return http.Response(
              jsonEncode({'message': 'Your QA work is ready to review.'}),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'id': 'c1',
              'title': 'QA chat',
              'messages': messages,
              'proposals': [],
            }),
            200,
          );
        }),
        baseUrl: 'http://planify.test',
      );
      final services = AppServices(client: client);
      await tester.pumpWidget(
        AppScope(
          services: services,
          child: const MaterialApp(home: ChatPage(id: 'c1')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Local assistant'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Use cloud AI'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Summarize QA work');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(find.text('Cloud AI is busy. Retry shortly.'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Summarize QA work',
      );
      // The error must remain visible after a snackbar would have disappeared.
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Retry message'), findsOneWidget);
      await tester.tap(find.text('Retry message'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 36));
      expect(
        find.text('Waiting for cloud AI. Free models can take up to a minute.'),
        findsOneWidget,
      );
      expect(sends, 2);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText &&
              widget.data == 'Your QA work is ready to review.',
        ),
        findsOneWidget,
      );
      expect(find.text('Retry message'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      client.close();
    },
  );

  testWidgets('returning from project assistant reloads shared work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var projectReads = 0;
    final client = ApiClient(
      client: MockClient((req) async {
        if (req.url.path == '/projects/p1') {
          projectReads++;
          return http.Response(
            jsonEncode({
              'id': 'p1',
              'title': 'QA project',
              'role': 'owner',
              'members': [],
              'tasks': [],
              'goals': projectReads > 1
                  ? [
                      {
                        'id': 'g1',
                        'title': 'New assistant outcome',
                        'status': 'active',
                      },
                    ]
                  : [],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'id': 'c1',
            'title': 'Project chat',
            'messages': [],
            'proposals': [],
          }),
          200,
        );
      }),
      baseUrl: 'http://planify.test',
    );
    final services = AppServices(client: client);
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: const MaterialApp(home: ProjectWorkspace(id: 'p1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask assistant'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(projectReads, 2);
    expect(find.text('New assistant outcome'), findsOneWidget);
    expect(tester.takeException(), isNull);
    client.close();
  });
}
