import 'package:timezone/timezone.dart' as tz;

import '../tasks/task_store.dart' show dayKey;
import 'planning_engine.dart';

/// Calendar records use a civil date and wall-clock minutes. A skipped or
/// repeated minute cannot identify a unique instant in that representation.
class CalendarClock {
  CalendarClock(this.zone);

  final String? Function() zone;
  final Map<(String, String?), List<Minutes>> _cache = {};

  tz.Location? _location(String? name) => switch (name) {
    'UTC' || 'Etc/UTC' || 'GMT' || 'Etc/GMT' => tz.UTC,
    final String value => tz.timeZoneDatabase.locations[value],
    null => null,
  };

  void validateZone() {
    final name = zone();
    if (name != null && _location(name) == null) {
      throw StateError(
        'Choose a supported timezone in Preferences before planning.',
      );
    }
  }

  DateTime local(DateTime instant) {
    final location = _location(zone());
    return location == null
        ? instant.toLocal()
        : tz.TZDateTime.from(instant, location);
  }

  List<Minutes> unavailable(String date) {
    final key = (date, zone());
    if (_cache.length >= 16 && !_cache.containsKey(key)) {
      _cache.remove(_cache.keys.first);
    }
    return _cache.putIfAbsent(key, () {
      final anchor = DateTime.parse('${date}T00:00:00Z');
      final location = _location(key.$2);
      final counts = List<int>.filled(1440, 0);
      for (var offset = -1440; offset < 2880; offset++) {
        final instant = anchor.add(Duration(minutes: offset));
        final value = location == null
            ? instant.toLocal()
            : tz.TZDateTime.from(instant, location);
        if (value.year == anchor.year &&
            value.month == anchor.month &&
            value.day == anchor.day) {
          counts[value.hour * 60 + value.minute]++;
        }
      }
      final blocked = <Minutes>[];
      for (var minute = 0; minute < counts.length;) {
        if (counts[minute] == 1) {
          minute++;
          continue;
        }
        final start = minute++;
        while (minute < counts.length && counts[minute] != 1) {
          minute++;
        }
        blocked.add((start: start, end: minute));
      }
      return List.unmodifiable(blocked);
    });
  }

  static void validateDate(String date) {
    final parsed = DateTime.tryParse('${date}T00:00:00Z');
    if (parsed == null || dayKey(parsed) != date) {
      throw StateError('Choose a valid calendar date.');
    }
  }
}
