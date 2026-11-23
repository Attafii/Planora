import 'google_plan_sync.dart';
import 'planning_store.dart';

import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/services/app_session.dart';

class GoogleCalendarPage extends StatefulWidget {
  const GoogleCalendarPage({
    super.key,
    required this.session,
    required this.store,
    required this.date,
    required this.review,
  });
  final AppSession session;
  final PlanningStore store;
  final String date;
  final Future<bool> Function(PlanDraft) review;
  @override
  State<GoogleCalendarPage> createState() => _GoogleCalendarPageState();
}

class _GoogleCalendarPageState extends State<GoogleCalendarPage> {
  bool busy = false, connected = false;
  String? error;
  List<dynamic> events = [];
  final title = TextEditingController();
  final start = TextEditingController();
  final end = TextEditingController();
  String? requestId;
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() async {
    final status = await widget.session.request(
      'GET',
      '/users/me/google/calendar',
    );
    connected = status['connected'] == true;
    if (!connected) {
      events = [];
    }
    if (connected) {
      events =
          (await widget.session.request(
                'GET',
                '/users/me/google/calendar/events',
              ))['events']
              as List;
    }
  }

  Future<void> importBusy() async {
    final today = DateTime.parse(
      widget.store.localNow.toIso8601String().substring(0, 10),
    );
    final selected = DateTime.parse(widget.date);
    if (selected.isBefore(today) || selected.difference(today).inDays > 29) {
      throw StateError(
        'Select a date within the next 30 days before importing Google busy times.',
      );
    }
    await load();
    if (!connected) {
      throw StateError('Connect Google Calendar before importing.');
    }
    final draft = widget.store.preview(
      widget.date,
      reservedOverride: googleBusyBlocks(widget.store, widget.date, events),
      reason: 'Import Google busy times for ${widget.date}',
    );
    if (!mounted) return;
    await widget.review(draft);
  }

  Future<void> exportPlan() async {
    final today = DateTime.parse(
      widget.store.localNow.toIso8601String().substring(0, 10),
    );
    final selected = DateTime.parse(widget.date);
    if (selected.isBefore(today) || selected.difference(today).inDays > 29) {
      throw StateError(
        'Select a date within the next 30 days before exporting.',
      );
    }
    await load();
    if (!connected) {
      throw StateError('Connect Google Calendar before exporting.');
    }
    if (!mounted) return;
    final version = widget.store.day(widget.date).version;
    final items = approvedGoogleExports(
      widget.store,
      widget.date,
      widget.session.account!.id,
    );
    if (items.isEmpty) {
      throw StateError(
        'No future approved task blocks to export on this date.',
      );
    }
    final fingerprint = items.toString();
    final previous = <String>[];
    for (final item in items) {
      final old = events
          .where((dynamic e) => e['id'] == item['request_id'])
          .firstOrNull;
      if (old != null) {
        item['expected_etag'] = old['etag'];
        previous.add(
          "Existing Google event: ${old['summary']} ${old['start']} to ${old['end']}",
        );
      }
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Export ${items.length} approved blocks?'),
        content: SingleChildScrollView(
          child: Text(
            items
                    .map(
                      (e) => "${e['title']}\n${e['start']} – ${e['end']} (UTC)",
                    )
                    .join('\n\n') +
                (previous.isEmpty
                    ? ''
                    : '\n\nUpdates may replace these previously exported events:\n${previous.join('\n')}'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirm export to Google'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    var saved = 0;
    try {
      for (final item in items) {
        if (widget.store.day(widget.date).version != version ||
            approvedGoogleExports(
                  widget.store,
                  widget.date,
                  widget.session.account!.id,
                ).toString() !=
                fingerprint) {
          throw StateError('Plan changed. Review a fresh export preview.');
        }
        await widget.session.request(
          'POST',
          '/users/me/google/calendar/events',
          item,
        );
        saved++;
      }
    } catch (e) {
      throw StateError(
        '$saved of ${items.length} blocks confirmed. Retry safely after reviewing: $e',
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$saved blocks confirmed in Google Calendar.')),
      );
    }
    await load();
  }

  @override
  void initState() {
    super.initState();
    run(load);
  }

  @override
  void dispose() {
    title.dispose();
    start.dispose();
    end.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Google Calendar')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Connect your primary Google calendar. Import busy times through a schedule proposal, or preview and confirm export of approved tasks. Selected date: ${widget.date}. Imported constraints remain available offline; refresh and Google writes require connectivity.',
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        Wrap(
          spacing: 8,
          children: [
            if (!connected)
              FilledButton(
                onPressed: busy
                    ? null
                    : () => run(() async {
                        await widget.session.googleSignIn(calendar: true);
                        await load();
                      }),
                child: const Text('Connect Google Calendar'),
              ),
            OutlinedButton(
              onPressed: busy ? null : () => run(load),
              child: const Text('Refresh / retry'),
            ),
            if (connected)
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () async {
                        final yes = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Disconnect Google Calendar?'),
                            content: const Text(
                              'Google events remain in Google. Planify sign-in is preserved.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Disconnect'),
                              ),
                            ],
                          ),
                        );
                        if (yes == true) {
                          await run(() async {
                            await widget.session.request(
                              'DELETE',
                              '/users/me/google/calendar',
                            );
                            connected = false;
                            events = [];
                          });
                        }
                      },
                child: const Text('Disconnect'),
              ),
          ],
        ),
        if (connected) ...[
          OutlinedButton(
            onPressed: busy ? null : () => run(importBusy),
            child: const Text('Preview busy-time import'),
          ),
          OutlinedButton(
            onPressed: busy ? null : () => run(exportPlan),
            child: const Text('Preview approved-plan export'),
          ),
          const SizedBox(height: 20),
          const Text('Create an event in Google Calendar'),
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'Event title'),
            onChanged: (_) => requestId = null,
          ),
          TextField(
            controller: start,
            decoration: const InputDecoration(
              labelText: 'Start with timezone offset',
              hintText: '2026-11-25T09:00:00+01:00',
            ),
            onChanged: (_) => requestId = null,
          ),
          TextField(
            controller: end,
            decoration: const InputDecoration(
              labelText: 'End with timezone offset',
              hintText: '2026-11-25T10:00:00+01:00',
            ),
            onChanged: (_) => requestId = null,
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () => run(() async {
                    if (!RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(start.text) ||
                        !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(end.text)) {
                      throw const ApiFailure(
                        'Include a timezone offset or Z in each time.',
                      );
                    }
                    requestId ??= List.generate(
                      16,
                      (_) => Random.secure()
                          .nextInt(256)
                          .toRadixString(16)
                          .padLeft(2, '0'),
                    ).join();
                    await widget.session.request(
                      'POST',
                      '/users/me/google/calendar/events',
                      {
                        'request_id': requestId,
                        'title': title.text,
                        'start': start.text,
                        'end': end.text,
                      },
                    );
                    title.clear();
                    start.clear();
                    end.clear();
                    requestId = null;
                    await load();
                  }),
            child: const Text('Create Google event'),
          ),
          const SizedBox(height: 20),
          const Text('Upcoming Google events (next 31 days)'),
          if (events.isEmpty && !busy)
            const Text('No upcoming events returned.'),
          for (final event in events)
            ListTile(
              title: Text(event['summary'] as String? ?? 'Untitled event'),
              subtitle: Text(
                '${event['start']?['dateTime'] ?? event['start']?['date'] ?? ''} – ${event['end']?['dateTime'] ?? event['end']?['date'] ?? ''}',
              ),
            ),
        ],
      ],
    ),
  );
}
