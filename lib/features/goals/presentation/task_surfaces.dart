import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/write_id.dart';
import '../../../core/widgets/product_widgets.dart';
import '../models/goal.dart';
import '../../tasks/task_store.dart';

Future<TaskItem?> createLinkedTask(BuildContext context, {String? projectId}) =>
    showModalBottomSheet<TaskItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _TaskCreateSheet(projectId: projectId),
    );

class _TaskCreateSheet extends StatefulWidget {
  const _TaskCreateSheet({this.projectId});
  final String? projectId;
  @override
  State<_TaskCreateSheet> createState() => _TaskCreateSheetState();
}

class _TaskCreateSheetState extends State<_TaskCreateSheet> {
  late final _requestId = newWriteId();
  final _form = GlobalKey<FormState>(),
      _title = TextEditingController(),
      _minutes = TextEditingController(text: '45'),
      _date = TextEditingController();
  @override
  void dispose() {
    _title.dispose();
    _minutes.dispose();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add linked work',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'This task belongs to the project. Assigned members can plan it in their calendar.',
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _title,
              validator: Validators.required,
              maxLength: 160,
              decoration: const InputDecoration(labelText: 'Task title'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _minutes,
              validator: Validators.minutes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Estimated minutes'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _date,
              validator: Validators.date,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(
                labelText: 'Deadline (optional)',
                hintText: 'YYYY-MM-DD',
              ),
            ),
            const SizedBox(height: 24),
            BusyButton(
              label: 'Create task',
              onPressed: () async {
                if (!_form.currentState!.validate()) return;
                final task = await AppScope.of(context).goals.createTask({
                  'title': _title.text,
                  'request_id': _requestId,
                  'estimated_minutes': int.parse(_minutes.text),
                  'deadline': _date.text.isEmpty ? null : _date.text,
                  'project_id': widget.projectId,
                });
                if (context.mounted) Navigator.pop(context, task);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> linkTaskPicker(BuildContext context, Goal goal) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _TaskPicker(goal: goal),
    );

class _TaskPicker extends StatefulWidget {
  const _TaskPicker({required this.goal});
  final Goal goal;
  @override
  State<_TaskPicker> createState() => _TaskPickerState();
}

class _TaskPickerState extends State<_TaskPicker> {
  final _list = GlobalKey<PagedViewState<TaskItem>>();
  String _search = '';
  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .85,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Link existing work',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          SearchBox(
            hint: 'Search tasks',
            onSearch: (s) {
              _search = s;
              _list.currentState?.refresh();
            },
          ),
          const SizedBox(height: 16),
          if (widget.goal.projectId == null)
            BusyButton(
              label: 'Sync personal tasks',
              outlined: true,
              onPressed: () async {
                await AppScope.of(context).workActivity?.syncPersonal();
                _list.currentState?.refresh();
              },
            )
          else
            BusyButton(
              label: 'Create linked task',
              outlined: true,
              onPressed: () async {
                final t = await createLinkedTask(
                  context,
                  projectId: widget.goal.projectId,
                );
                if (t != null && context.mounted) {
                  await AppScope.of(context).goals
                      .link(widget.goal.id, t.id, personal: t.personal);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          const SizedBox(height: 20),
          Expanded(
            child: PagedView<TaskItem>(
              key: _list,
              load: (offset) {
                final goals = AppScope.of(context).goals;
                final project = widget.goal.projectId;
                return project == null
                    ? goals.personalTasks(search: _search, offset: offset)
                    : goals.tasks(
                        search: _search,
                        projectId: project,
                        offset: offset,
                      );
              },
              emptyTitle: 'No work to link',
              emptyMessage: widget.goal.projectId == null
                  ? 'Add work in My tasks, then sync it here to link it.'
                  : 'Create a task in this project.',
              itemBuilder: (ctx, t) {
                final allowed = t.projectId == widget.goal.projectId,
                    linked = widget.goal.tasks.any((x) => x.id == t.id);
                return ListTile(
                  title: Text(t.title),
                  subtitle: Text(
                    '${t.minutes} min · ${t.status.replaceAll('_', ' ')}',
                  ),
                  trailing: BusyButton(
                    label: linked
                        ? 'Linked'
                        : allowed
                        ? 'Link'
                        : 'Other workspace',
                    enabled: allowed && !linked,
                    outlined: true,
                    onPressed: () async {
                      await AppScope.of(context).goals
                          .link(widget.goal.id, t.id, personal: t.personal);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class LinkedTaskPage extends StatelessWidget {
  const LinkedTaskPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => ProductPage(
    title: 'Linked task',
    subtitle: 'Shared task record',
    child: AsyncView<TaskItem>(
      revalidateEvery: const Duration(seconds: 15),
      load: () => AppScope.of(context).goals.task(id),
      builder: (ctx, t, refresh) {
        final services = AppScope.of(context);
        final work = services.workActivity;
        final user = services.session.user?.id;
        final canPlan =
            t.projectId != null &&
            t.canEdit &&
            (t.assigneeId ?? t.ownerId) == user &&
            (t.status == 'todo' || t.status == 'in_progress');
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t.description.isEmpty
                        ? 'No description added.'
                        : t.description,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    children: [
                      StatusChip(t.status),
                      StatusChip('${t.minutes} minutes'),
                      StatusChip(readableDate(t.deadline)),
                    ],
                  ),
                  if (t.assigneeName != null) ...[
                    const SizedBox(height: 16),
                    Text('Assigned to ${t.assigneeName}'),
                  ],
                  const Divider(),
                  if (work != null && canPlan)
                    Text('Calendar label: ${sharedTaskLabel(t.id)}'),
                  if (work != null && canPlan)
                    BusyButton(
                      label: 'Plan in my calendar',
                      icon: Icons.calendar_month_outlined,
                      onPressed: work.openCalendar,
                    ),
                  Text(
                    'Update progress',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final s in {
                        'todo': 'To do',
                        'in_progress': 'In progress',
                        'blocked': 'Blocked',
                        'completed': 'Complete',
                      }.entries)
                        BusyButton(
                          label: s.value,
                          outlined: t.status != s.key,
                          enabled: t.canEdit,
                          onPressed: () async {
                            await AppScope.of(context).goals
                                .updateTask(t.id, s.key);
                            refresh();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Calendar slots and focus time belong to your personal workspace.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
