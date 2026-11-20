import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../../core/services/app_session.dart';
import '../focus/focus_store.dart';
import '../focus/pages.dart' show clock;

import 'task_agent.dart';
import 'task_store.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({
    super.key,
    required this.store,
    this.embedded = false,
    this.agent = const TaskAgent(),
    this.syncStatus,
    this.focus,
    this.initialTaskId,
  });
  final TaskStore store;
  final bool embedded;
  final TaskAgent agent;
  final Widget? syncStatus;
  final FocusStore? focus;
  final String? initialTaskId;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  TaskAgent get agent => widget.agent;
  String query = '';
  bool busy = false;
  bool readyOnly = false;
  bool showSkipped = false;
  TaskStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    final id = widget.initialTaskId;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (store.get(id) case final task?) detail(task);
      });
    }
  }

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
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TaskEditor(store: store, task: task, future: future),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task saved on this device.')),
      );
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
          agent.cloudAiEnabled &&
          !await consent(
            'Send this task title, estimate and existing step titles to the AI provider?',
          )) {
        return;
      }
      if (!mounted) return;
      final applied = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _StepsEditor(
          generate: useAi
              ? () => agent.decompose(task, store.children(task.id))
              : null,
          save: (titles) => store.addSteps(task, titles, expectedRevision: rev),
        ),
      );
      if (applied == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subtasks saved on this device.')),
        );
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

  Future<void> recommend() async {
    final choice = await showDialog<Task>(
      context: context,
      builder: (_) =>
          _NextActionDialog(store: store, agent: agent, consent: consent),
    );
    if (choice != null && mounted) {
      final action = store.get(choice.id);
      final task = store.get(choice.parent ?? choice.id);
      if (action != null && task != null && store.ready(action)) {
        detail(task, suggestedStep: action.parent == null ? null : action.id);
      }
    }
  }

  void detail(Task task, {String? suggestedStep}) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ListenableBuilder(
          listenable: Listenable.merge([store, widget.focus]),
          builder: (context, _) {
            final current = store.get(task.id);
            if (current == null || current.skipped) {
              return Scaffold(
                appBar: AppBar(title: const Text('Task unavailable')),
              );
            }
            final children = store.children(current.id);
            final recorded = widget.focus?.recordedSecondsFor({
              current.id,
              ...children.map((step) => step.id),
            });
            final blockers = store.blockers(current);
            final readySteps = children.where(store.ready);
            final next =
                readySteps
                    .where((step) => step.id == suggestedStep)
                    .firstOrNull ??
                readySteps.firstOrNull;
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
                  ?widget.syncStatus,
                  Text(
                    current.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    '${current.minutes} min · ${current.energy.name} energy${current.due == null ? '' : ' · Due ${current.due}'}',
                  ),
                  if (recorded != null)
                    Text(
                      recorded == 0
                          ? 'No recorded focus time.'
                          : 'Recorded focus time · ${clock(recorded)} (min:sec)',
                    ),
                  if (blockers.isNotEmpty)
                    Text(
                      'Blocked by ${blockers.map((t) => t.title).join(', ')}',
                    ),
                  if (blockers.isEmpty && store.ready(current))
                    const Text('Ready · Prerequisites are complete.'),
                  if (blockers.isEmpty &&
                      !store.ready(current) &&
                      !store.completed(current))
                    const Text(
                      'Blocked · Complete the prerequisites shown under each subtask.',
                    ),
                  if (children.isEmpty) _check(current),
                  if (next != null)
                    Text(
                      '${next.id == suggestedStep ? 'Suggested step' : 'Next step'} · ${next.title}',
                    ),
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
            ?widget.syncStatus,
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
                if (store.skippedOccurrences.isNotEmpty)
                  FilterChip(
                    label: const Text('Show skipped'),
                    selected: showSkipped,
                    onSelected: (value) => setState(() => showSkipped = value),
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
            if (showSkipped)
              for (final skipped in store.skippedOccurrences)
                if (skipped.title.toLowerCase().contains(query))
                  ListTile(
                    title: Text(skipped.title),
                    subtitle: Text('Skipped · ${skipped.due}'),
                    trailing: TextButton(
                      onPressed: busy
                          ? null
                          : () =>
                                run(() => store.restoreOccurrence(skipped.id)),
                      child: const Text('Restore occurrence'),
                    ),
                  ),
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
  late final int revision;
  late final String id;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    revision = widget.store.revision;
    id = widget.task?.id ?? widget.store.newId();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    final base = widget.task ?? Task(id: id, title: '', repeat: repeat);
    try {
      await widget.store.save(
        base.patch({
          'title': title.text.trim(),
          'minutes': int.parse(minutes.text),
          'energy': energy.name,
          'activity': activity.name,
          'due': due,
          'requires': requiredIds.toList(),
        }),
        future: widget.future,
        expectedRevision: revision,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (failure) {
      if (mounted) {
        setState(() {
          error = taskError(failure, 'Could not save this task. Try again.');
          saving = false;
        });
      }
    }
  }

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
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
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
                if (widget.future)
                  const Text(
                    'These changes apply from this date onward. Completed and skipped occurrences and other individual edits are preserved.',
                  ),
                if (error case final message?)
                  Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                TextFormField(
                  controller: title,
                  maxLength: 120,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    suffixIcon:
                        !kIsWeb &&
                            defaultTargetPlatform == TargetPlatform.android
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
                  decoration: const InputDecoration(
                    labelText: 'Required energy',
                  ),
                  items: Energy.values
                      .map(
                        (e) => DropdownMenuItem(value: e, child: Text(e.name)),
                      )
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
                          (r) =>
                              DropdownMenuItem(value: r, child: Text(r.name)),
                        )
                        .toList(),
                    onChanged: (r) => setState(() => repeat = r!),
                    validator: (_) => repeat != Repeat.once && due == null
                        ? 'Choose a first due date.'
                        : null,
                  ),
                for (final id in requiredIds.difference(
                  widget.store.prerequisites.map((task) => task.id).toSet(),
                ))
                  CheckboxListTile(
                    title: const Text('Unavailable prerequisite'),
                    value: true,
                    onChanged: saving
                        ? null
                        : (_) => setState(() => requiredIds.remove(id)),
                  ),
                ...widget.store.prerequisites
                    .where(
                      (t) =>
                          t.id != widget.task?.id &&
                          t.id != widget.task?.parent,
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
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(saving ? 'Saving…' : 'Save'),
        ),
      ],
    ),
  );
}

String taskError(Object failure, String fallback) => switch (failure) {
  ApiFailure(:final message) => message,
  StateError(:final message) => message,
  _ => fallback,
};

class _StepsEditor extends StatefulWidget {
  const _StepsEditor({required this.generate, required this.save});

  final Future<List<String>> Function()? generate;
  final Future<void> Function(List<String>) save;

  @override
  State<_StepsEditor> createState() => _StepsEditorState();
}

class _StepsEditorState extends State<_StepsEditor> {
  final fields = <TextEditingController>[];
  final discarded = <TextEditingController>[];
  bool loading = false;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    if (widget.generate == null) {
      fields.add(TextEditingController());
    } else {
      generate();
    }
  }

  Future<void> generate() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final titles = await widget.generate!();
      if (titles.isEmpty ||
          titles.any((title) => title.trim().isEmpty || title.length > 120)) {
        throw StateError('AI returned unusable subtasks. Try again.');
      }
      if (!mounted) return;
      setState(() {
        fields.addAll(
          titles.map((title) => TextEditingController(text: title.trim())),
        );
        loading = false;
      });
    } catch (failure) {
      if (mounted) {
        setState(() {
          loading = false;
          error = taskError(
            failure,
            'AI could not draft subtasks. Try again or add them manually.',
          );
        });
      }
    }
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.save(fields.map((field) => field.text.trim()).toList());
      if (mounted) Navigator.pop(context, true);
    } catch (failure) {
      if (mounted) {
        setState(() {
          saving = false;
          error = taskError(
            failure,
            'Could not save subtasks. Your draft is still here. Try again.',
          );
        });
      }
    }
  }

  void move(int from, int to) {
    setState(() => fields.insert(to, fields.removeAt(from)));
  }

  @override
  void dispose() {
    for (final field in [...fields, ...discarded]) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: Text(loading ? 'Drafting subtasks…' : 'Review subtasks'),
      content: SizedBox(
        width: 470,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) const LinearProgressIndicator(),
              if (error case final message?)
                Text(
                  message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (!loading &&
                  fields.isEmpty &&
                  widget.generate != null &&
                  error != null)
                TextButton(onPressed: generate, child: const Text('Retry AI')),
              for (final (index, field) in fields.indexed)
                Column(
                  key: ObjectKey(field),
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextField(
                      controller: field,
                      readOnly: saving,
                      maxLength: 120,
                      decoration: InputDecoration(
                        labelText: 'Subtask ${index + 1}',
                      ),
                    ),
                    Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Move step up',
                          onPressed: saving || index == 0
                              ? null
                              : () => move(index, index - 1),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          tooltip: 'Move step down',
                          onPressed: saving || index == fields.length - 1
                              ? null
                              : () => move(index, index + 1),
                          icon: const Icon(Icons.arrow_downward),
                        ),
                        IconButton(
                          tooltip: 'Remove step',
                          onPressed: saving
                              ? null
                              : () => setState(
                                  () => discarded.add(fields.removeAt(index)),
                                ),
                          icon: const Icon(Icons.clear),
                        ),
                      ],
                    ),
                  ],
                ),
              if (!loading)
                TextButton.icon(
                  onPressed: saving
                      ? null
                      : () => setState(() {
                          if (fields.isEmpty) error = null;
                          fields.add(TextEditingController());
                        }),
                  icon: const Icon(Icons.add),
                  label: const Text('Add a step'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving || loading || fields.isEmpty ? null : save,
          child: Text(saving ? 'Saving…' : 'Save subtasks'),
        ),
      ],
    ),
  );
}

class _NextActionDialog extends StatefulWidget {
  const _NextActionDialog({
    required this.store,
    required this.agent,
    required this.consent,
  });

  final TaskStore store;
  final TaskAgent agent;
  final Future<bool> Function(String) consent;

  @override
  State<_NextActionDialog> createState() => _NextActionDialogState();
}

class _NextActionDialogState extends State<_NextActionDialog> {
  int minutes = 30;
  Energy energy = Energy.medium;
  final dismissed = <String>{};
  String? aiChoice, error;
  bool loading = false;

  List<Task> get candidates => widget.store
      .nextActions(
        minutes: minutes,
        energy: energy,
        today: dayKey(DateTime.now()),
      )
      .where((task) => !dismissed.contains(task.id))
      .toList();

  void resetChoice() {
    aiChoice = null;
    error = null;
    dismissed.clear();
  }

  Future<void> askAi() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (!widget.agent.cloudAiEnabled) {
        throw const ApiFailure(
          'Cloud AI is off. Enable it in Privacy to request an AI proposal.',
          status: 403,
        );
      }
      if (!await widget.consent(
            'Send eligible task titles, estimates, energy and due dates to the AI provider?',
          ) ||
          !mounted) {
        return;
      }
      final options = candidates.take(30).toList();
      if (options.isEmpty) return;
      final (id, _) = await widget.agent.recommend(options, minutes, energy);
      if (!mounted) return;
      if (!options.any((task) => task.id == id) ||
          !candidates.any((task) => task.id == id)) {
        throw StateError('That recommendation is no longer available.');
      }
      setState(() => aiChoice = id);
    } catch (failure) {
      if (mounted) {
        setState(() {
          error = taskError(
            failure,
            'AI could not recommend an action. You can still use the device suggestion.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final options = candidates;
      final selected =
          options.where((task) => task.id == aiChoice).firstOrNull ??
          options.firstOrNull;
      final theme = Theme.of(context);
      final due =
          selected?.due ?? widget.store.get(selected?.parent ?? '')?.due;
      return AlertDialog(
        title: const Text('Find my next action'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: minutes,
                  decoration: const InputDecoration(
                    labelText: 'Minutes available',
                  ),
                  items: [
                    for (final value in [5, 10, 15, 20, 30, 45, 60, 90, 120])
                      DropdownMenuItem(value: value, child: Text('$value')),
                  ],
                  onChanged: loading
                      ? null
                      : (value) => setState(() {
                          minutes = value!;
                          resetChoice();
                        }),
                ),
                DropdownButtonFormField<Energy>(
                  initialValue: energy,
                  decoration: const InputDecoration(
                    labelText: 'Available energy',
                  ),
                  items: [
                    for (final value in Energy.values)
                      DropdownMenuItem(value: value, child: Text(value.name)),
                  ],
                  onChanged: loading
                      ? null
                      : (value) => setState(() {
                          energy = value!;
                          resetChoice();
                        }),
                ),
                const SizedBox(height: 16),
                if (loading) ...[
                  const LinearProgressIndicator(),
                  const Text('Asking AI for a suggestion…'),
                ],
                if (error case final message?)
                  Text(
                    message,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                if (selected == null)
                  Text(
                    dismissed.isEmpty
                        ? 'No ready action fits. Try more time or energy, or complete a prerequisite.'
                        : 'No other actions fit. Change the time or energy to see suggestions again.',
                  )
                else ...[
                  Text(selected.title, style: theme.textTheme.titleMedium),
                  Text(
                    '${selected.minutes} of $minutes minutes · ${selected.energy.name} energy · Prerequisites complete'
                    '${due == null ? '' : ' · Due $due'}',
                  ),
                  if (selected.id == aiChoice)
                    const Text(
                      'AI selected this action from the eligible tasks.',
                    ),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: loading
                            ? null
                            : () => setState(() {
                                dismissed.add(selected.id);
                                aiChoice = null;
                                error = null;
                              }),
                        child: const Text('Dismiss suggestion'),
                      ),
                      TextButton(
                        onPressed: loading ? null : askAi,
                        child: const Text('Ask AI'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: selected == null || loading
                ? null
                : () => Navigator.pop(context, selected),
            child: const Text('Open task'),
          ),
        ],
      );
    },
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
