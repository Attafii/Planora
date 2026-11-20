import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../../core/services/app_session.dart';

import 'task_agent.dart';
import 'task_store.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({
    super.key,
    required this.store,
    this.embedded = false,
    this.agent = const TaskAgent(),
  });
  final TaskStore store;
  final bool embedded;
  final TaskAgent agent;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  TaskAgent get agent => widget.agent;
  String query = '';
  bool busy = false;
  bool readyOnly = false;
  TaskStore get store => widget.store;

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        final label = error is ApiFailure
            ? error.message
            : error is StateError
            ? error.message
            : 'Could not complete the request. Try again.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(label)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit({Task? task, bool future = false}) async {
    final draft = await showDialog<Task>(
      context: context,
      builder: (_) => _TaskEditor(store: store, task: task, future: future),
    );
    if (draft != null && mounted) {
      await run(() => store.save(draft, future: future));
    }
  }

  Future<void> remove(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          task.occurrence ? 'Skip this occurrence?' : 'Delete this task?',
        ),
        content: Text(task.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(task.occurrence ? 'Skip' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await run(() => store.remove(task));
  }

  Future<void> steps(Task task, {required bool useAi}) async {
    await run(() async {
      final rev = store.revision;
      if (useAi &&
          !await consent(
            'Send this task title, estimate and existing step titles to the AI provider?',
          )) {
        return;
      }
      final suggestions = useAi
          ? await agent.decompose(task, store.children(task.id))
          : [''];
      if (!mounted) return;
      final applied = await showDialog<List<String>>(
        context: context,
        builder: (_) => _StepsEditor(suggestions: suggestions),
      );
      if (applied != null) {
        await store.addSteps(task, applied, expectedRevision: rev);
      }
    });
  }

  Future<bool> consent(String text) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Use AI'),
            content: Text(text),
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
        ) ??
        false;
  }

  Future<void> recommend() => run(() async {
    var minutes = 30;
    var energy = Energy.medium;
    final input = await showDialog<(int, Energy)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Find my next action'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: minutes,
                decoration: const InputDecoration(
                  labelText: 'Minutes available',
                ),
                items: [5, 10, 15, 20, 30, 45, 60, 90, 120]
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                    .toList(),
                onChanged: (n) => update(() => minutes = n!),
              ),
              DropdownButtonFormField<Energy>(
                initialValue: energy,
                decoration: const InputDecoration(
                  labelText: 'Available energy',
                ),
                items: Energy.values
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                    .toList(),
                onChanged: (e) => update(() => energy = e!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, (minutes, energy)),
              child: const Text('Find candidates'),
            ),
          ],
        ),
      ),
    );
    if (input == null || !mounted) return;
    final today = dayKey(DateTime.now());
    final available = store.inbox.where(
      (t) => !t.occurrence || t.due!.compareTo(today) <= 0,
    );
    final candidates = available
        .expand((parent) {
          final steps = store.children(parent.id);
          return steps.isEmpty ? [parent] : steps;
        })
        .where(
          (task) =>
              !store.completed(task) &&
              store.blockers(task).isEmpty &&
              task.minutes <= input.$1 &&
              task.energy.index <= input.$2.index,
        )
        .take(30)
        .toList();
    if (candidates.isEmpty) {
      throw StateError(
        'No unfinished action fits this time and energy with its prerequisites complete.',
      );
    }
    if (!await consent(
      'Send eligible task titles, estimates, energy and due dates to the AI provider?',
    )) {
      return;
    }
    final rev = store.revision;
    final (id, reason) = await agent.recommend(candidates, input.$1, input.$2);
    final selected = candidates.where((task) => task.id == id).firstOrNull;
    if (selected == null || rev != store.revision) {
      throw StateError('The recommendation is no longer available.');
    }
    if (!mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(selected.title),
        content: Text(reason),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open task'),
          ),
        ],
      ),
    );
    if (open == true && mounted) {
      final task = store.get(selected.parent ?? selected.id);
      if (task != null) detail(task);
    }
  });

  void detail(Task task) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final current = store.get(task.id);
            if (current == null || current.skipped) {
              return Scaffold(
                appBar: AppBar(title: const Text('Task unavailable')),
              );
            }
            final children = store.children(current.id);
            final blockers = store.blockers(current);
            final next = children
                .where(
                  (step) =>
                      !store.completed(step) && store.blockers(step).isEmpty,
                )
                .firstOrNull;
            return Scaffold(
              appBar: AppBar(
                title: const Text('Task details'),
                actions: [
                  IconButton(
                    tooltip: 'Edit task',
                    onPressed: () => edit(task: current),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  if (current.occurrence)
                    IconButton(
                      tooltip: 'Edit this and future occurrences',
                      onPressed: () => edit(task: current, future: true),
                      icon: const Icon(Icons.event_repeat),
                    ),
                  IconButton(
                    tooltip: current.occurrence
                        ? 'Skip occurrence'
                        : 'Delete task',
                    onPressed: () => remove(current),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              body: _TaskLayout(
                children: [
                  Text(
                    current.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    '${current.minutes} min · ${current.energy.name} energy${current.due == null ? '' : ' · Due ${current.due}'}',
                  ),
                  if (blockers.isNotEmpty)
                    Text(
                      'Blocked by ${blockers.map((t) => t.title).join(', ')}',
                    ),
                  if (children.isEmpty) _check(current),
                  if (next != null) Text('Next step · ${next.title}'),
                  if (children.isNotEmpty) ...[
                    Text(
                      '${(store.progress(current) * 100).round()}% complete',
                    ),
                    LinearProgressIndicator(value: store.progress(current)),
                    ...children.map(
                      (step) => Row(
                        children: [
                          Expanded(child: _check(step)),
                          IconButton(
                            tooltip: 'Edit subtask',
                            onPressed: () => edit(task: step),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Delete subtask',
                            onPressed: () => remove(step),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ],
                  OutlinedButton.icon(
                    onPressed: () => steps(current, useAi: false),
                    icon: const Icon(Icons.add),
                    label: const Text('Add subtask'),
                  ),
                  FilledButton.icon(
                    onPressed: () => steps(current, useAi: true),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Draft subtasks with AI'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _check(Task task) {
    final blockers = store.blockers(task);
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(task.parent == null ? 'Complete task' : task.title),
      subtitle: blockers.isEmpty
          ? null
          : Text('Blocked by ${blockers.map((t) => t.title).join(', ')}'),
      value: blockers.isEmpty && store.completed(task),
      onChanged: blockers.isEmpty ? (_) => run(() => store.toggle(task)) : null,
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final results = store.inbox
          .where(
            (task) =>
                task.title.toLowerCase().contains(query) &&
                (!readyOnly || store.ready(task)),
          )
          .toList();
      return Scaffold(
        appBar: widget.embedded
            ? null
            : AppBar(title: const Text('Planify · Tasks')),
        body: _TaskLayout(
          children: [
            _DailyHeader(
              ready: store.inbox.where(store.ready).length,
              completed: store.inbox.where(store.completed).length,
            ),
            if (busy) const LinearProgressIndicator(),
            TextField(
              onChanged: (value) =>
                  setState(() => query = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                labelText: 'Search tasks',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Ready only'),
                  selected: readyOnly,
                  onSelected: (value) => setState(() => readyOnly = value),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : recommend,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Find my next action'),
                ),
              ],
            ),
            if (results.isEmpty)
              Text(
                query.isEmpty && !readyOnly
                    ? 'Add a task to get started.'
                    : 'No matching tasks.',
              ),
            ...results.map((task) {
              final status = store.completed(task)
                  ? 'Done'
                  : store.ready(task)
                  ? 'Ready'
                  : 'Blocked';
              return Card(
                child: ListTile(
                  title: Text(task.title),
                  subtitle: Text(
                    '$status · ${task.minutes} min${task.due == null ? '' : ' · ${task.due}'}',
                  ),
                  leading: Icon(
                    task.occurrence
                        ? Icons.event_repeat
                        : activityIcon(task.activity),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => detail(task),
                ),
              );
            }),
            const SizedBox(height: 72),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: busy ? null : () => edit(),
          icon: const Icon(Icons.add),
          label: const Text('Add task'),
        ),
      );
    },
  );
}

class _TaskLayout extends StatelessWidget {
  const _TaskLayout({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: children
            .map(
              (child) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: child,
              ),
            )
            .toList(),
      ),
    ),
  );
}

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({required this.store, this.task, required this.future});
  final TaskStore store;
  final Task? task;
  final bool future;
  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  final form = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.task?.title);
  late final minutes = TextEditingController(
    text: '${widget.task?.minutes ?? 25}',
  );
  late ActivityType activity = widget.task?.activity ?? ActivityType.general;
  late Energy energy = widget.task?.energy ?? Energy.medium;
  late final requiredIds = {...?widget.task?.requires};
  late String? due = widget.task?.due;
  Repeat repeat = Repeat.once;

  Future<void> dictate() async {
    try {
      final words = await const MethodChannel('planify/voice')
          .invokeMethod<String>('dictate');
      if (!mounted || words == null || words.trim().isEmpty) return;
      final text = String.fromCharCodes(words.trim().runes.take(120));
      title.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech input is unavailable on this device.'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    title.dispose();
    minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.future
          ? 'Edit this and future occurrences'
          : widget.task == null
          ? 'New task'
          : 'Edit task',
    ),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: title,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: 'Title',
                  suffixIcon:
                      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
                      ? IconButton(
                          tooltip: 'Dictate task title',
                          icon: const Icon(Icons.mic_none),
                          onPressed: dictate,
                        )
                      : null,
                ),
                validator: (value) =>
                    value!.trim().isEmpty ? 'Enter a title.' : null,
              ),
              TextFormField(
                controller: minutes,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Estimated minutes',
                ),
                validator: (value) {
                  final n = int.tryParse(value!);
                  return n == null || n < 1 || n > 1440
                      ? 'Use 1–1440 minutes.'
                      : null;
                },
              ),
              DropdownButtonFormField<ActivityType>(
                initialValue: activity,
                decoration: const InputDecoration(labelText: 'Activity icon'),
                items: [
                  for (final type in ActivityType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Icon(activityIcon(type)),
                          const SizedBox(width: 12),
                          Text(type.name),
                        ],
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => activity = value!),
              ),
              DropdownButtonFormField<Energy>(
                initialValue: energy,
                decoration: const InputDecoration(labelText: 'Required energy'),
                items: Energy.values
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                    .toList(),
                onChanged: (e) => setState(() => energy = e!),
              ),
              if (widget.task?.occurrence != true) ...[
                TextButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final value = await showDatePicker(
                      context: context,
                      initialDate: due == null ? now : DateTime.parse(due!),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (value != null && mounted) {
                      setState(() => due = dayKey(value));
                    }
                  },
                  child: Text(due ?? 'Choose due date'),
                ),
                if (due != null && repeat == Repeat.once)
                  TextButton(
                    onPressed: () => setState(() => due = null),
                    child: const Text('Clear due date'),
                  ),
              ],
              if (widget.task == null)
                DropdownButtonFormField<Repeat>(
                  initialValue: repeat,
                  decoration: const InputDecoration(labelText: 'Repeat'),
                  items: Repeat.values
                      .map(
                        (r) => DropdownMenuItem(value: r, child: Text(r.name)),
                      )
                      .toList(),
                  onChanged: (r) => setState(() => repeat = r!),
                  validator: (_) => repeat != Repeat.once && due == null
                      ? 'Choose a first due date.'
                      : null,
                ),
              ...widget.store.prerequisites
                  .where(
                    (t) =>
                        t.id != widget.task?.id && t.id != widget.task?.parent,
                  )
                  .map(
                    (t) => CheckboxListTile(
                      title: Text(t.title),
                      subtitle: const Text('Prerequisite'),
                      value: requiredIds.contains(t.id),
                      onChanged: (checked) => setState(
                        () => checked!
                            ? requiredIds.add(t.id)
                            : requiredIds.remove(t.id),
                      ),
                    ),
                  ),
            ],
          ),
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
          final base =
              widget.task ??
              Task(id: widget.store.newId(), title: '', repeat: repeat);
          Navigator.pop(
            context,
            base.patch({
              'title': title.text.trim(),
              'minutes': int.parse(minutes.text),
              'energy': energy.name,
              'activity': activity.name,
              'due': due,
              'requires': requiredIds.toList(),
            }),
          );
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class _StepsEditor extends StatefulWidget {
  const _StepsEditor({required this.suggestions});
  final List<String> suggestions;
  @override
  State<_StepsEditor> createState() => _StepsEditorState();
}

class _StepsEditorState extends State<_StepsEditor> {
  late final fields = widget.suggestions
      .map((s) => TextEditingController(text: s))
      .toList();

  @override
  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Review subtasks'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final field in fields)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: field,
                      maxLength: 120,
                      decoration: const InputDecoration(labelText: 'Subtask'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Discard step',
                    onPressed: () => setState(() => field.clear()),
                    icon: const Icon(Icons.clear),
                  ),
                ],
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
          final titles = fields
              .map((field) => field.text.trim())
              .where((title) => title.isNotEmpty)
              .toList();
          if (titles.isNotEmpty) Navigator.pop(context, titles);
        },
        child: const Text('Save subtasks'),
      ),
    ],
  );
}

class _DailyHeader extends StatelessWidget {
  const _DailyHeader({required this.ready, required this.completed});

  final int ready;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: colors.primaryContainer,
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.5,
          colors: dark
              ? const [Color(0xFF40644D), Color(0xFF223E36)]
              : const [Color(0xFFF8E8C8), Color(0xFFD9EFE2)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MaterialLocalizations.of(context).formatFullDate(DateTime.now()),
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Text('Your tasks', style: theme.textTheme.headlineLarge),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            child: Text(
              '$ready ready · $completed complete',
              key: ValueKey((ready, completed)),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

IconData activityIcon(ActivityType type) => switch (type) {
  ActivityType.general => Icons.task_alt,
  ActivityType.work => Icons.work_outline,
  ActivityType.study => Icons.menu_book_outlined,
  ActivityType.movement => Icons.directions_walk,
  ActivityType.personal => Icons.spa_outlined,
};
