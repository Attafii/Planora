import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/product_widgets.dart';
import '../models/conversation.dart';

String actionLabel(String kind) =>
    const {
      'create_task': 'Create task',
      'create_goal': 'Create goal',
      'build_goal_plan': 'Create milestones and linked tasks',
      'create_milestones': 'Add milestones',
      'assign_task': 'Assign task',
      'add_comment': 'Add comment',
      'archive_task': 'Archive task',
      'update_task': 'Update task',
      'generate_schedule': 'Generate calendar proposal',
      'replan_schedule': 'Prepare replanning proposal',
    }[kind] ??
    kind.replaceAll('_', ' ');
bool editableAction(String kind) => [
  'create_task',
  'create_goal',
  'build_goal_plan',
  'create_milestones',
  'add_comment',
  'update_task',
].contains(kind);
Future<JsonMap?> editAction(BuildContext context, ProposedAction action) =>
    showModalBottomSheet<JsonMap>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _ActionEditor(action: action),
    );

class _ActionEditor extends StatefulWidget {
  const _ActionEditor({required this.action});
  final ProposedAction action;
  @override
  State<_ActionEditor> createState() => _ActionEditorState();
}

class _ActionEditorState extends State<_ActionEditor> {
  final _form = GlobalKey<FormState>();
  late JsonMap _payload;
  late final TextEditingController _title, _date, _minutes, _body, _titles;
  final List<TextEditingController> _stepTitles = [], _stepMinutes = [];
  final List<bool> _selected = [];
  @override
  void initState() {
    super.initState();
    _payload = jsonDecode(jsonEncode(widget.action.payload)) as JsonMap;
    _title = TextEditingController(text: _payload['title'] as String?);
    _date = TextEditingController(
      text: (_payload['target_date'] ?? _payload['deadline']) as String?,
    );
    _minutes = TextEditingController(
      text: '${_payload['estimated_minutes'] ?? 45}',
    );
    _body = TextEditingController(
      text: (_payload['body'] ?? _payload['description']) as String?,
    );
    _titles = TextEditingController(
      text: (_payload['titles'] as List?)?.join('\n'),
    );
    for (final raw in (_payload['steps'] as List?) ?? []) {
      final s = raw as JsonMap;
      _stepTitles.add(TextEditingController(text: s['title'] as String));
      _stepMinutes.add(
        TextEditingController(text: '${s['estimated_minutes']}'),
      );
      _selected.add(s['selected'] != false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _date,
      _minutes,
      _body,
      _titles,
      ..._stepTitles,
      ..._stepMinutes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final kind = widget.action.kind;
    if ([
      'create_task',
      'create_goal',
      'build_goal_plan',
      'update_task',
    ].contains(kind)) {
      _payload['title'] = _title.text.trim();
      _payload[kind == 'create_goal' || kind == 'build_goal_plan'
          ? 'target_date'
          : 'deadline'] = _date.text.isEmpty
          ? null
          : _date.text;
    }
    if (['create_task', 'update_task'].contains(kind)) {
      _payload['estimated_minutes'] = int.parse(_minutes.text);
    }
    if (kind == 'create_goal') _payload['description'] = _body.text;
    if (kind == 'add_comment') _payload['body'] = _body.text;
    if (kind == 'create_milestones') {
      final titles = _titles.text
          .split('\n')
          .where((s) => s.trim().isNotEmpty)
          .map((s) => s.trim())
          .toList();
      if (titles.isEmpty) {
        feedback(context, 'Enter at least one milestone.', error: true);
        return;
      }
      _payload['titles'] = titles;
    }
    if (kind == 'build_goal_plan') {
      if (!_selected.any((s) => s)) {
        feedback(context, 'Select at least one step.', error: true);
        return;
      }
      _payload['steps'] = [
        for (int i = 0; i < _stepTitles.length; i++)
          {
            'title': _stepTitles[i].text.trim(),
            'estimated_minutes': int.parse(_stepMinutes[i].text),
            'selected': _selected[i],
          },
      ];
    }
    Navigator.pop(context, {
      'kind': kind,
      'reason': widget.action.reason,
      'payload': _payload,
    });
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.action.kind;
    return Padding(
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
                actionLabel(kind),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              if ([
                'create_task',
                'create_goal',
                'build_goal_plan',
                'update_task',
              ].contains(kind)) ...[
                TextFormField(
                  controller: _title,
                  validator: Validators.required,
                  maxLength: 160,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _date,
                  validator: Validators.date,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Target date',
                    hintText: 'YYYY-MM-DD',
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (['create_task', 'update_task'].contains(kind)) ...[
                TextFormField(
                  controller: _minutes,
                  validator: Validators.minutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Estimated minutes',
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (['create_goal', 'add_comment'].contains(kind))
                TextFormField(
                  controller: _body,
                  validator: kind == 'add_comment' ? Validators.required : null,
                  maxLines: 4,
                  maxLength: 4000,
                  decoration: InputDecoration(
                    labelText: kind == 'add_comment'
                        ? 'Comment'
                        : 'Description',
                  ),
                ),
              if (kind == 'create_milestones')
                TextFormField(
                  controller: _titles,
                  validator: Validators.required,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Milestone titles',
                    helperText: 'One title per line',
                  ),
                ),
              if (kind == 'build_goal_plan') ...[
                const Text(
                  'Select the work you want to create. Each selected step adds a milestone and a task.',
                ),
                const SizedBox(height: 16),
                for (int i = 0; i < _stepTitles.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Surface(
                      child: Column(
                        children: [
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Step ${i + 1}'),
                            value: _selected[i],
                            onChanged: (s) =>
                                setState(() => _selected[i] = s ?? false),
                          ),
                          TextFormField(
                            controller: _stepTitles[i],
                            validator: Validators.required,
                            maxLength: 160,
                            decoration: const InputDecoration(
                              labelText: 'Step title',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _stepMinutes[i],
                            validator: Validators.minutes,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Estimated minutes',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              FilledButton(onPressed: _save, child: const Text('Save edits')),
            ],
          ),
        ),
      ),
    );
  }
}
