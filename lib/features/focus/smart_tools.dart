import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../app/theme/app_colors.dart';
import '../../core/services/app_session.dart';
import 'focus_store.dart';
import 'pages.dart';

int adaptiveMinutes(List<FocusSession> sessions) {
  final recent = sessions
      .where((s) => s.status == 'completed' && s.seconds >= 60)
      .take(10)
      .toList();
  if (recent.isEmpty) return 25;
  final average =
      recent.fold<int>(0, (sum, s) => sum + s.seconds) ~/ recent.length ~/ 60;
  final interruptions = recent
      .where(
        (s) => s.logs.any(
          (l) => l.startsWith('Interruption') || l.startsWith('Blocked'),
        ),
      )
      .length;
  return ((average * (interruptions * 2 >= recent.length ? 0.8 : 1)) / 5)
          .round()
          .clamp(2, 12) *
      5;
}

DateTime safeReminderSlot(
  DateTime requested,
  List<Reminder> reminders, {
  String? excluding,
  int quietStart = 22,
  int quietEnd = 8,
}) {
  var slot = requested;
  for (var tries = 0; tries < 300; tries++) {
    if (slot.hour >= quietStart) {
      slot = DateTime(slot.year, slot.month, slot.day + 1, quietEnd);
      continue;
    }
    if (slot.hour < quietEnd) {
      slot = DateTime(slot.year, slot.month, slot.day, quietEnd);
      continue;
    }
    if (reminders.any(
      (r) =>
          r.enabled &&
          r.id != excluding &&
          r
                  .next(slot.subtract(const Duration(minutes: 10)))
                  .difference(slot)
                  .inMinutes
                  .abs() <
              10,
    )) {
      slot = slot.add(const Duration(minutes: 10));
      continue;
    }
    return slot;
  }
  throw StateError('No available reminder slot in the search window.');
}

Future<void> openContextAssist(
  BuildContext c,
  FocusStore store,
  String tool, {
  Reminder? reminder,
}) => showModalBottomSheet<void>(
  context: c,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: paper,
  builder: (sheet) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
    child: SizedBox(
      height:
          MediaQuery.sizeOf(c).height *
          (tool == 'AI reminder agent'
              ? 0.64
              : tool == 'Reminder guard'
              ? 0.7
              : 0.82),
      child: ContextAssistSheet(
        store: store,
        initialTool: tool,
        reminder: reminder,
      ),
    ),
  ),
);

class ContextAssistSheet extends StatefulWidget {
  const ContextAssistSheet({
    super.key,
    required this.store,
    this.client,
    this.initialTool = 'Adaptive focus',
    this.reminder,
  });
  final FocusStore store;
  final http.Client? client;
  final String initialTool;
  final Reminder? reminder;
  @override
  State<ContextAssistSheet> createState() => _SmartToolsState();
}

class _SmartToolsState extends State<ContextAssistSheet> {
  final input = TextEditingController();
  late String tool;
  late final http.Client _client;
  @override
  void initState() {
    super.initState();
    tool = widget.initialTool;
    selected = widget.reminder;
    _client = widget.client ?? http.Client();
    if (tool == 'Reminder guard' && selected != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) generate();
      });
    }
  }

  bool busy = false, applied = false;
  String? error;
  Map<String, dynamic>? proposal;
  Reminder? selected;
  String? expected;
  final tools = [
    'Adaptive focus',
    'Reminder guard',
    'AI focus coach',
    'AI reminder agent',
  ];
  @override
  void dispose() {
    input.dispose();
    if (widget.client == null) _client.close();
    super.dispose();
  }

  Future<void> generate() async {
    setState(() {
      busy = true;
      error = null;
      proposal = null;
      applied = false;
    });
    try {
      final s = widget.store;
      if (tool == 'Adaptive focus') {
        if (input.text.trim().isEmpty) {
          throw StateError('Name the activity you want to focus on.');
        }
        final minutes = adaptiveMinutes(s.sessions);
        proposal = {
          'kind': 'focus',
          'title': input.text.trim(),
          'minutes': minutes,
          'steps': <String>[],
          'reason':
              s.sessions
                  .where((x) => x.status == 'completed' && x.seconds >= 60)
                  .isEmpty
              ? 'A 25-minute starting point. Complete sessions to personalize the recommendation.'
              : 'Based on your last ten completed sessions, shortened when interruptions are frequent.',
        };
      } else if (tool == 'Reminder guard') {
        if (selected == null) throw StateError('Select a reminder to inspect.');
        expected = jsonEncode(selected!.toJson());
        final requested = selected!.next(DateTime.now());
        final slot = safeReminderSlot(
          requested.isBefore(DateTime.now())
              ? DateTime.now().add(const Duration(minutes: 1))
              : requested,
          s.reminders,
          excluding: selected!.id,
        );
        proposal = {
          'kind': 'move',
          'title': selected!.title,
          'when': slot.toIso8601String(),
          'reason':
              'Avoids quiet hours (22:00–08:00) and keeps a ten-minute gap from other reminders. ${selected!.repeat} recurrence is preserved.',
        };
      } else {
        if (input.text.trim().isEmpty) {
          throw StateError('Describe what you would like help with.');
        }
        const url = String.fromEnvironment(
          'AI_API_URL',
          defaultValue: 'http://localhost:5140',
        );
        final payload = <String, dynamic>{
          'kind': tool == 'AI focus coach' ? 'focus' : 'reminder',
          'input': input.text.trim(),
          'now': DateTime.now().toIso8601String(),
          'offsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
          'context': {
            'completed': s.sessions
                .where((x) => x.finished)
                .take(10)
                .map(
                  (x) => {'seconds': x.seconds, 'interruptions': x.logs.length},
                )
                .toList(),
            'reminders': s.reminders
                .where((r) => r.enabled)
                .take(30)
                .map(
                  (r) => {
                    'when': r.next(DateTime.now()).toIso8601String(),
                    'repeat': r.repeat,
                  },
                )
                .toList(),
          },
        };
        if (s.proposeAgent case final propose?) {
          proposal = await propose(payload);
        } else {
          final response = await _client
              .post(
                Uri.parse('$url/propose'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(payload),
              )
              .timeout(const Duration(seconds: 65));
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          if (response.statusCode != 200) {
            throw StateError(body['error'] ?? 'AI service unavailable.');
          }
          proposal = body;
        }
      }
    } catch (e) {
      error = e is ApiFailure
          ? e.message
          : e is StateError
          ? e.message.toString()
          : 'Could not reach the AI service. Check its configuration and retry.';
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> approve() async {
    final p = proposal;
    if (p == null || applied) return;
    setState(() => applied = true);
    try {
      final s = widget.store;
      if (p['kind'] == 'focus') {
        if (s.active != null) {
          throw StateError(
            'Finish the active session before starting this plan.',
          );
        }
        final minutes = p['minutes'];
        if (minutes is! int || minutes < 5 || minutes > 120) {
          throw StateError('Invalid focus duration.');
        }
        s.start(p['title'], minutes, 'Countdown');
        s.active!.notes = (p['steps'] as List).map((x) => '• $x').join('\n');
      } else if (p['kind'] == 'move') {
        if (selected == null ||
            !s.reminders.contains(selected) ||
            jsonEncode(selected!.toJson()) != expected) {
          throw StateError('This reminder changed. Generate a fresh proposal.');
        }
        final r = selected!;
        final proposed = DateTime.parse(p['when']);
        if (!proposed.isAfter(DateTime.now()) ||
            safeReminderSlot(proposed, s.reminders, excluding: r.id) !=
                proposed) {
          throw StateError(
            'Reminder availability changed. Generate a fresh proposal.',
          );
        }
        r.when = proposed;
        await s.putReminder(r);
      } else if (p['kind'] == 'reminder') {
        final date = DateTime.parse(p['when']);
        if (!date.isAfter(DateTime.now())) {
          throw StateError('The proposed time has passed. Generate again.');
        }
        await s.putReminder(
          Reminder(
            id: newId(),
            title: p['title'],
            when: date.toLocal(),
            repeat: p['repeat'] ?? 'Once',
          ),
        );
      } else {
        throw StateError('Unsupported proposal.');
      }
      s.inbox.insert(0, 'Approved $tool: ${p['title']}');
      s.save();
      if (mounted) setState(() => applied = true);
    } catch (e) {
      applied = false;
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message.toString()
              : 'Could not apply this proposal.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext c) => Material(
    color: paper,
    child: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tool.contains('focus')
                    ? const Color(0xFFF0EAFF)
                    : const Color(0xFFEAF2FF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                tool == 'Reminder guard'
                    ? Icons.shield_outlined
                    : tool.contains('focus')
                    ? Icons.spa_outlined
                    : Icons.chat_bubble_outline_rounded,
                color: ink,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(c),
              tooltip: 'Close',
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          tool == 'AI focus coach'
              ? 'A smaller first step.'
              : tool == 'AI reminder agent'
              ? 'Say it. Let it go.'
              : tool == 'Reminder guard'
              ? 'Give it some space.'
              : 'Your natural rhythm.',
          style: Theme.of(c).textTheme.headlineMedium,
        ),
        const SizedBox(height: 18),
        if (tool != 'AI reminder agent')
          Text(
            tool == 'Adaptive focus'
                ? 'An evidence-based work block, adapted to your actual time and interruptions.'
                : tool == 'Reminder guard'
                ? 'Review a reminder against quiet hours and nearby alerts before moving it.'
                : tool == 'AI focus coach'
                ? 'The coach can read recent focus statistics and propose a manageable block with concrete steps.'
                : 'Describe a reminder naturally. The agent can inspect reminder load before proposing a time.',
            style: const TextStyle(height: 1.6, color: Color(0xFF526078)),
          ),
        const SizedBox(height: 20),
        if (tool == 'Reminder guard' && widget.reminder != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_none),
            title: Text(widget.reminder!.title),
            subtitle: Text(
              'Currently ${timeLabel(widget.reminder!.next(DateTime.now()))} · ${widget.reminder!.repeat}',
            ),
          )
        else if (tool == 'Reminder guard')
          DropdownButtonFormField<Reminder>(
            initialValue: selected,
            items: widget.store.reminders
                .map(
                  (r) => DropdownMenuItem(
                    value: r,
                    child: Text(r.title, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: busy
                ? null
                : (v) => setState(() {
                    selected = v;
                    proposal = null;
                    applied = false;
                  }),
            decoration: const InputDecoration(labelText: 'Reminder'),
          )
        else
          TextField(
            controller: input,
            minLines: tool == 'AI reminder agent' ? 3 : 2,
            maxLines: 5,
            maxLength: 1000,
            decoration: InputDecoration(
              filled: tool == 'AI reminder agent',
              fillColor: const Color(0xFFEAF2FF),
              border: tool == 'AI reminder agent'
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    )
                  : null,
              enabledBorder: tool == 'AI reminder agent'
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    )
                  : null,
              labelText: tool == 'Adaptive focus'
                  ? 'Activity'
                  : tool == 'AI focus coach'
                  ? 'What feels hard to start?'
                  : 'Remind me to…',
              hintText: tool == 'AI reminder agent'
                  ? 'Remind me to stretch tomorrow at 3 pm'
                  : null,
            ),
          ),
        if (tool.startsWith('AI'))
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Generating shares your request and recent time/reminder statistics with the configured AI provider. Nothing changes until you approve.',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: Color(0xFF526078),
              ),
            ),
          ),
        if (tool != 'Reminder guard' || proposal == null)
          FilledButton.icon(
            onPressed: busy ? null : generate,
            icon: Icon(
              tool == 'AI reminder agent'
                  ? Icons.send_rounded
                  : tool.startsWith('AI')
                  ? Icons.auto_awesome
                  : Icons.tune,
            ),
            label: Text(busy ? 'Preparing a proposal…' : 'Review a suggestion'),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
        if (proposal != null) ...[
          const SizedBox(height: 26),
          sectionTitle(c, applied ? 'Applied' : 'Your proposal'),
          const SizedBox(height: 12),
          Text(proposal!['title'], style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: proposal!['kind'] == 'focus'
                  ? const Color(0xFFE3F8F3)
                  : const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  proposal!['kind'] == 'focus'
                      ? Icons.timelapse
                      : Icons.schedule,
                  color: ink,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    proposal!['kind'] == 'focus'
                        ? '${proposal!['minutes']} min\nOne focused block'
                        : '${timeLabel(DateTime.parse(proposal!['when']).toLocal())}\n${dayLabel(DateTime.parse(proposal!['when']).toLocal())}',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 21,
                      height: 1.4,
                      color: ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(proposal!['reason'] ?? '', style: const TextStyle(height: 1.6)),
          ...((proposal!['steps'] ?? []) as List).map(
            (step) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_outline, color: teal),
              title: Text(step),
            ),
          ),
          const SizedBox(height: 20),
          if (!applied)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => proposal = null),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: approve,
                    child: const Text('Approve'),
                  ),
                ),
              ],
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Return to my day'),
            ),
        ],
      ],
    ),
  );
}
