import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/features/assistant/presentation/message_chart.dart';

void main() {
  testWidgets(
    'record chart remains readable on a narrow screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: MessageChart(
                  data: {
                    'title': 'Personal tasks',
                    'unit': 'tasks',
                    'source': 'Last synchronized task records',
                    'generated_at': '2026-11-21T12:00:00Z',
                    'items': [
                      {'label': 'completed', 'value': 3},
                      {'label': 'todo', 'value': 0},
                    ],
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('completed: 3'), findsOneWidget);
      expect(find.text('todo: 0'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
