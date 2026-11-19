import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tasks/task_store.dart';
import 'planning_agent.dart';
import 'planning_engine.dart';
import 'planning_store.dart';

class PlanningPage extends StatefulWidget {
  const PlanningPage({super.key, required this.store});
  final PlanningStore store;

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  final agent = PlanningAgent();
  String date = dayKey(DateTime.now());
  bool busy = false;
  PlanningStore get store => widget.store;

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message
                  : 'Could not complete the request. Try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> chooseDate() async {
    final now = DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(date),
      firstDate: DateTime(now.year, now.month - 12, now.day),
      lastDate: DateTime(now.year, now.month, now.day + 60),
    );
    if (value != null && mounted) setState(() => date = dayKey(value));
  }

  Future<void> review(PlanDraft draft) async {
    if (!mounted) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (_) => _ProposalDialog(draft: draft, store: store, agent: agent),
    );
    if (approved == true) {
      await store.approve(draft);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Revision ${store.day(draft.day).version} saved.'),
          ),
        );
      }
    }
  }

  Future<void> editHours() async {
    final current = store.day(date);
    final result = await editInterval('Working hours', current.workday);
    if (result != null) {
      await review(store.preview(date, workday: result.interval));
    }
  }

  Future<void> editReserved([PlanBlock? block]) async {
    final result = await editInterval(
      'Reserve time',
      block?.interval ?? (start: 900, end: 930),
      label: block?.title ?? '',
      kind: block?.kind ?? BlockKind.commitment,
    );
    if (result == null) return;
    final now = store.cutoffFor(date);
    if (result.interval.start < now) {
      throw StateError('Reserve a time from now onward.');
    }
    final id = block?.id ?? 'event-${DateTime.now().microsecondsSinceEpoch}';
    await review(
      store.preview(
        date,
        reservedOverride: [
          ...store.day(date).reserved.where((item) => item.id != id),
          PlanBlock(
            id,
            result.label,
            result.interval.start,
            result.interval.end,
            result.kind,
          ),
        ],
      ),
    );
  }

  Future<void> removeReserved(PlanBlock block) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove reserved time?'),
        content: Text(block.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Preview'),
          ),
        ],
      ),
    );
    if (remove == true) {
      await review(
        store.preview(
          date,
          reservedOverride: [
            ...store.day(date).reserved.where((item) => item.id != block.id),
          ],
        ),
      );
    }
  }

  Future<void> interrupt() async {
    final start = math.min(
      1439,
      math.max(store.cutoffFor(date), store.day(date).workday.start),
    );
    final result = await editInterval('Report interruption', (
      start: start,
      end: math.min(start + 30, 1440),
    ));
    if (result == null) return;
    final time = result.interval;
    await review(
      store.preview(
        date,
        interruption: (
          id: 'interruption-$date-${time.start}-${time.end}',
          start: time.start,
          end: time.end,
        ),
      ),
    );
  }

  Future<({Minutes interval, String label, BlockKind kind})?> editInterval(
    String title,
    Minutes initial, {
    String? label,
    BlockKind? kind,
  }) => showDialog(
    context: context,
    builder: (_) => _IntervalEditor(
      title: title,
      interval: initial,
      label: label,
      kind: kind,
    ),
  );

  Future<void> interpret() async {
    final input = await showDialog<String>(
      context: context,
      builder: (_) => _RequestDialog(date: date),
    );
    if (input == null) return;
    final result = await agent.interpret(
      input,
      date,
      store.day(date).workday,
      store.cutoffFor(date),
    );
    if (!mounted) return;
    if (result.question != null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clarify the request'),
          content: Text(result.question!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    final interval = result.interval!;
    if (result.kind == 'unavailable' &&
        interval.start < store.cutoffFor(date)) {
      throw StateError('That time has already started. Request a later time.');
    }
    await review(
      store.preview(
        date,
        workday: result.kind == 'workday' ? interval : null,
        constraint: result.kind == 'unavailable'
            ? PlanBlock(
                'constraint-${DateTime.now().microsecondsSinceEpoch}',
                'Unavailable',
                interval.start,
                interval.end,
                BlockKind.unavailable,
              )
            : null,
      ),
    );
  }

  void history(DayPlan day) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revision history'),
        content: SizedBox(
          width: 560,
          child: day.history.isEmpty
              ? const Text('No approved revisions yet.')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final entry in day.history.reversed)
                      ExpansionTile(
                        title: Text(
                          'Revision ${entry['revision']} · ${entry['reason']}',
                        ),
                        subtitle: Text(
                          MaterialLocalizations.of(context).formatMediumDate(
                            DateTime.parse(entry['time'] as String).toLocal(),
                          ),
                        ),
                        children: [
                          for (final change in entry['changes'] as List)
                            ListTile(
                              title: Text(
                                '${change['title']} · ${change['kind']}',
                              ),
                              subtitle: Text(
                                '${change['before'] ?? 'Unscheduled'} → ${change['after'] ?? 'Unscheduled'}\n${change['reason']}',
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final current = store.day(date);
      final timeline = [...current.approved, ...current.reserved]
        ..sort((a, b) => a.start.compareTo(b.start));
      final editable = !busy && store.cutoffFor(date) < 1440;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Planify · Calendar'),
          actions: [
            IconButton(
              tooltip: 'Revision history',
              onPressed: () => history(current),
              icon: const Icon(Icons.history),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (busy) const LinearProgressIndicator(),
                TextButton.icon(
                  onPressed: busy ? null : chooseDate,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    MaterialLocalizations.of(context)
                        .formatFullDate(DateTime.parse(date)),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Working hours'),
                  subtitle: Text(
                    intervalLabel(current.workday.start, current.workday.end),
                  ),
                  trailing: IconButton(
                    tooltip: 'Edit working hours',
                    onPressed: editable ? () => run(editHours) : null,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: editable
                          ? () => run(() => review(store.preview(date)))
                          : null,
                      icon: const Icon(Icons.calendar_view_day),
                      label: const Text('Generate schedule'),
                    ),
                    OutlinedButton.icon(
                      onPressed: editable
                          ? () => run(() => editReserved())
                          : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Reserve time'),
                    ),
                    OutlinedButton.icon(
                      onPressed: editable ? () => run(interrupt) : null,
                      icon: const Icon(Icons.pause_circle_outline),
                      label: const Text('Report interruption'),
                    ),
                    OutlinedButton.icon(
                      onPressed: editable ? () => run(interpret) : null,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Ask planning AI'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Day timeline',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (current.approved.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No approved task blocks for this day.'),
                  ),
                for (final block in timeline)
                  Card(
                    child: ListTile(
                      leading: Icon(switch (block.kind) {
                        BlockKind.task => Icons.checklist,
                        BlockKind.pause => Icons.coffee_outlined,
                        _ => Icons.lock_outline,
                      }),
                      title: Text(block.title),
                      subtitle: Text(
                        '${intervalLabel(block.start, block.end)} · ${switch (block.kind) {
                          BlockKind.task => 'Task',
                          BlockKind.pause => 'Break',
                          BlockKind.commitment => 'Fixed commitment',
                          BlockKind.unavailable => 'Unavailable',
                        }}',
                      ),
                      trailing:
                          block.kind != BlockKind.task &&
                              editable &&
                              block.start >= store.cutoffFor(date)
                          ? PopupMenuButton<String>(
                              tooltip: 'Manage reserved time',
                              onSelected: (action) => run(
                                () => action == 'edit'
                                    ? editReserved(block)
                                    : removeReserved(block),
                              ),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Remove'),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _IntervalEditor extends StatefulWidget {
  const _IntervalEditor({
    required this.title,
    required this.interval,
    this.label,
    this.kind,
  });
  final String title;
  final Minutes interval;
  final String? label;
  final BlockKind? kind;

  @override
  State<_IntervalEditor> createState() => _IntervalEditorState();
}

class _IntervalEditorState extends State<_IntervalEditor> {
  final form = GlobalKey<FormState>();
  late final start = TextEditingController(
    text: clockLabel(widget.interval.start),
  );
  late final end = TextEditingController(text: clockLabel(widget.interval.end));
  late final label = TextEditingController(text: widget.label);
  late BlockKind kind = widget.kind ?? BlockKind.commitment;

  int? parse(String input) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(input.trim());
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour == 24 && minute == 0) return 1440;
    return hour < 24 && minute < 60 ? hour * 60 + minute : null;
  }

  @override
  void dispose() {
    start.dispose();
    end.dispose();
    label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.label != null) ...[
              TextFormField(
                controller: label,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (_) =>
                    label.text.trim().isEmpty ? 'Enter a title.' : null,
              ),
              DropdownButtonFormField<BlockKind>(
                initialValue: kind,
                items: [
                  const DropdownMenuItem(
                    value: BlockKind.commitment,
                    child: Text('Fixed commitment'),
                  ),
                  const DropdownMenuItem(
                    value: BlockKind.pause,
                    child: Text('Break'),
                  ),
                  if (kind == BlockKind.unavailable)
                    const DropdownMenuItem(
                      value: BlockKind.unavailable,
                      child: Text('Unavailable'),
                    ),
                ],
                onChanged: (value) => setState(() => kind = value!),
              ),
            ],
            TextFormField(
              controller: start,
              decoration: const InputDecoration(labelText: 'Start (HH:mm)'),
              validator: (value) => (parse(value!) ?? 1440) >= 1440
                  ? 'Enter a time from 00:00 to 23:59.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: end,
              decoration: const InputDecoration(labelText: 'End (HH:mm)'),
              validator: (value) =>
                  (parse(value!) ?? -1) <= (parse(start.text) ?? 1440)
                  ? 'Enter an end after the start.'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, (
              interval: (start: parse(start.text)!, end: parse(end.text)!),
              label: label.text.trim(),
              kind: kind,
            ));
          }
        },
        child: const Text('Preview'),
      ),
    ],
  );
}

class _RequestDialog extends StatefulWidget {
  const _RequestDialog({required this.date});
  final String date;

  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  final input = TextEditingController();
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ask planning AI'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Planning for ${widget.date}. Your request, date and working hours go to the AI provider.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: input,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Scheduling request',
            hintText: 'Keep 14:00–15:00 free',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (input.text.trim().isNotEmpty) {
            Navigator.pop(context, input.text.trim());
          }
        },
        child: const Text('Interpret'),
      ),
    ],
  );
}

class _ProposalDialog extends StatefulWidget {
  const _ProposalDialog({
    required this.draft,
    required this.store,
    required this.agent,
  });
  final PlanDraft draft;
  final PlanningStore store;
  final PlanningAgent agent;

  @override
  State<_ProposalDialog> createState() => _ProposalDialogState();
}

class _ProposalDialogState extends State<_ProposalDialog> {
  bool loading = false;
  String? error;
  List<({PlanChange change, String text})> notes = [];

  Future<void> explain() async {
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Explain this proposal with AI?'),
        content: const Text(
          'The AI provider receives the proposed changes, including titles, times and reasons.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (!mounted || consent != true) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.agent.explain(widget.draft);
      if (mounted) setState(() => notes = result);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'AI explanation unavailable. Planner reasons are shown below.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return ListenableBuilder(
      listenable: Listenable.merge([widget.store, widget.store.tasks]),
      builder: (context, _) {
        final stale = widget.store.isStale(draft);
        return AlertDialog(
          title: const Text('Review schedule proposal'),
          content: SizedBox(
            width: 620,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text('${draft.day} · ${draft.reason}'),
                Text(
                  'Working hours ${intervalLabel(draft.workday.start, draft.workday.end)}',
                ),
                if (stale)
                  const Text('This preview is out of date. Generate it again.'),
                if (loading) const LinearProgressIndicator(),
                if (error != null) Text(error!),
                for (final row in notes)
                  ListTile(
                    title: Text(row.change.title),
                    subtitle: Text(row.text),
                  ),
                if (draft.result.changes.isEmpty)
                  const Text('No tasks or reserved blocks to schedule.'),
                for (final change in draft.result.changes)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${change.title} · ${change.kind.name}'),
                    subtitle: Text(
                      '${change.before ?? 'Unscheduled'} → ${change.after ?? 'Unscheduled'}\n${change.reason}',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Discard'),
            ),
            OutlinedButton(
              onPressed: loading || draft.result.changes.isEmpty
                  ? null
                  : explain,
              child: const Text('Explain with AI'),
            ),
            FilledButton(
              onPressed: stale ? null : () => Navigator.pop(context, true),
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );
  }
}
