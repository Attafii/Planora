import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/product_widgets.dart';
import '../../goals/presentation/goal_detail_page.dart';
import '../models/conversation.dart';
import 'action_editor.dart';

class ProposalPage extends StatefulWidget {
  const ProposalPage({super.key, required this.id});
  final String id;
  @override
  State<ProposalPage> createState() => _ProposalPageState();
}

class _ProposalPageState extends State<ProposalPage> {
  final _view = GlobalKey<AsyncViewState<AgentProposal>>();
  final Set<int> _chosen = {};
  int? _revision;
  Future<void> _approve(AgentProposal p) async {
    final repo = AppScope.of(context).assistant;
    if (p.actions.asMap().entries.any(
      (e) => _chosen.contains(e.key) && e.value.risk == 'high',
    )) {
      if (!await confirm(
        context,
        title: 'Approve consequential changes?',
        message: 'This proposal includes assignments or archiving. Check the affected records before continuing.',
        action: 'Approve',
      )) {
        return;
      }
    }
    try {
      var current = p;
      if (_chosen.length != p.actions.length) {
        current = await repo.edit(p, [
          for (final e in p.actions.asMap().entries)
            if (_chosen.contains(e.key)) e.value.toJson(),
        ]);
      }
      await repo.approve(current);
      _view.currentState?.refresh();
      if (mounted) feedback(context, 'Backend confirmed the approved actions.');
    } catch (e) {
      _view.currentState?.refresh();
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => ProductPage(
    title: 'Review proposed actions',
    subtitle: 'Check the details before anything changes.',
    child: AsyncView<AgentProposal>(
      key: _view,
      load: () => AppScope.of(context).assistant.proposal(widget.id),
      builder: (ctx, p, refresh) {
        if (_revision != p.revision) {
          _revision = p.revision;
          _chosen
            ..clear()
            ..addAll(List.generate(p.actions.length, (i) => i));
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Text(p.title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(p.explanation),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                StatusChip(
                  p.status == 'pending' && !p.canApprove ? 'expired' : p.status,
                ),
                StatusChip('Expires ${readableDate(p.expiresAt)}'),
              ],
            ),
            const SizedBox(height: 20),
            for (final e in p.actions.asMap().entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (p.canApprove)
                            Checkbox(
                              value: _chosen.contains(e.key),
                              onChanged: (s) => setState(
                                () => s == true
                                    ? _chosen.add(e.key)
                                    : _chosen.remove(e.key),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              actionLabel(e.value.kind),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          StatusChip('${e.value.risk} risk'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(e.value.reason),
                      const SizedBox(height: 16),
                      _ActionSummary(action: e.value),
                      if (p.canApprove && editableAction(e.value.kind)) ...[
                        const SizedBox(height: 16),
                        BusyButton(
                          label: 'Edit details',
                          outlined: true,
                          icon: Icons.edit_outlined,
                          onPressed: () async {
                            final changed = await editAction(context, e.value);
                            if (changed == null || !context.mounted) return;
                            final actions = p.actions
                                .map((a) => a.toJson())
                                .toList();
                            actions[e.key] = changed;
                            await AppScope.of(context).assistant
                                .edit(p, actions);
                            refresh();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (p.canApprove) ...[
              const SizedBox(height: 8),
              const Text(
                'Approval applies the selected local product changes together. Rejection changes no tasks, goals or project records.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  BusyButton(
                    label: 'Approve selected actions',
                    enabled: _chosen.isNotEmpty,
                    icon: Icons.check,
                    onPressed: () => _approve(p),
                  ),
                  BusyButton(
                    label: 'Reject proposal',
                    outlined: true,
                    onPressed: () async {
                      await AppScope.of(context).assistant.reject(p.id);
                      refresh();
                    },
                  ),
                ],
              ),
            ],
            if (p.status == 'executed') ...[
              const Divider(),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppColors.ink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Actions completed',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final r in p.result ?? <JsonMap>[])
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (r['title'] != null)
                        Text(
                          r['title'] as String,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      if (r['created_tasks'] != null)
                        Text(
                          '${r['created_tasks']} tasks and milestones created',
                        ),
                      if (r['message'] != null) Text(r['message'] as String),
                      if (r['goal_id'] != null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  GoalDetailPage(id: r['goal_id'] as String),
                            ),
                          ),
                          child: const Text('Open goal'),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
            if (p.error != null) ...[
              const Divider(),
              Text(p.error!, style: const TextStyle(color: AppColors.error)),
            ],
            if (!p.canApprove && p.status == 'pending')
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'This proposal expired. Ask the assistant to prepare a fresh version.',
                ),
              ),
            if (p.audit.isNotEmpty) ...[
              const Divider(),
              Text(
                'Action history',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final a in p.audit)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history),
                  title: Text((a['event'] as String).replaceAll('_', ' ')),
                  subtitle: Text(
                    '${a['details']}\n${readableDate(a['created_at'] as String)}',
                  ),
                ),
            ],
          ],
        );
      },
    ),
  );
}

class _ActionSummary extends StatelessWidget {
  const _ActionSummary({required this.action});
  final ProposedAction action;
  @override
  Widget build(BuildContext context) {
    final p = action.payload;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p['title'] != null)
          Text(
            p['title'] as String,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        if (p['deadline'] != null || p['target_date'] != null)
          Text('Target: ${p['deadline'] ?? p['target_date']}'),
        if (p['estimated_minutes'] != null)
          Text('Estimate: ${p['estimated_minutes']} minutes'),
        if (p['max_daily_minutes'] != null)
          Text('Daily planning limit: ${p['max_daily_minutes']} minutes'),
        if (p['body'] != null) Text(p['body'] as String),
        for (final step in (p['steps'] as List?) ?? [])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              (step as JsonMap)['selected'] != false
                  ? Icons.check_circle_outline
                  : Icons.remove_circle_outline,
            ),
            title: Text(step['title'] as String),
            subtitle: Text(
              '${step['estimated_minutes']} minutes · ${step['selected'] != false ? 'Selected' : 'Excluded'}',
            ),
          ),
        for (final heading in (p['titles'] as List?) ?? [])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('• $heading'),
          ),
        if (p['task_id'] != null)
          AsyncView<String>(
            load: () async {
              final services = AppScope.of(context);
              final t = await services.goals.task(p['task_id'] as String);
              if (p['user_id'] != null && t.projectId != null) {
                final project = await services.collaboration.detail(
                  t.projectId!,
                );
                return '${t.title} → ${project.members.firstWhere((m) => m.id == p['user_id']).name}';
              }
              if (action.kind == 'update_task') {
                return '${t.title} → ${p['title'] ?? t.title}\nDeadline: ${readableDate(t.deadline)} → ${readableDate(p.containsKey('deadline') ? p['deadline'] as String? : t.deadline)}\nEstimate: ${t.minutes} → ${p['estimated_minutes'] ?? t.minutes} minutes';
              }
              return '${t.title} · ${t.status}';
            },
            builder: (ctx, label, _) => Text(label),
          ),
        if (p['date'] != null) Text('Calendar date: ${p['date']}'),
      ],
    );
  }
}
