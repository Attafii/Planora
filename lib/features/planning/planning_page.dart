import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/services/app_session.dart';

import '../../app/theme/planify_brand.dart';
import '../tasks/task_store.dart';
import 'calendar_panel.dart';
import 'planning_agent.dart';
import 'planning_engine.dart';
import 'planning_store.dart';

class PlanningPage extends StatefulWidget {
  const PlanningPage({
    super.key,
    required this.store,
    this.agent = const PlanningAgent(),
  });
  final PlanningStore store;
  final PlanningAgent agent;

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  PlanningAgent get agent => widget.agent;
  String date = dayKey(DateTime.now());
  CalendarView calendarView = CalendarView.month;
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
              e is ApiFailure
                  ? e.message
                  : e is StateError
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
    final value = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(date),
      firstDate: DateTime(firstCalendarYear),
      lastDate: DateTime(lastCalendarYear, 12, 31),
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
    final start = math.min(1439, math.max(540, store.cutoffFor(date)));
    final result = await editInterval(
      'Add event',
      block?.interval ?? (start: start, end: math.min(start + 30, 1440)),
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
      final canEdit = !busy && store.cutoffFor(date) < 1440;
      final calendar = CalendarPanel(
        date: DateTime.parse(date),
        view: calendarView,
        enabled: !busy,
        blocksFor: store.calendarEntries,
        onJump: chooseDate,
        onDate: (value) => setState(() => date = dayKey(value)),
        onView: (value) => setState(() => calendarView = value),
      );
      final agenda = buildAgenda(context, current, timeline, canEdit);
      return Scaffold(
        appBar: AppBar(
          leading: const Center(child: PlanifyMark(size: 30)),
          title: const Text('Planify · Calendar'),
          actions: [
            IconButton(
              tooltip: 'Revision history for selected date',
              onPressed: () => history(current),
              icon: const Icon(Icons.history_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final split =
                constraints.maxWidth >= 1000 &&
                calendarView != CalendarView.day;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: ListView(
                  padding: EdgeInsets.all(split ? 24 : 14),
                  children: [
                    if (busy) const LinearProgressIndicator(),
                    if (split)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: calendar),
                          const SizedBox(width: 24),
                          Expanded(flex: 5, child: agenda),
                        ],
                      )
                    else ...[
                      calendar,
                      const SizedBox(height: 18),
                      agenda,
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );

  Widget buildAgenda(
    BuildContext context,
    DayPlan plan,
    List<PlanBlock> timeline,
    bool editable,
  ) {
    final theme = Theme.of(context);
    final dateLabel = MaterialLocalizations.of(context)
        .formatFullDate(DateTime.parse(date));
    final scheduled = plan.approved.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Agenda', style: theme.textTheme.headlineMedium),
            Text(dateLabel, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('Working hours'),
              subtitle: Text(
                intervalLabel(plan.workday.start, plan.workday.end),
              ),
              trailing: IconButton(
                tooltip: 'Edit working hours',
                onPressed: editable ? () => run(editHours) : null,
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: editable
                      ? () => run(() => review(store.preview(date)))
                      : null,
                  icon: const Icon(Icons.auto_fix_high_rounded),
                  label: const Text('Generate schedule'),
                ),
                OutlinedButton.icon(
                  onPressed: editable ? () => run(() => editReserved()) : null,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add event'),
                ),
                OutlinedButton.icon(
                  onPressed: editable ? () => run(interrupt) : null,
                  icon: const Icon(Icons.pause_circle_outline),
                  label: const Text('Report interruption'),
                ),
                OutlinedButton.icon(
                  onPressed: editable ? () => run(interpret) : null,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Ask planning AI'),
                ),
              ],
            ),
            const Divider(),
            if (scheduled == 0)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('No approved tasks on this date.'),
              ),
            for (final block in timeline)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: buildBlock(context, block, editable),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildBlock(BuildContext context, PlanBlock block, bool editable) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canManage =
        editable &&
        block.kind != BlockKind.task &&
        block.start >= store.cutoffFor(date);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              clockLabel(block.start),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Expanded(
          child: Material(
            color: blockColor(scheme, block.kind),
            borderRadius: BorderRadius.circular(14),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              leading: Icon(blockIcon(block.kind), color: scheme.onSurface),
              title: Text(block.title),
              subtitle: Text(
                '${blockType(block.kind)} · Until ${clockLabel(block.end)}',
              ),
              onTap: () => showBlock(block, canManage),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> showBlock(PlanBlock block, bool canManage) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(block.title),
        content: Text(
          '${blockType(block.kind)}\n'
          '${MaterialLocalizations.of(context).formatFullDate(DateTime.parse(date))}\n'
          '${intervalLabel(block.start, block.end)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (canManage) ...[
            TextButton(
              onPressed: () => Navigator.pop(context, 'remove'),
              child: const Text('Remove'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'edit'),
              child: const Text('Edit event'),
            ),
          ],
        ],
      ),
    );
    if (action == 'edit' && mounted) await run(() => editReserved(block));
    if (action == 'remove' && mounted) await run(() => removeReserved(block));
  }
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
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = failure is ApiFailure
              ? failure.message
              : 'AI explanation unavailable. Planner reasons are shown below.',
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
