import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/services/app_session.dart';

import '../../app/theme/planify_brand.dart';
import '../tasks/task_store.dart';
import 'calendar_panel.dart';
import 'planning_agent.dart';
import 'planning_engine.dart';
import 'planning_store.dart';

typedef IntervalInput = ({Minutes interval, String label, BlockKind kind});

class PlanningPage extends StatefulWidget {
  const PlanningPage({
    super.key,
    required this.store,
    this.embedded = false,
    this.agent = const PlanningAgent(),
    this.initialInterruptionId,
    this.syncStatus,
    this.onStartFocus,
  });
  final PlanningStore store;
  final bool embedded;
  final PlanningAgent agent;
  final String? initialInterruptionId;
  final Widget? syncStatus;
  final void Function(String date, PlanBlock block)? onStartFocus;

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  PlanningAgent get agent => widget.agent;
  late String date;

  @override
  void initState() {
    super.initState();
    date = dayKey(store.localNow);
    if (widget.initialInterruptionId case final id?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) run(() => interrupt(intentId: id));
      });
    }
  }

  CalendarView calendarView = CalendarView.month;
  bool busy = false;
  bool interpreting = false;
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

  // True means the user wants to edit the request and preview it again.
  Future<bool> review(PlanDraft draft, {bool canRevise = false}) async {
    if (!mounted) return false;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProposalDialog(
        draft: draft,
        store: store,
        agent: agent,
        canRevise: canRevise,
      ),
    );
    if (action == 'approved' && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Revision ${store.day(draft.day).version} saved on this device.',
          ),
        ),
      );
    }
    return action == 'revise';
  }

  Future<void> reviewInterval(
    String title,
    Minutes initial,
    PlanDraft Function(IntervalInput) propose, {
    String? label,
    BlockKind? kind,
  }) async {
    var seed = initial;
    while (mounted) {
      PlanDraft? draft;
      final input = await editInterval(
        title,
        seed,
        label: label,
        kind: kind,
        validate: (candidate) => draft = propose(candidate),
      );
      if (input == null || !await review(draft!, canRevise: true)) return;
      seed = input.interval;
      if (label != null) label = input.label;
      if (kind != null) kind = input.kind;
    }
  }

  Future<void> editHours() => reviewInterval(
    'Working hours',
    store.day(date).workday,
    (input) => store.preview(date, workday: input.interval),
  );

  Future<void> editReserved([PlanBlock? block]) {
    final start = math.min(1439, math.max(540, store.cutoffFor(date)));
    final id = block?.id ?? 'event-${DateTime.now().microsecondsSinceEpoch}';
    return reviewInterval(
      block == null ? 'Add event' : 'Edit event',
      block?.interval ?? (start: start, end: math.min(start + 30, 1440)),
      (input) => store.preview(
        date,
        reservedOverride: [
          ...store.day(date).reserved.where((item) => item.id != id),
          PlanBlock(
            id,
            input.label,
            input.interval.start,
            input.interval.end,
            input.kind,
          ),
        ],
      ),
      label: block?.title ?? '',
      kind: block?.kind ?? BlockKind.commitment,
    );
  }

  Future<void> generate() async {
    await review(store.preview(date));
  }

  Future<void> taskWindow() async {
    final candidates = store.candidatesFor(date);
    if (candidates.isEmpty) {
      throw StateError(
        'There are no unfinished tasks to constrain on this date.',
      );
    }
    final selection = await showDialog<PlanningTask>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose a task for a time window'),
        children: [
          for (final task in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, task),
              child: Text('${task.title} · ${task.minutes} min'),
            ),
        ],
      ),
    );
    if (selection == null || !mounted) return;
    await editWindow(selection);
  }

  Future<void> editWindow(PlanningTask task) => reviewInterval(
    'Time window for ${task.title}',
    store.day(date).windows[task.id] ?? store.day(date).workday,
    (input) => store.preview(
      date,
      windowsOverride: {...store.day(date).windows, task.id: input.interval},
    ),
  );

  Future<void> clearWindow(String id) async {
    final next = {...store.day(date).windows}..remove(id);
    await review(store.preview(date, windowsOverride: next));
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

  Future<void> interrupt({String? intentId}) {
    final start = math.min(
      1439,
      math.max(store.cutoffFor(date), store.day(date).workday.start),
    );
    return reviewInterval(
      'Report interruption',
      (start: start, end: math.min(start + 30, 1440)),
      (input) {
        final time = input.interval;
        return store.preview(
          date,
          interruption: (
            id: intentId ?? 'interruption-$date-${time.start}-${time.end}',
            start: time.start,
            end: time.end,
          ),
        );
      },
    );
  }

  Future<IntervalInput?> editInterval(
    String title,
    Minutes initial, {
    String? label,
    BlockKind? kind,
    required void Function(IntervalInput) validate,
  }) => showDialog(
    context: context,
    builder: (_) => _IntervalEditor(
      title: title,
      interval: initial,
      label: label,
      kind: kind,
      validate: validate,
    ),
  );

  Future<void> interpret() async {
    if (!agent.cloudAiEnabled) {
      throw StateError(
        'Cloud AI is off. Use the calendar forms or enable Cloud AI in Privacy.',
      );
    }
    final input = await showDialog<String>(
      context: context,
      builder: (_) => _RequestDialog(date: date),
    );
    if (input == null) return;
    if (!mounted) return;
    setState(() => interpreting = true);
    final ({String kind, Minutes? interval, String? question}) result;
    try {
      result = await agent.interpret(
        input,
        date,
        store.day(date).workday,
        store.cutoffFor(date),
        timezone: store.clock.zone(),
      );
    } finally {
      if (mounted) setState(() => interpreting = false);
    }
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
    final workingHours = result.kind == 'workday';
    final id = 'constraint-${DateTime.now().microsecondsSinceEpoch}';
    await reviewInterval(
      workingHours
          ? 'Review interpreted working hours'
          : 'Review interpreted unavailable time',
      interval,
      (input) => store.preview(
        date,
        workday: workingHours ? input.interval : null,
        constraint: workingHours
            ? null
            : PlanBlock(
                id,
                'Unavailable',
                input.interval.start,
                input.interval.end,
                BlockKind.unavailable,
              ),
      ),
    );
  }

  void externalCalendars() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('External calendars'),
        content: const Text(
          'Calendar import and export are unavailable. Planify needs a configured calendar provider and a connection that grants access to your calendar.',
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

  Future<void> history(DayPlan day) async {
    final selected = await showDialog<Map<String, dynamic>>(
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
                            store.clock.local(
                              DateTime.parse(entry['time'] as String),
                            ),
                          ),
                        ),
                        children: [
                          if (entry['snapshot'] != null &&
                              store.cutoffFor(date) < 1440)
                            TextButton(
                              onPressed: () => Navigator.pop(context, entry),
                              child: const Text('Preview restore'),
                            ),
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
    if (selected != null && mounted) {
      await run(() async {
        await review(store.restoreRevision(date, selected));
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([store, store.tasks, agent.session]),
    builder: (context, _) {
      final current = store.day(date);
      final timeline = [...store.visibleApproved(date), ...current.reserved]
        ..sort((a, b) => a.start.compareTo(b.start));
      final canEdit = !busy && store.cutoffFor(date) < 1440;
      final calendar = CalendarPanel(
        date: DateTime.parse(date),
        today: store.localNow,
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
          leading: widget.embedded
              ? null
              : const Center(child: PlanifyMark(size: 30)),
          title: Text(widget.embedded ? 'Calendar' : 'Planify · Calendar'),
          actions: [
            IconButton(
              tooltip: 'Revision history for selected date',
              onPressed: () => history(current),
              icon: const Icon(Icons.history_rounded),
            ),
            IconButton(
              tooltip: 'External calendars',
              onPressed: externalCalendars,
              icon: const Icon(Icons.link_off_outlined),
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
                    if (interpreting) const LinearProgressIndicator(),
                    ?widget.syncStatus,
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
    final scheduled = store.visibleApproved(date).length;
    final unscheduled = store.unscheduled(date);
    final candidates = {
      for (final task in store.candidatesFor(date)) task.id: task,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Agenda', style: theme.textTheme.headlineMedium),
            Text(dateLabel, style: theme.textTheme.titleMedium),
            if (store.clock.zone() case final zone?) Text(zone),
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
                  onPressed: editable ? () => run(generate) : null,
                  icon: const Icon(Icons.auto_fix_high_rounded),
                  label: const Text('Generate schedule'),
                ),
                OutlinedButton.icon(
                  onPressed: editable ? () => run(() => editReserved()) : null,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add event'),
                ),
                OutlinedButton.icon(
                  onPressed: editable ? () => run(() => interrupt()) : null,
                  icon: const Icon(Icons.pause_circle_outline),
                  label: const Text('Report interruption'),
                ),
                OutlinedButton.icon(
                  onPressed: editable ? () => run(taskWindow) : null,
                  icon: const Icon(Icons.timelapse_outlined),
                  label: const Text('Task time window'),
                ),
                OutlinedButton.icon(
                  onPressed: editable ? () => run(interpret) : null,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Ask planning AI'),
                ),
              ],
            ),
            for (final entry in plan.windows.entries)
              ListTile(
                title: Text(
                  '${candidates[entry.key]?.title ?? store.tasks.get(entry.key)?.title ?? 'Unavailable task'} · Time window',
                ),
                subtitle: Text(
                  intervalLabel(entry.value.start, entry.value.end),
                ),
                onTap: editable && candidates.containsKey(entry.key)
                    ? () => run(() => editWindow(candidates[entry.key]!))
                    : null,
                trailing: IconButton(
                  tooltip: 'Remove task time window',
                  onPressed: editable
                      ? () => run(() => clearWindow(entry.key))
                      : null,
                  icon: const Icon(Icons.close_rounded),
                ),
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
            const Divider(),
            Text('Unscheduled tasks', style: theme.textTheme.titleMedium),
            if (unscheduled.isEmpty) const Text('No unscheduled tasks.'),
            for (final task in unscheduled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: Text(task.title),
                subtitle: Text(task.reason),
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
    final selectedDate = date;
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
          if (block.kind == BlockKind.task && widget.onStartFocus != null)
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, 'focus'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start focus'),
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
    if (action == 'focus' && mounted) widget.onStartFocus!(selectedDate, block);
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
    required this.validate,
  });
  final String title;
  final void Function(IntervalInput) validate;
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
  String? error;

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
            if (error case final message?)
              Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
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
          if (!form.currentState!.validate()) return;
          final input = (
            interval: (start: parse(start.text)!, end: parse(end.text)!),
            label: label.text.trim(),
            kind: kind,
          );
          try {
            widget.validate(input);
          } on StateError catch (failure) {
            setState(() => error = failure.message);
            return;
          }
          Navigator.pop(context, input);
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
    required this.canRevise,
    required this.draft,
    required this.store,
    required this.agent,
  });
  final bool canRevise;
  final PlanDraft draft;
  final PlanningStore store;
  final PlanningAgent agent;

  @override
  State<_ProposalDialog> createState() => _ProposalDialogState();
}

class _ProposalDialogState extends State<_ProposalDialog> {
  bool loading = false;
  bool saving = false;
  late PlanDraft draft;
  Timer? clock;
  String? error;
  List<({PlanChange change, String text})> notes = [];

  @override
  void initState() {
    super.initState();
    draft = widget.draft;
    clock = Timer.periodic(const Duration(seconds: 15), (_) => setState(() {}));
  }

  @override
  void dispose() {
    clock?.cancel();
    super.dispose();
  }

  Future<void> explain() async {
    if (!widget.agent.cloudAiEnabled) {
      setState(
        () => error = 'Cloud AI is off. Planner reasons are shown below.',
      );
      return;
    }
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
      final requested = draft;
      final result = await widget.agent.explain(requested);
      if (mounted && identical(draft, requested)) {
        setState(() => notes = result);
      }
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

  void recalculate() {
    try {
      final updated = widget.store.recalculate(draft);
      setState(() {
        draft = updated;
        notes = [];
        error = null;
      });
    } on StateError catch (failure) {
      setState(() => error = failure.message);
    }
  }

  Future<void> approve() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.store.approve(draft);
      if (mounted) Navigator.pop(context, 'approved');
    } catch (failure) {
      if (mounted) {
        setState(() {
          saving = false;
          error = failure is StateError ? failure.message : 'Could not save the proposal. The approved plan is still in place. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.store,
      widget.store.tasks,
      widget.agent.session,
    ]),
    builder: (context, _) {
      final stale = widget.store.isStale(draft);
      final deferred = draft.result.changes.where(
        (change) => change.kind == ChangeKind.deferred,
      );
      return PopScope(
        canPop: !saving,
        child: AlertDialog(
          title: const Text('Review schedule proposal'),
          content: SizedBox(
            width: 620,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text('${draft.day} · ${draft.reason}'),
                if (draft.zone case final zone?) Text(zone),
                Text(
                  'Working hours ${intervalLabel(draft.workday.start, draft.workday.end)}',
                ),
                for (final window in draft.windows.entries)
                  Text(
                    '${widget.store.tasks.get(window.key)?.title ?? 'Unavailable task'} · ${intervalLabel(window.value.start, window.value.end)}',
                  ),
                if (draft.interruption != null)
                  const Text(
                    'Elapsed blocks show planned time. Actual focus time is recorded in Focus.',
                  ),
                if (stale)
                  const Text(
                    'This preview is out of date. Recalculate to review the latest plan.',
                  ),
                if (saving || loading) const LinearProgressIndicator(),
                if (error case final message?) Text(message),
                if (notes.isNotEmpty) const Text('Changes highlighted by AI'),
                for (final row in notes)
                  ListTile(
                    title: Text(row.change.title),
                    subtitle: Text(row.change.reason),
                  ),
                if (draft.result.changes.isEmpty)
                  const Text('No tasks or reserved blocks to schedule.'),
                if (deferred.isNotEmpty)
                  Text(
                    '${deferred.length} task${deferred.length == 1 ? ' has' : 's have'} work that could not be placed.',
                  ),
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
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Discard'),
            ),
            if (widget.canRevise)
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.pop(context, 'revise'),
                child: const Text('Revise'),
              ),
            if (stale)
              TextButton(
                onPressed: saving ? null : recalculate,
                child: const Text('Recalculate'),
              ),
            OutlinedButton(
              onPressed:
                  saving || stale || loading || draft.result.changes.isEmpty
                  ? null
                  : explain,
              child: const Text('Explain with AI'),
            ),
            FilledButton(
              onPressed: saving || stale ? null : approve,
              child: Text(saving ? 'Saving…' : 'Approve'),
            ),
          ],
        ),
      );
    },
  );
}
