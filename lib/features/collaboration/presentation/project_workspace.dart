import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/widgets/product_widgets.dart';
import '../models/project.dart';
import '../../goals/presentation/goal_editor.dart';
import '../../goals/presentation/goal_detail_page.dart';
import '../../goals/presentation/task_surfaces.dart';
import '../../assistant/presentation/chat_page.dart';
import 'project_editor.dart';
import 'members_invitations.dart';
import 'discussion.dart';

class ProjectWorkspace extends StatelessWidget {
  const ProjectWorkspace({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => ProductPage(
    title: 'Project workspace',
    child: AsyncView<Project>(
      load: () => AppScope.of(context).collaboration.detail(id),
      builder: (ctx, p, refresh) => DefaultTabController(
        length: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.title, style: Theme.of(context).textTheme.headlineMedium),
            if (p.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(p.description),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                StatusChip(p.role),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => MembersPage(id: p.id),
                      ),
                    );
                    refresh();
                  },
                  icon: const Icon(Icons.people_outline),
                  label: Text('${p.members.length} members'),
                ),
                if (p.canManage)
                  OutlinedButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => InvitationsPage(id: p.id),
                        ),
                      );
                      refresh();
                    },
                    child: const Text('Invitations'),
                  ),
                if (p.canManage)
                  OutlinedButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ProjectEditor(project: p),
                        ),
                      );
                      refresh();
                    },
                    child: const Text('Edit project'),
                  ),
                BusyButton(
                  label: 'Ask assistant',
                  outlined: true,
                  onPressed: () async {
                    final c = await AppScope.of(context).assistant
                        .create(projectId: p.id, title: p.title);
                    if (context.mounted) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ChatPage(id: c.id),
                        ),
                      );
                      refresh();
                    }
                  },
                ),
                if (p.role == 'owner')
                  BusyButton(
                    label: 'Delete project',
                    outlined: true,
                    onPressed: () async {
                      if (!await confirm(
                        context,
                        title: 'Delete ${p.title}?',
                        message: 'This removes the shared project, its goals, tasks, memberships and discussions for everyone.',
                        action: 'Delete',
                      )) {
                        return;
                      }
                      if (!context.mounted) return;
                      await AppScope.of(context).collaboration.delete(p.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                  )
                else
                  BusyButton(
                    label: 'Leave project',
                    outlined: true,
                    onPressed: () async {
                      if (!await confirm(
                        context,
                        title: 'Leave this project?',
                        message: 'You will lose access. Your comments remain in the project.',
                        action: 'Leave',
                      )) {
                        return;
                      }
                      if (!context.mounted) return;
                      await AppScope.of(context).collaboration.leave(p.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Overview'),
                Tab(text: 'Tasks'),
                Tab(text: 'Discussion'),
                Tab(text: 'Activity'),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TabBarView(
                children: [
                  _Overview(project: p, refresh: refresh),
                  _ProjectTasks(project: p, refresh: refresh),
                  Discussion(project: p),
                  PagedView<ActivityEntry>(
                    load: (offset) =>
                        AppScope.of(context).collaboration
                            .activity(p.id, offset: offset),
                    emptyTitle: 'A fresh start',
                    emptyMessage: 'Important project changes will appear here.',
                    itemBuilder: (ctx, a) => ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(a.message),
                      subtitle: Text(
                        '${a.actorName} · ${readableDate(a.createdAt)}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.project, required this.refresh});
  final Project project;
  final VoidCallback refresh;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(bottom: 32),
    children: [
      Surface(
        child: ProgressMeter(project.progress, label: 'Project work completed'),
      ),
      const SizedBox(height: 28),
      Row(
        children: [
          Expanded(
            child: Text(
              'Shared goals',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (project.canWrite)
            IconButton(
              tooltip: 'Add shared goal',
              icon: const Icon(Icons.add),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => GoalEditor(projectId: project.id),
                  ),
                );
                refresh();
              },
            ),
        ],
      ),
      if (project.goals.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text('Add a shared goal to give this project direction.'),
        ),
      for (final g in project.goals)
        ListTile(
          title: Text(g['title'] as String),
          subtitle: Text(g['status'] as String),
          trailing: const Icon(Icons.arrow_forward),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => GoalDetailPage(id: g['id'] as String),
              ),
            );
            refresh();
          },
        ),
      const Divider(),
      Text('Team progress', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      for (final m in project.members)
        ListTile(
          leading: CircleAvatar(
            child: Text(m.name.substring(0, 1).toUpperCase()),
          ),
          title: Text(m.name),
          subtitle: Text(m.role),
          trailing: Text(
            '${project.tasks.where((t) => t.assigneeId == m.id && t.status == 'completed').length} / ${project.tasks.where((t) => t.assigneeId == m.id).length} tasks',
          ),
        ),
      const SizedBox(height: 12),
      const Text(
        'Completed / assigned work. Progress measures outcomes, not hours or rankings.',
      ),
    ],
  );
}

class _ProjectTasks extends StatelessWidget {
  const _ProjectTasks({required this.project, required this.refresh});
  final Project project;
  final VoidCallback refresh;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(bottom: 32),
    children: [
      if (project.canWrite)
        Align(
          alignment: Alignment.centerLeft,
          child: BusyButton(
            label: 'Add task',
            icon: Icons.add,
            onPressed: () async {
              await createLinkedTask(context, projectId: project.id);
              refresh();
            },
          ),
        ),
      const SizedBox(height: 16),
      if (project.tasks.isEmpty)
        const StateMessage(
          title: 'No shared tasks yet',
          message:
              'Add work to the project, then assign it to the right person.',
        ),
      for (final t in project.tasks)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.title),
                  subtitle: Text(
                    '${t.minutes} min · ${t.status.replaceAll('_', ' ')}',
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => LinkedTaskPage(id: t.id),
                      ),
                    );
                    refresh();
                  },
                  trailing: const Icon(Icons.arrow_forward),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      t.assigneeName == null
                          ? 'Unassigned'
                          : 'Assigned to ${t.assigneeName}',
                    ),
                    if (project.canManage)
                      OutlinedButton(
                        onPressed: () async {
                          await assignmentPicker(
                            context,
                            project,
                            t.id,
                            t.assigneeId,
                          );
                          refresh();
                        },
                        child: const Text('Assign'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

Future<void> assignmentPicker(
  BuildContext context,
  Project p,
  String taskId,
  String? memberId,
) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (ctx) =>
      _AssignmentSheet(project: p, taskId: taskId, memberId: memberId),
);

class _AssignmentSheet extends StatefulWidget {
  const _AssignmentSheet({
    required this.project,
    required this.taskId,
    this.memberId,
  });
  final Project project;
  final String taskId;
  final String? memberId;
  @override
  State<_AssignmentSheet> createState() => _AssignmentSheetState();
}

class _AssignmentSheetState extends State<_AssignmentSheet> {
  late String _member;
  @override
  void initState() {
    super.initState();
    _member = widget.memberId ?? '';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Assign work', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: _member,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Assignee'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Unassigned')),
            for (final m in widget.project.members.where(
              (m) => m.role != 'viewer',
            ))
              DropdownMenuItem(value: m.id, child: Text(m.name)),
          ],
          onChanged: (s) => setState(() => _member = s ?? ''),
        ),
        const SizedBox(height: 24),
        BusyButton(
          label: 'Save assignment',
          onPressed: () async {
            await AppScope.of(context).collaboration.assign(
              widget.project.id,
              widget.taskId,
              _member.isEmpty ? null : _member,
            );
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    ),
  );
}
