import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/services/app_session.dart';

class GoogleCalendarPage extends StatefulWidget {
  const GoogleCalendarPage({super.key, required this.session});
  final AppSession session;
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
    if (connected) {
      events =
          (await widget.session.request(
                'GET',
                '/users/me/google/calendar/events',
              ))['events']
              as List;
    }
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
        const Text(
          'Connect your primary Google calendar to view upcoming events and create events. Google events shown here are live online data; they do not automatically change your approved Planify schedule.',
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
          const Text('Upcoming Google events (up to 100)'),
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
