import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/product_widgets.dart';
import '../models/project.dart';
import 'project_editor.dart';
import 'project_workspace.dart';
import 'members_invitations.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  final _list = GlobalKey<PagedViewState<Project>>();
  String _search = '', _sort = '';
  Future<void> _create() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const ProjectEditor()),
    );
    _list.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) => ProductPage(
    title: 'Shared projects',
    subtitle: 'Move work forward, together.',
    embedded: widget.embedded,
    actions: [
      OutlinedButton.icon(
        onPressed: () => openInvitation(context),
        icon: const Icon(Icons.mail_outline),
        label: const Text('Open invitation'),
      ),
      BusyButton(label: 'New project', icon: Icons.add, onPressed: _create),
    ],
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SearchBox(
                hint: 'Search projects',
                onSearch: (s) {
                  _search = s;
                  _list.currentState?.refresh();
                },
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Change sort order',
              onPressed: () {
                _sort = _sort == 'title' ? '' : 'title';
                _list.currentState?.refresh();
              },
              icon: const Icon(Icons.sort),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: PagedView<Project>(
            key: _list,
            load: (offset) =>
                AppScope.of(context).collaboration
                    .list(search: _search, sort: _sort, offset: offset),
            emptyTitle: _search.isEmpty
                ? 'A space for shared work'
                : 'No matching projects',
            emptyMessage: _search.isEmpty
                ? 'Create a project or open an invitation from someone you work with.'
                : 'Try another title.',
            emptyAction: BusyButton(
              label: 'Create a project',
              onPressed: _create,
            ),
            itemBuilder: (ctx, p) => Surface(
              padding: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ProjectWorkspace(id: p.id),
                    ),
                  );
                  _list.currentState?.refresh();
                },
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.tint,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.people_outline),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (p.description.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                p.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.muted),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                StatusChip(p.role),
                                StatusChip('${p.memberCount} members'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
