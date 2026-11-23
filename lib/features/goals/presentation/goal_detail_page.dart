import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/widgets/product_widgets.dart';
import '../../assistant/presentation/proposal_page.dart';
import '../../assistant/presentation/chat_page.dart';
import '../../collaboration/presentation/project_workspace.dart';
import '../models/goal.dart';
import 'goal_editor.dart';
import 'task_surfaces.dart';
import 'work_progress.dart';
import '../../tasks/task_store.dart';

class GoalDetailPage extends StatelessWidget {
  const GoalDetailPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => ProductPage(
    title: 'Goal details',
    child: AsyncView<Goal>(
      revalidateEvery: const Duration(seconds: 15),
      load: () => AppScope.of(context).goals.detail(id),
      builder: (ctx, g, refresh) => SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(g.title, style: Theme.of(context).textTheme.headlineLarge),
            if (g.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(g.description),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusChip(g.status),
                StatusChip(readableDate(g.targetDate)),
                if (g.projectId != null)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ProjectWorkspace(id: g.projectId!),
                      ),
                    ),
                    icon: const Icon(Icons.people_outline),
                    label: const Text('Shared project'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            WorkProgress(
              percent: g.progress,
              checkedAt: g.checkedAt,
              taskIds: {
                for (final task in g.tasks)
                  if (task.personal)
                    task.id
                  else if (task.projectId != null)
                    sharedTaskKey(task.id),
              },
              summary: switch (g.progressSource) {
                'tasks' =>
                  '${g.completedCount} of ${g.itemCount} linked tasks completed.',
                'milestones' =>
                  '${g.completedCount} of ${g.itemCount} milestones confirmed.',
                'unavailable' =>
                  'Progress unavailable until personal tasks sync.',
                _ => 'No linked activity to measure yet.',
              },
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                BusyButton(
                  label: 'Refresh activity',
                  outlined: true,
                  onPressed: () async {
                    if (g.projectId == null) {
                      await AppScope.of(context).workActivity?.syncPersonal();
                    }
                    refresh();
                  },
                ),
                if (g.canEdit) ...[
                  BusyButton(
                    label: 'Edit goal',
                    outlined: true,
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => GoalEditor(goal: g),
                        ),
                      );
                      refresh();
                    },
                  ),
                  BusyButton(
                    label: 'Break down with assistant',
                    icon: Icons.auto_awesome_outlined,
                    onPressed: () async {
                      final p = await AppScope.of(context).assistant
                          .decompose(g.id);
                      if (context.mounted) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ProposalPage(id: p.id),
                          ),
                        );
                        refresh();
                      }
                    },
                  ),
                ],
                BusyButton(
                  label: 'Ask about this goal',
                  outlined: true,
                  onPressed: () async {
                    final c = await AppScope.of(context).assistant.create(
                      goalId: g.id,
                      projectId: g.projectId,
                      title: g.title,
                    );
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
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Milestones',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (g.canEdit)
                  IconButton(
                    tooltip: 'Add milestone',
                    icon: const Icon(Icons.add),
                    onPressed: () async {
                      await editMilestone(context, g);
                      refresh();
                    },
                  ),
              ],
            ),
            if (g.milestones.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('A first milestone makes the path clearer.'),
              ),
            for (final m in g.milestones)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Surface(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: m.completed,
                            onChanged: !g.canEdit
                                ? null
                                : (checked) async {
                                    try {
                                      await AppScope.of(context).goals
                                          .saveMilestone(
                                            g.id,
                                            m.toForm(done: checked),
                                            id: m.id,
                                          );
                                      refresh();
                                    } catch (e) {
                                      if (context.mounted) {
                                        feedback(
                                          context,
                                          e.toString(),
                                          error: true,
                                        );
                                      }
                                    }
                                  },
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                if (m.description.isNotEmpty)
                                  Text(m.description),
                                Text(
                                  readableDate(m.targetDate),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (g.canEdit)
                            PopupMenuButton<String>(
                              tooltip: 'Milestone actions',
                              onSelected: (s) async {
                                try {
                                  if (s == 'edit') {
                                    await editMilestone(
                                      context,
                                      g,
                                      milestone: m,
                                    );
                                  } else if (s == 'delete') {
                                    if (!await confirm(
                                      context,
                                      title: 'Delete milestone?',
                                      message: 'Linked tasks will be preserved. This milestone will be removed.',
                                      action: 'Delete',
                                    )) {
                                      return;
                                    }
                                    if (!context.mounted) return;
                                    await AppScope.of(context).goals
                                        .deleteMilestone(g.id, m.id);
                                  } else {
                                    final index = g.milestones.indexOf(m),
                                        other = index + (s == 'up' ? -1 : 1);
                                    if (other < 0 ||
                                        other >= g.milestones.length) {
                                      return;
                                    }
                                    final ids = g.milestones
                                        .map((item) => item.id)
                                        .toList();
                                    final moved = ids.removeAt(index);
                                    ids.insert(other, moved);
                                    await AppScope.of(context).goals
                                        .reorderMilestones(g.id, ids);
                                  }
                                  refresh();
                                } catch (e) {
                                  if (context.mounted) {
                                    feedback(
                                      context,
                                      e.toString(),
                                      error: true,
                                    );
                                  }
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'up',
                                  child: Text('Move up'),
                                ),
                                PopupMenuItem(
                                  value: 'down',
                                  child: Text('Move down'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Linked work',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (g.canEdit)
                  IconButton(
                    tooltip: 'Link a task',
                    onPressed: () async {
                      await linkTaskPicker(context, g);
                      refresh();
                    },
                    icon: const Icon(Icons.add_link),
                  ),
              ],
            ),
            if (g.tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Link existing tasks or add work for this outcome.',
                ),
              ),
            for (final missing in g.missingTasks)
              ListTile(
                title: const Text('Linked task unavailable'),
                subtitle: Text(
                  g.progressSource == 'unavailable'
                      ? 'Sync personal tasks to restore this link.'
                      : 'This task was deleted, skipped, or is no longer available.',
                ),
                trailing: g.canEdit
                    ? BusyButton(
                        label: 'Unlink',
                        outlined: true,
                        onPressed: () async {
                          await AppScope.of(context).goals
                              .unlink(g.id, missing, personal: true);
                          refresh();
                        },
                      )
                    : null,
              ),
            for (final t in g.tasks)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                leading: Icon(
                  t.status == 'completed'
                      ? Icons.check_circle_outline
                      : Icons.radio_button_unchecked,
                ),
                title: Text(t.title),
                subtitle: Text(
                  '${t.minutes} min · ${t.status.replaceAll('_', ' ')}',
                ),
                onTap: () async {
                  if (t.personal) {
                    final work = AppScope.of(context).workActivity;
                    if (work?.tasks.get(t.id) == null) {
                      feedback(
                        context,
                        'This task is unavailable on this device. Sync from Today and try again.',
                        error: true,
                      );
                      return;
                    }
                    await work!.openTask(t.id);
                    if (!context.mounted) return;
                    try {
                      await work.syncPersonal();
                    } catch (error) {
                      if (context.mounted) {
                        feedback(context, error.toString(), error: true);
                      }
                      return;
                    }
                  } else {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => LinkedTaskPage(id: t.id),
                      ),
                    );
                  }
                  refresh();
                },
                trailing: g.canEdit
                    ? IconButton(
                        tooltip: 'Unlink task',
                        icon: const Icon(Icons.link_off),
                        onPressed: () async {
                          if (await confirm(
                            context,
                            title: 'Unlink task?',
                            message: 'The task will remain available in its workspace.',
                            action: 'Unlink',
                          )) {
                            if (!context.mounted) return;
                            try {
                              await AppScope.of(context).goals
                                  .unlink(g.id, t.id, personal: t.personal);
                              refresh();
                            } catch (e) {
                              if (context.mounted) {
                                feedback(context, e.toString(), error: true);
                              }
                            }
                          }
                        },
                      )
                    : null,
              ),
            if (g.canEdit) ...[
              const Divider(),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (g.status == 'active' || g.status == 'paused')
                    BusyButton(
                      label: 'Complete goal',
                      enabled:
                          g.progressSource != 'unavailable' &&
                          g.itemCount == g.completedCount,
                      onPressed: () async {
                        await AppScope.of(context).goals
                            .save(g.toForm(newStatus: 'completed'), id: g.id);
                        refresh();
                        if (context.mounted) {
                          feedback(
                            context,
                            'Goal completed. Your achievement progress is updated.',
                          );
                        }
                      },
                    ),
                  if (g.status == 'active' || g.status == 'paused')
                    BusyButton(
                      label: g.status == 'paused'
                          ? 'Resume goal'
                          : 'Pause goal',
                      outlined: true,
                      onPressed: () async {
                        await AppScope.of(context).goals.save(
                          g.toForm(
                            newStatus: g.status == 'paused'
                                ? 'active'
                                : 'paused',
                          ),
                          id: g.id,
                        );
                        refresh();
                      },
                    ),
                  BusyButton(
                    label: g.status == 'archived'
                        ? 'Restore goal'
                        : 'Archive goal',
                    outlined: true,
                    onPressed: () async {
                      await AppScope.of(context).goals.save(
                        g.toForm(
                          newStatus: g.status == 'archived'
                              ? 'active'
                              : 'archived',
                        ),
                        id: g.id,
                      );
                      refresh();
                    },
                  ),
                  BusyButton(
                    label: 'Delete goal',
                    outlined: true,
                    onPressed: () async {
                      if (!await confirm(
                        context,
                        title: 'Delete ${g.title}?',
                        message: 'This removes the goal and milestones. Linked task records remain.',
                        action: 'Delete',
                      )) {
                        return;
                      }
                      if (!context.mounted) return;
                      await AppScope.of(context).goals.delete(g.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
