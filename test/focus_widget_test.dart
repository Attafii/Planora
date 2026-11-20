// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_project/main.dart';

void main() {
  testWidgets('creates a focus session from the session form', (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Nouvelle session'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Réviser Dart');
    await tester.tap(find.text('Enregistrer').last);
    await tester.pumpAndSettle();

    expect(find.text('Réviser Dart'), findsOneWidget);
    expect(find.textContaining('25 min estimées'), findsOneWidget);
    expect(find.text('Démarrer'), findsOneWidget);
  });
}
