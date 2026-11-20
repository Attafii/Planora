import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/notification_service.dart';

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
  });
  String id, title, mode, status, notes;
  int minutes, seconds;
  DateTime created;
  DateTime? anchor, breakUntil, ended;
  List<String> logs;
  bool taskCompleted;
  int elapsed(DateTime now) =>
      seconds +
      (anchor == null
          ? 0
          : now.difference(anchor!).inSeconds.clamp(0, 1 << 31));
  bool get finished => status == 'completed' || status == 'cancelled';
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
  FocusStore({String? accountId, this.proposeAgent})
    : _key = accountId == null
          ? 'planify.oumayma.v1'
          : 'planify.oumayma.v1.$accountId';

  final String _key;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
  proposeAgent;
  bool _disposed = false;
  final notifications = NotificationService();
  late final _prefs = SharedPreferencesAsync();
  List<FocusSession> sessions = [];
  List<Reminder> reminders = [];
  List<String> inbox = [];
  String? error;
  bool ready = false;
  DateTime now = DateTime.now();
  Timer? _ticker;
  Future<void> _writes = Future.value();
  FocusSession? get active => sessions.where((s) => !s.finished).firstOrNull;
  Future<void> load() async {
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
      }
    } catch (_) {
      error = 'Saved data could not be loaded. Restart before making changes.';
    }
    try {
      await notifications.init();
    } catch (_) {
      notifications.message = 'Device notifications could not be initialized.';
    }
    if (_disposed) return;
    ready = true;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      now = DateTime.now();
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
    _writes = _writes.then((_) => _prefs.setString(_key, raw)).catchError((
      Object e,
    ) {
      error = 'Changes could not be saved. Check device storage.';
      notifyListeners();
    });
    notifyListeners();
  }

  void start(String title, int minutes, String mode) {
    if (active != null) return;
    sessions.insert(
      0,
      FocusSession(
        id: newId(),
        title: title.trim(),
        mode: mode,
        minutes: minutes,
        created: DateTime.now(),
        anchor: DateTime.now(),
      ),
    );
    save();
    _scheduleTimer();
  }

  void _capture(FocusSession s) {
    s.seconds = s.elapsed(DateTime.now());
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
    if (s == null) return;
    if (s.status == 'break' && s.mode == 'Pomodoro') {
      s.minutes = (s.seconds / 60).ceil() + 25;
    }
    s.breakUntil = null;
    s.status = 'running';
    s.anchor = DateTime.now();
    save();
    _scheduleTimer();
  }

  void takeBreak() {
    final s = active;
    if (s == null) return;
    _capture(s);
    s.status = 'break';
    s.breakUntil = DateTime.now().add(const Duration(minutes: 5));
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
    _capture(s);
    s.status = cancelled ? 'cancelled' : 'completed';
    s.ended = DateTime.now();
    save();
    unawaited(notifications.cancelTimer());
    return s;
  }

  void _scheduleTimer() {
    final s = active;
    if (s == null || s.status != 'running' || s.mode == 'Stopwatch') return;
    final left = s.minutes * 60 - s.elapsed(DateTime.now());
    if (left > 0) {
      unawaited(
        notifications.timer(
          DateTime.now().add(Duration(seconds: left)),
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
    await notifications.schedule(
      r.id,
      r.title,
      r.next(DateTime.now()),
      r.repeat,
      r.enabled,
    );
    await notifications.schedule(
      '${r.id}1',
      r.title,
      r.snoozedUntil ?? DateTime(2000),
      'Once',
      r.enabled,
    );
    notifyListeners();
  }

  Future<void> deleteReminder(Reminder r) async {
    reminders.removeWhere((x) => x.id == r.id);
    save();
    await notifications.cancel(r.id);
    await notifications.cancel('${r.id}1');
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
