enum FocusMode { free, focus, pomodoro }

enum FocusSessionStatus { planned, active, paused, completed, archived }

enum SessionLogKind { interruption, blocked, extension }

class SessionLogEntry {
  const SessionLogEntry({
    required this.id,
    required this.kind,
    required this.description,
    required this.elapsedSeconds,
    required this.createdAt,
  });

  final String id;
  final SessionLogKind kind;
  final String description;
  final int elapsedSeconds;
  final DateTime createdAt;
}

class FocusSession {
  const FocusSession({
    required this.id,
    required this.title,
    required this.mode,
    required this.status,
    required this.estimatedDurationMinutes,
    required this.elapsedSeconds,
    required this.notes,
    required this.log,
    required this.createdAt,
  });

  final String id;
  final String title;
  final FocusMode mode;
  final FocusSessionStatus status;
  final int estimatedDurationMinutes;
  final int elapsedSeconds;
  final String notes;
  final List<SessionLogEntry> log;
  final DateTime createdAt;

  bool get exceededEstimate => elapsedSeconds >= estimatedDurationMinutes * 60;

  FocusSession copyWith({
    String? title,
    FocusMode? mode,
    FocusSessionStatus? status,
    int? estimatedDurationMinutes,
    int? elapsedSeconds,
    String? notes,
    List<SessionLogEntry>? log,
  }) {
    return FocusSession(
      id: id,
      title: title ?? this.title,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      notes: notes ?? this.notes,
      log: log ?? this.log,
      createdAt: createdAt,
    );
  }
}
