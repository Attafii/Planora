import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/features/focus_sessions/controllers/focus_session_controller.dart';
import 'package:mobile_project/features/focus_sessions/models/focus_session.dart';

void main() {
  late FocusSessionController controller;

  setUp(() => controller = FocusSessionController());
  tearDown(() => controller.dispose());

  test('creates, updates, archives, restores, and deletes sessions', () {
    final session = controller.createSession(
      title: '  Lire  ',
      estimatedDurationMinutes: 30,
      mode: FocusMode.focus,
    );
    expect(session.title, 'Lire');
    expect(controller.sessions, hasLength(1));

    controller.updateSession(
      session.id,
      title: 'Écrire',
      estimatedDurationMinutes: 45,
      mode: FocusMode.pomodoro,
    );
    expect(controller.sessions.single.title, 'Écrire');
    expect(controller.sessions.single.estimatedDurationMinutes, 45);

    controller.archiveSession(session.id);
    expect(controller.sessions.single.status, FocusSessionStatus.archived);
    controller.restoreSession(session.id);
    expect(controller.sessions.single.status, FocusSessionStatus.paused);
    controller.deleteSession(session.id);
    expect(controller.sessions, isEmpty);
  });

  test('logs interruptions and extends the target duration', () {
    final session = controller.createSession(
      title: 'Préparer la présentation',
      estimatedDurationMinutes: 25,
      mode: FocusMode.pomodoro,
    );

    controller.markBlocked(session.id, 'Attente d’une réponse');
    controller.requestMoreTime(session.id);

    final updated = controller.sessions.single;
    expect(updated.estimatedDurationMinutes, 35);
    expect(updated.log, hasLength(2));
    expect(updated.log.first.kind, SessionLogKind.blocked);
    expect(updated.log.last.kind, SessionLogKind.extension);
  });
}
