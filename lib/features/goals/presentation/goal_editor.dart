import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/product_widgets.dart';
import '../../collaboration/models/project.dart';
import '../models/goal.dart';

class GoalEditor extends StatefulWidget {
  const GoalEditor({super.key, this.goal, this.projectId});
  final Goal? goal;
  final String? projectId;
  @override
  State<GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<GoalEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _description, _start, _target;
  String? _project;
  bool _dirty = false, _saved = false;
  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.goal?.title);
    _description = TextEditingController(text: widget.goal?.description);
    _start = TextEditingController(text: widget.goal?.startDate);
    _target = TextEditingController(text: widget.goal?.targetDate);
    _project = widget.goal?.projectId ?? widget.projectId;
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _start, _target]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_start.text.isNotEmpty &&
        _target.text.isNotEmpty &&
        _start.text.compareTo(_target.text) > 0) {
      feedback(
        context,
        'Target date must be on or after the start date.',
        error: true,
      );
      return;
    }
    final g = await AppScope.of(context).goals.save({
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'project_id': _project,
      'start_date': _start.text.isEmpty ? null : _start.text,
      'target_date': _target.text.isEmpty ? null : _target.text,
      'status': widget.goal?.status ?? 'active',
    }, id: widget.goal?.id);
    if (mounted) {
      _saved = true;
      feedback(context, '${g.title} saved');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty || _saved,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop) return;
      if (await confirm(
        context,
        title: 'Discard unsaved changes?',
        message: 'Your saved goal will be kept. The edits in this form will be lost.',
        action: 'Discard',
      )) {
        if (context.mounted) {
          setState(() => _saved = true);
          Navigator.pop(context);
        }
      }
    },
    child: ProductPage(
      title: widget.goal == null ? 'New goal' : 'Edit goal',
      subtitle: 'A clear outcome is a good place to start.',
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: _form,
            onChanged: () => setState(() => _dirty = true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _title,
                  validator: Validators.required,
                  maxLength: 160,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Goal title',
                    hintText: 'What do you want to achieve?',
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _description,
                  maxLines: 4,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Describe what a successful outcome looks like.',
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _start,
                  validator: Validators.date,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Start date (optional)',
                    hintText: 'YYYY-MM-DD',
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _target,
                  validator: Validators.date,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Target date (optional)',
                    hintText: 'YYYY-MM-DD',
                  ),
                ),
                const SizedBox(height: 24),
                if (widget.goal == null)
                  AsyncView<List<Project>>(
                    load: () async =>
                        (await AppScope.of(context).collaboration.list()).items
                            .where((p) => p.canWrite)
                            .toList(),
                    builder: (ctx, projects, refresh) =>
                        DropdownButtonFormField<String>(
                          initialValue: _project ?? '',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Visibility / workspace',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Personal — only you'),
                            ),
                            for (final p in projects)
                              DropdownMenuItem(
                                value: p.id,
                                child: Text(
                                  'Shared — ${p.title}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (s) => setState(() {
                            _project = s == '' ? null : s;
                            _dirty = true;
                          }),
                        ),
                  )
                else
                  Text(
                    _project == null
                        ? 'Personal goal'
                        : 'Shared goal · workspace is preserved',
                  ),
                const SizedBox(height: 32),
                BusyButton(label: 'Save goal', onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> editMilestone(
  BuildContext context,
  Goal goal, {
  Milestone? milestone,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (ctx) => MilestoneSheet(goal: goal, milestone: milestone),
);

class MilestoneSheet extends StatefulWidget {
  const MilestoneSheet({super.key, required this.goal, this.milestone});
  final Goal goal;
  final Milestone? milestone;
  @override
  State<MilestoneSheet> createState() => _MilestoneSheetState();
}

class _MilestoneSheetState extends State<MilestoneSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _description, _date;
  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.milestone?.title);
    _description = TextEditingController(text: widget.milestone?.description);
    _date = TextEditingController(text: widget.milestone?.targetDate);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
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
              widget.milestone == null ? 'New milestone' : 'Edit milestone',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _title,
              validator: Validators.required,
              maxLength: 160,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _date,
              validator: Validators.date,
              decoration: const InputDecoration(
                labelText: 'Target date',
                hintText: 'YYYY-MM-DD',
              ),
            ),
            const SizedBox(height: 24),
            BusyButton(
              label: 'Save milestone',
              onPressed: () async {
                if (!_form.currentState!.validate()) return;
                final JsonMap d = {
                  'title': _title.text,
                  'description': _description.text,
                  'target_date': _date.text.isEmpty ? null : _date.text,
                  'completed': widget.milestone?.completed ?? false,
                  if (widget.milestone != null)
                    'position': widget.milestone!.position,
                };
                await AppScope.of(context).goals
                    .saveMilestone(widget.goal.id, d, id: widget.milestone?.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    ),
  );
}
