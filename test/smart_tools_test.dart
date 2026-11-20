import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/features/focus/focus_store.dart';
import 'package:mobile_project/features/focus/smart_tools.dart';

void main() {
  test('Adaptive focus has a cold start and reduces interrupted blocks', () {
    expect(adaptiveMinutes([]), 25);
    final sessions = List.generate(
      4,
      (i) => FocusSession(
        id: '$i',
        title: 'Work',
        mode: 'Countdown',
        minutes: 50,
        created: DateTime(2026),
        seconds: 3000,
        status: 'completed',
        logs: ['Interruption: phone'],
      ),
    );
    expect(adaptiveMinutes(sessions), 40);
    sessions.first.seconds = 999999;
    expect(adaptiveMinutes(sessions), lessThanOrEqualTo(60));
  });
  test('Reminder guard avoids quiet hours and adjacent recurring alerts', () {
    final r = Reminder(
      id: '1',
      title: 'Daily',
      when: DateTime(2026, 11, 2, 8),
      repeat: 'Daily',
    );
    expect(
      safeReminderSlot(DateTime(2026, 11, 1, 23), [r]),
      DateTime(2026, 11, 2, 8, 10),
    );
    expect(
      safeReminderSlot(DateTime(2026, 11, 2, 8), [r], excluding: '1'),
      DateTime(2026, 11, 2, 8),
    );
  });
}
