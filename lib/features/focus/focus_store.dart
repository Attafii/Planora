import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/notification_service.dart';
import '../../core/services/personal_sync.dart';
import 'focus_task_link.dart';

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

class FocusSession {
  FocusSession({
    required this.id,
    required this.title,
    required this.mode,
    required this.minutes,
    required this.created,
    this.seconds = 0,
    this.status = 'running',
    this.anchor,
    this.breakUntil,
    this.notes = '',
    this.logs = const [],
    this.ended,
    this.taskCompleted = false,
    this.scheduled,
    this.accumulatedMillis,
  });
  String id, title, mode, status, notes;
  int minutes, seconds;
  DateTime created;
  DateTime? anchor, breakUntil, ended;
  List<String> logs;
  bool taskCompleted;
  final ScheduledFocus? scheduled;
  int? accumulatedMillis;

  int elapsedMillis(DateTime now) =>
      (accumulatedMillis ?? seconds * 1000) +
      (anchor == null || status != 'running'
          ? 0
          : now.difference(anchor!).inMilliseconds.clamp(0, 2147483648000));
  int elapsed(DateTime now) => elapsedMillis(now) ~/ 1000;
  bool get finished =>
      status == 'completed' || status == 'endedEarly' || status == 'cancelled';
  bool get interrupted => logs.any(
    (entry) =>
        entry.startsWith('Interruption:') || entry.startsWith('Blocked:'),
  );
  String get statusLabel => switch (status) {
    'completed' => 'Completed',
    'endedEarly' => 'Ended early',
    'cancelled' => 'Abandoned',
    'paused' => interrupted ? 'Paused · Interrupted' : 'Paused',
    'break' => 'Break',
    _ => 'In progress',
  };
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'mode': mode,
    'minutes': minutes,
    'created': created.toUtc().toIso8601String(),
    'seconds': seconds,
    'status': status,
    'anchor': anchor?.toUtc().toIso8601String(),
    'breakUntil': breakUntil?.toUtc().toIso8601String(),
    'notes': notes,
    'logs': logs,
    'ended': ended?.toUtc().toIso8601String(),
    'taskCompleted': taskCompleted,
    if (scheduled != null) 'scheduled': scheduled!.toJson(),
    if (accumulatedMillis != null) 'accumulatedMillis': accumulatedMillis,
  };
  factory FocusSession.fromJson(Map<String, dynamic> j) => FocusSession(
    id: j['id'],
    title: j['title'],
    mode: j['mode'],
    minutes: j['minutes'],
    created: DateTime.parse(j['created']).toLocal(),
    seconds: j['seconds'],
    status: j['status'],
    anchor: DateTime.tryParse(j['anchor'] ?? ''),
    breakUntil: DateTime.tryParse(j['breakUntil'] ?? ''),
    notes: j['notes'],
    logs: List<String>.from(j['logs']),
    ended: DateTime.tryParse(j['ended'] ?? '')?.toLocal(),
    taskCompleted: j['taskCompleted'] ?? false,
    accumulatedMillis: j['accumulatedMillis'] as int?,
    scheduled: j['scheduled'] == null
        ? null
        : ScheduledFocus.fromJson(j['scheduled'] as Map<String, dynamic>),
  );
}

class Reminder {
  Reminder({
    required this.id,
    required this.title,
    required this.when,
    this.repeat = 'Once',
    this.enabled = true,
    this.note = '',
    this.snoozedUntil,
  });
  String id, title, repeat, note;
  DateTime when;
  bool enabled;
  DateTime? snoozedUntil;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'when': when.toIso8601String(),
    'repeat': repeat,
    'enabled': enabled,
    'note': note,
    'snoozedUntil': snoozedUntil?.toIso8601String(),
  };
  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
    id: j['id'],
    title: j['title'],
    when: DateTime.parse(j['when']),
    repeat: j['repeat'],
    enabled: j['enabled'],
    note: j['note'],
    snoozedUntil: DateTime.tryParse(j['snoozedUntil'] ?? ''),
  );
  DateTime next(DateTime now) {
    var d = when;
    if (repeat == 'Once') return d;
    while (!d.isAfter(now)) {
      d = DateTime(
        d.year,
        d.month,
        d.day + (repeat == 'Daily' ? 1 : 7),
        d.hour,
        d.minute,
      );
    }
    return d;
  }
}

class FocusStore extends ChangeNotifier {
  FocusStore({
    String? accountId,
    this.proposeAgent,
    this.onPlanRecovery,
    this.taskContext,
    SharedPreferencesAsync? storage,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       now = (clock ?? DateTime.now)(),
       _providedStorage = storage,
       _key = accountId == null
           ? 'planify.oumayma.v1'
           : 'planify.oumayma.v1.$accountId';

  final String _key;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
  proposeAgent;
  final void Function(String id)? onPlanRecovery;
  bool _disposed = false;
  final notifications = NotificationService();
  final SharedPreferencesAsync? _providedStorage;
  late final _prefs = _providedStorage ?? SharedPreferencesAsync();
  List<FocusSession> sessions = [];
  List<Reminder> reminders = [];
  List<String> inbox = [];
  String? error;
  bool ready = false;
  final DateTime Function() _clock;
  final FocusTaskContext? taskContext;
  DateTime now;
  DateTime get currentTime => _clock();
  Timer? _ticker;
  Future<void> _writes = Future.value();
  FocusSession? get active => sessions.where((s) => !s.finished).firstOrNull;
  Future<void> get settled => _writes;
  int _saveGeneration = 0;
  bool saving = false;
  Map<String, ({String? taskId, int seconds})> _savedSessions = {};

  bool hasSavedFinish(String id) => _savedSessions.containsKey(id);

  int recordedSecondsFor(Set<String> taskIds) => _savedSessions.values
      .where((record) => taskIds.contains(record.taskId))
      .fold<int>(0, (total, record) => total + record.seconds);

  Map<String, ({String? taskId, int seconds})> _finishedSnapshot() => {
    for (final session in sessions)
      if (session.finished)
        session.id: (
          taskId: session.status == 'cancelled'
              ? null
              : session.scheduled?.taskId,
          seconds: session.seconds,
        ),
  };

  Future<void> completeLinkedTask(String id) async {
    final session = sessions.where((item) => item.id == id).firstOrNull;
    final slot = session?.scheduled;
    if (_disposed ||
        session == null ||
        slot == null ||
        taskContext == null ||
        !session.finished ||
        session.status == 'cancelled' ||
        !hasSavedFinish(id)) {
      throw StateError(
        'Save the finished focus session before marking its task done.',
      );
    }
    await taskContext!.tasks.markDone(slot.taskId);
  }

  Future<void> clearDeviceAlerts() async {
    try {
      await notifications.clearDeviceAlerts();
    } catch (_) {
      notifications.message = 'Device alerts could not be cleared.';
    }
  }

  Future<void> _scheduleReminder(Reminder reminder) async {
    final date = DateTime.now();
    await Future.wait([
      notifications.schedule(
        reminder.id,
        reminder.title,
        reminder.next(date),
        reminder.repeat,
        reminder.enabled,
      ),
      notifications.schedule(
        '${reminder.id}1',
        reminder.title,
        reminder.snoozedUntil ?? DateTime(2000),
        'Once',
        reminder.enabled,
      ),
    ]);
  }

  void suspend() => _ticker?.cancel();

  Future<void> load() async {
    suspend();
    error = null;
    now = _clock();
    try {
      final raw = await _prefs.getString(_key);
      if (raw != null) {
        final j = jsonDecode(raw);
        sessions = (j['sessions'] as List)
            .map((e) => FocusSession.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        reminders = (j['reminders'] as List)
            .map((e) => Reminder.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        inbox = List<String>.from(j['inbox']);
      } else {
        sessions = [];
        reminders = [];
        inbox = [];
      }
    } catch (_) {
      if (_prefs is SyncedPreferences) rethrow;
      error = 'Saved data could not be loaded. Restart before making changes.';
    }
    _savedSessions = _finishedSnapshot();
    try {
      if (!ready) await notifications.init();
    } catch (_) {
      notifications.message = 'Device notifications could not be initialized.';
    }
    if (_disposed) return;
    if (_prefs is SyncedPreferences && notifications.initialized) {
      await clearDeviceAlerts();
      if (_disposed) return;
      final alert = active?.breakUntil;
      await Future.wait([
        for (final reminder in reminders) _scheduleReminder(reminder),
        if (alert != null) notifications.timer(alert, 'Your break is complete'),
      ]);
    }
    if (_disposed) return;
    ready = true;
    _scheduleTimer();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      now = _clock();
      final s = active;
      if (s != null &&
          s.status == 'running' &&
          s.mode != 'Stopwatch' &&
          s.elapsed(now) >= s.minutes * 60) {
        final marker = 'Time target reached: ${s.minutes} min';
        if (!s.logs.contains(marker)) {
          s.logs = [...s.logs, marker];
          inbox.insert(
            0,
            '${s.title}: time target reached. Finish, take a break, or request more time.',
          );
          save();
        }
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void save() {
    final raw = jsonEncode({
      'sessions': sessions.map((s) => s.toJson()).toList(),
      'reminders': reminders.map((r) => r.toJson()).toList(),
      'inbox': inbox,
    });
    final recorded = _finishedSnapshot();
    final generation = ++_saveGeneration;
    saving = true;
    _writes = _writes.then((_) async {
      try {
        await _prefs.setString(_key, raw);
        _savedSessions = recorded;
        if (generation == _saveGeneration) error = null;
      } catch (_) {
        if (generation == _saveGeneration) {
          error = 'Changes could not be saved. Check device storage.';
        }
      } finally {
        if (generation == _saveGeneration) saving = false;
        if (!_disposed) notifyListeners();
      }
    });
    if (!_disposed) notifyListeners();
  }

  void start(String title, int minutes, String mode) {
    if (active != null || _disposed) return;
    _start(title, minutes, mode);
  }

  FocusSession startScheduled(ScheduledFocus slot, int minutes, String mode) {
    if (active != null) {
      throw StateError('Continue or finish the active session first.');
    }
    if (_disposed || taskContext == null) {
      throw StateError('The focus workspace is unavailable.');
    }
    final task = taskContext!.eligibleTask(slot);
    return _start(task.title, minutes, mode, scheduled: slot);
  }

  FocusSession _start(
    String title,
    int minutes,
    String mode, {
    ScheduledFocus? scheduled,
  }) {
    now = _clock();
    sessions.insert(
      0,
      FocusSession(
        id: newId(),
        title: title.trim(),
        mode: mode,
        minutes: minutes,
        created: now,
        anchor: now,
        scheduled: scheduled,
      ),
    );
    save();
    _scheduleTimer();
    return sessions.first;
  }

  void _capture(FocusSession s, [DateTime? instant]) {
    now = instant ?? _clock();
    s.accumulatedMillis = s.elapsedMillis(now);
    s.seconds = s.accumulatedMillis! ~/ 1000;
    s.anchor = null;
  }

  void pause() {
    final s = active;
    if (s == null || s.status != 'running') return;
    _capture(s);
    s.status = 'paused';
    save();
    unawaited(notifications.cancelTimer());
  }

  void resume() {
    final s = active;
    if (s == null || (s.status != 'paused' && s.status != 'break')) return;
    if (s.status == 'break' && s.mode == 'Pomodoro') {
      s.minutes = (s.seconds / 60).ceil() + 25;
    }
    s.breakUntil = null;
    s.status = 'running';
    s.anchor = now = _clock();
    save();
    _scheduleTimer();
  }

  void takeBreak() {
    final s = active;
    if (s == null || s.status != 'running') return;
    _capture(s);
    s.status = 'break';
    s.breakUntil = now.add(const Duration(minutes: 5));
    save();
    unawaited(notifications.timer(s.breakUntil!, 'Your break is complete'));
  }

  void addTime(int minutes) {
    final s = active;
    if (s == null) return;
    s.minutes += minutes;
    s.logs = [...s.logs, 'Added $minutes minutes'];
    inbox.insert(
      0,
      'More time requested for ${s.title}. Review your remaining day when Calendar is connected.',
    );
    save();
    _scheduleTimer();
  }

  void log(String kind, String text) {
    final s = active;
    if (s == null) return;
    pause();
    s.logs = [...s.logs, '$kind: $text'];
    if (kind == 'Blocked') inbox.insert(0, 'Blocked: ${s.title} — $text');
    save();
  }

  FocusSession? finish({bool cancelled = false}) {
    final s = active;
    if (s == null) return null;
    final ended = _clock();
    _capture(s, ended);
    s.status = cancelled
        ? 'cancelled'
        : s.mode != 'Stopwatch' && s.seconds < s.minutes * 60
        ? 'endedEarly'
        : 'completed';
    s.ended = ended;
    s.breakUntil = null;
    save();
    unawaited(notifications.cancelTimer());
    return s;
  }

  void _scheduleTimer() {
    final s = active;
    if (s == null || s.status != 'running' || s.mode == 'Stopwatch') return;
    final instant = _clock();
    final left = s.minutes * 60 - s.elapsed(instant);
    if (left > 0) {
      unawaited(
        notifications.timer(
          instant.add(Duration(seconds: left)),
          'Your focus time is complete',
        ),
      );
    }
  }

  Future<void> putReminder(Reminder r) async {
    final i = reminders.indexWhere((x) => x.id == r.id);
    if (i < 0) {
      reminders.add(r);
    } else {
      reminders[i] = r;
    }
    save();
    await _scheduleReminder(r);
    if (!_disposed) notifyListeners();
  }

  Future<void> deleteReminder(Reminder r) async {
    reminders.removeWhere((x) => x.id == r.id);
    save();
    await Future.wait([
      notifications.cancel(r.id),
      notifications.cancel('${r.id}1'),
    ]);
  }

  Future<void> snooze(Reminder r) async {
    r.snoozedUntil = DateTime.now().add(const Duration(minutes: 10));
    if (r.repeat == 'Once') {
      r.when = r.snoozedUntil!;
      r.snoozedUntil = null;
    }
    r.enabled = true;
    await putReminder(r);
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }
}
