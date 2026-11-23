import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:timezone/timezone.dart' as tz;

import '../tasks/task_store.dart' show dayKey;
import 'planning_store.dart';
import 'planning_engine.dart';

List<PlanBlock> googleBusyBlocks(
  PlanningStore store,
  String date,
  List<dynamic> events,
) {
  final existing = store
      .day(date)
      .reserved
      .where(
        (b) => !b.id.startsWith('google:') || b.start < store.cutoffFor(date),
      )
      .toList();
  final minutes = List<bool>.filled(1440, false);
  final location = tz.getLocation(store.clock.zone() ?? 'UTC');
  final civil = DateTime.parse(date);
  for (final dynamic event in events) {
    if (event['extendedProperties']?['private']?['planify'] == 'true' ||
        event['status'] == 'cancelled' ||
        event['transparency'] == 'transparent' ||
        (event['attendees'] as List? ?? []).any(
          (dynamic a) => a['self'] == true && a['responseStatus'] == 'declined',
        )) {
      continue;
    }
    final start = event['start'] as Map?, end = event['end'] as Map?;
    if (start == null || end == null) {
      throw StateError(
        'Google returned an event without valid times. Refresh before importing.',
      );
    }
    final allDay = start['date'] != null;
    final from = allDay
        ? tz.TZDateTime.parse(location, '${start['date']}T00:00:00')
        : DateTime.parse(start['dateTime'] as String);
    final until = allDay
        ? tz.TZDateTime.parse(location, '${end['date']}T00:00:00')
        : DateTime.parse(end['dateTime'] as String);
    for (var m = store.cutoffFor(date); m < 1440; m++) {
      final instant = tz.TZDateTime(
        location,
        civil.year,
        civil.month,
        civil.day,
        m ~/ 60,
        m % 60,
      );
      if (instant.isBefore(until) &&
          instant.add(const Duration(minutes: 1)).isAfter(from)) {
        minutes[m] = true;
      }
    }
  }
  // Preserve existing commitments and breaks; import only uncovered busy minutes.
  for (final block in existing) {
    for (var m = block.start; m < block.end; m++) {
      minutes[m] = false;
    }
  }
  final result = <PlanBlock>[];
  for (var m = 0; m < 1440;) {
    if (!minutes[m]) {
      m++;
      continue;
    }
    final start = m++;
    while (m < 1440 && minutes[m]) {
      m++;
    }
    result.add(
      PlanBlock(
        'google:$date:$start',
        'Google Calendar busy',
        start,
        m,
        BlockKind.commitment,
      ),
    );
  }
  return [...existing, ...result];
}

List<Map<String, dynamic>> approvedGoogleExports(
  PlanningStore store,
  String date,
  String account,
) {
  final zone = store.clock.zone() ?? 'UTC';
  final location = tz.getLocation(zone), day = DateTime.parse(date);
  return [
    for (final b in store.visibleApproved(date))
      if (b.kind == BlockKind.task && b.start >= store.cutoffFor(date))
        (() {
          if (store.clock
              .unavailable(date)
              .any((i) => b.start < i.end && b.end > i.start)) {
            throw StateError('Cannot export ambiguous daylight-saving times.');
          }
          final start = tz.TZDateTime(
            location,
            day.year,
            day.month,
            day.day,
            b.start ~/ 60,
            b.start % 60,
          );
          final end = tz.TZDateTime(
            location,
            day.year,
            day.month,
            day.day,
            b.end ~/ 60,
            b.end % 60,
          );
          if (dayKey(start) != date || end.isBefore(start)) {
            throw StateError('Invalid calendar boundary.');
          }
          return <String, dynamic>{
            'request_id': sha256
                .convert(utf8.encode('$account|$date|${b.id}'))
                .toString()
                .substring(0, 32),
            'title': b.title,
            'planify_export': true,
            'start': start.toUtc().toIso8601String(),
            'end': end.toUtc().toIso8601String(),
          };
        })(),
  ];
}
