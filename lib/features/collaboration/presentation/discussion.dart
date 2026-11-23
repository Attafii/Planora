import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/widgets/product_widgets.dart';
import '../../../core/utils/validators.dart';
import '../models/project.dart';

class Discussion extends StatefulWidget {
  const Discussion({super.key, required this.project});
  final Project project;
  @override
  State<Discussion> createState() => _DiscussionState();
}

class _DiscussionState extends State<Discussion> {
  final _list = GlobalKey<PagedViewState<ProjectComment>>();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.project.canWrite)
        BusyButton(
          label: 'Add comment',
          icon: Icons.chat_bubble_outline,
          onPressed: () async {
            await composeComment(context, widget.project);
            _list.currentState?.refresh();
          },
        ),
      const SizedBox(height: 16),
      Expanded(
        child: PagedView<ProjectComment>(
          key: _list,
          load: (offset) =>
              AppScope.of(context).collaboration
                  .comments(widget.project.id, offset: offset),
          emptyTitle: 'Start a useful conversation',
          emptyMessage:
              'Share a decision, ask a question or mention a project member.',
          itemBuilder: (ctx, c) => Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.authorName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      readableDate(c.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (widget.project.canWrite &&
                        (c.authorId == AppScope.of(context).session.user!.id ||
                            widget.project.canManage))
                      PopupMenuButton<String>(
                        tooltip: 'Comment actions',
                        onSelected: (s) async {
                          try {
                            if (s == 'edit') {
                              await composeComment(
                                context,
                                widget.project,
                                comment: c,
                              );
                            } else if (await confirm(
                              context,
                              title: 'Delete comment?',
                              message: 'This comment will be removed from the discussion.',
                              action: 'Delete',
                            )) {
                              if (!context.mounted) return;
                              await AppScope.of(context).collaboration
                                  .deleteComment(widget.project.id, c.id);
                            }
                            _list.currentState?.refresh();
                          } catch (e) {
                            if (context.mounted) {
                              feedback(context, e.toString(), error: true);
                            }
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(c.body),
                if (c.mentions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final m in widget.project.members.where(
                        (m) => c.mentions.contains(m.id),
                      ))
                        StatusChip('@${m.name}'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

Future<void> composeComment(
  BuildContext context,
  Project p, {
  ProjectComment? comment,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (ctx) => _CommentSheet(project: p, comment: comment),
);

class _CommentSheet extends StatefulWidget {
  const _CommentSheet({required this.project, this.comment});
  final Project project;
  final ProjectComment? comment;
  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _body;
  final Set<String> _mentions = {};
  @override
  void initState() {
    super.initState();
    _body = TextEditingController(text: widget.comment?.body);
    _mentions.addAll(widget.comment?.mentions ?? []);
  }

  @override
  void dispose() {
    _body.dispose();
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
              widget.comment == null ? 'Add a comment' : 'Edit comment',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _body,
              validator: Validators.required,
              maxLines: 4,
              maxLength: 4000,
              decoration: const InputDecoration(
                labelText: 'Comment',
                hintText: 'Share something useful for the team.',
              ),
            ),
            if (widget.comment == null) ...[
              const SizedBox(height: 16),
              const Text('Mention members'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in widget.project.members)
                    FilterChip(
                      label: Text(m.name),
                      selected: _mentions.contains(m.id),
                      onSelected: (s) => setState(
                        () => s ? _mentions.add(m.id) : _mentions.remove(m.id),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            BusyButton(
              label: 'Save comment',
              onPressed: () async {
                if (!_form.currentState!.validate()) return;
                final repo = AppScope.of(context).collaboration;
                if (widget.comment == null) {
                  await repo.comment(
                    widget.project.id,
                    _body.text,
                    _mentions.toList(),
                  );
                } else {
                  await repo.editComment(
                    widget.project.id,
                    widget.comment!.id,
                    _body.text,
                  );
                }
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    ),
  );
}
