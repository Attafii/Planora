import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/focus_session.dart';

class FocusSessionController extends ChangeNotifier {
  final List<FocusSession> _sessions = [];
  Timer? _timer;
  String? _activeSessionId;
  int _pomodoroSecondsRemaining = 25 * 60;
  bool _isPomodoroBreak = false;

  List<FocusSession> get sessions => List.unmodifiable(_sessions);

  FocusSession? get activeSession =>
      _activeSessionId == null ? null : _find(_activeSessionId!);

  int get timerSecondsRemaining {
    final session = activeSession;
    if (session == null) return 0;
    if (session.mode == FocusMode.pomodoro) return _pomodoroSecondsRemaining;
    return (session.estimatedDurationMinutes * 60 - session.elapsedSeconds)
        .clamp(0, 1 << 31);
  }

  bool get isPomodoroBreak => _isPomodoroBreak;

  FocusSession createSession({
    required String title,
    required int estimatedDurationMinutes,
    required FocusMode mode,
  }) {
    final now = DateTime.now();
    final session = FocusSession(
      id: '${now.microsecondsSinceEpoch}-${_sessions.length}',
      title: title.trim(),
      mode: mode,
      status: FocusSessionStatus.planned,
      estimatedDurationMinutes: estimatedDurationMinutes,
      elapsedSeconds: 0,
      notes: '',
      log: const [],
      createdAt: now,
    );
    _sessions.insert(0, session);
    notifyListeners();
    return session;
  }

  void updateSession(
    String id, {
    required String title,
    required int estimatedDurationMinutes,
    required FocusMode mode,
  }) {
    _replace(
      id,
      (session) => session.copyWith(
        title: title.trim(),
        estimatedDurationMinutes: estimatedDurationMinutes,
        mode: mode,
      ),
    );
    if (_activeSessionId == id && mode != FocusMode.pomodoro) {
      _isPomodoroBreak = false;
    }
  }

  void deleteSession(String id) {
    if (_activeSessionId == id) _stopTimer();
    _sessions.removeWhere((session) => session.id == id);
    notifyListeners();
  }

  void archiveSession(String id) {
    if (_activeSessionId == id) _stopTimer();
    _replace(
      id,
      (session) => session.copyWith(status: FocusSessionStatus.archived),
    );
  }

  void restoreSession(String id) {
    _replace(
      id,
      (session) => session.copyWith(status: FocusSessionStatus.paused),
    );
  }

  void startSession(String id) {
    if (_activeSessionId != id && _activeSessionId != null) pauseSession();
    final session = _find(id);
    if (session == null || session.status == FocusSessionStatus.archived)
      return;
    _activeSessionId = id;
    _isPomodoroBreak = false;
    _pomodoroSecondsRemaining = 25 * 60;
    _replace(id, (item) => item.copyWith(status: FocusSessionStatus.active));
    _startTimer();
  }

  void resumeSession(String id) {
    if (_activeSessionId != id) {
      _activeSessionId = id;
      _isPomodoroBreak = false;
      _pomodoroSecondsRemaining = 25 * 60;
    }
    _replace(
      id,
      (session) => session.copyWith(status: FocusSessionStatus.active),
    );
    _startTimer();
  }

  void pauseSession() {
    final id = _activeSessionId;
    if (id == null) return;
    _stopTimer();
    _replace(
      id,
      (session) => session.copyWith(status: FocusSessionStatus.paused),
    );
  }

  void completeSession(String id) {
    if (_activeSessionId == id) _stopTimer();
    _replace(
      id,
      (session) => session.copyWith(status: FocusSessionStatus.completed),
    );
  }

  void updateNotes(String id, String notes) {
    _replace(id, (session) => session.copyWith(notes: notes.trim()));
  }

  void logInterruption(String id, String description) {
    if (description.trim().isEmpty || _find(id) == null) return;
    if (_activeSessionId == id) pauseSession();
    _addLog(id, SessionLogKind.interruption, description.trim());
  }

  void markBlocked(String id, String description) {
    if (description.trim().isEmpty || _find(id) == null) return;
    if (_activeSessionId == id) pauseSession();
    _addLog(id, SessionLogKind.blocked, description.trim());
  }

  void requestMoreTime(String id, {int extraMinutes = 10}) {
    if (extraMinutes <= 0 || _find(id) == null) return;
    _replace(
      id,
      (item) => item.copyWith(
        estimatedDurationMinutes: item.estimatedDurationMinutes + extraMinutes,
      ),
    );
    _addLog(
      id,
      SessionLogKind.extension,
      'Durée cible prolongée de $extraMinutes min',
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _activeSessionId = null;
  }

  void _tick() {
    final id = _activeSessionId;
    final session = id == null ? null : _find(id);
    if (id == null || session == null) {
      _stopTimer();
      return;
    }
    _replace(
      id,
      (item) => item.copyWith(elapsedSeconds: item.elapsedSeconds + 1),
      notify: false,
    );
    if (session.mode == FocusMode.pomodoro) {
      _pomodoroSecondsRemaining--;
      if (_pomodoroSecondsRemaining <= 0) {
        _isPomodoroBreak = !_isPomodoroBreak;
        _pomodoroSecondsRemaining = _isPomodoroBreak ? 5 * 60 : 25 * 60;
      }
    }
    notifyListeners();
  }

  void _addLog(String id, SessionLogKind kind, String description) {
    final session = _find(id);
    if (session == null) return;
    final now = DateTime.now();
    final entry = SessionLogEntry(
      id: now.microsecondsSinceEpoch.toString(),
      kind: kind,
      description: description,
      elapsedSeconds: session.elapsedSeconds,
      createdAt: now,
    );
    _replace(id, (item) => item.copyWith(log: [...item.log, entry]));
  }

  FocusSession? _find(String? id) {
    for (final session in _sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  void _replace(
    String id,
    FocusSession Function(FocusSession) update, {
    bool notify = true,
  }) {
    final index = _sessions.indexWhere((session) => session.id == id);
    if (index < 0) return;
    _sessions[index] = update(_sessions[index]);
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
