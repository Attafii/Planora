import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/product_widgets.dart';
import '../models/goal.dart';
import 'goal_editor.dart';
import 'goal_detail_page.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  final _list = GlobalKey<PagedViewState<Goal>>();
  String _search = '', _status = 'active', _visibility = '', _sort = '';
  void _update(VoidCallback change) {
    setState(change);
    _list.currentState?.refresh();
  }

  Future<void> _create() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const GoalEditor()));
    _list.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) => ProductPage(
    title: 'Your goals',
    subtitle: 'Give your work a clear direction.',
    embedded: widget.embedded,
    actions: [
      BusyButton(label: 'New goal', icon: Icons.add, onPressed: _create),
    ],
    child: Column(
      children: [
        LayoutBuilder(
          builder: (ctx, c) => Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: c.maxWidth < 480 ? c.maxWidth : 340,
                child: SearchBox(
                  hint: 'Search goals',
                  onSearch: (s) => _update(() => _search = s),
                ),
              ),
              DropdownMenu<String>(
                initialSelection: _status,
                label: const Text('Status'),
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: '', label: 'All goals'),
                  DropdownMenuEntry(value: 'active', label: 'Active'),
                  DropdownMenuEntry(value: 'completed', label: 'Completed'),
                  DropdownMenuEntry(value: 'archived', label: 'Archived'),
                ],
                onSelected: (s) => _update(() => _status = s ?? ''),
              ),
              IconButton(
                tooltip:
                    'Sort by ${_sort == 'title' ? 'recent changes' : 'title'}',
                onPressed: () =>
                    _update(() => _sort = _sort == 'title' ? '' : 'title'),
                icon: const Icon(Icons.sort),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            children: [
              for (final option in {
                '': 'All',
                'personal': 'Personal',
                'shared': 'Shared',
              }.entries)
                ChoiceChip(
                  label: Text(option.value),
                  selected: _visibility == option.key,
                  onSelected: (_) => _update(() => _visibility = option.key),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: PagedView<Goal>(
            key: _list,
            load: (offset) => AppScope.of(context).goals.list(
              search: _search,
              status: _status,
              visibility: _visibility,
              sort: _sort,
              offset: offset,
            ),
            emptyTitle: _search.isEmpty
                ? 'Make space for an outcome'
                : 'No matching goals',
            emptyMessage: _search.isEmpty
                ? 'Start with something meaningful. Add milestones as the path becomes clearer.'
                : 'Try another search or filter.',
            emptyAction: _search.isEmpty
                ? BusyButton(
                    label: 'Create your first goal',
                    onPressed: _create,
                  )
                : null,
            itemBuilder: (ctx, g) => Surface(
              padding: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => GoalDetailPage(id: g.id),
                    ),
                  );
                  _list.currentState?.refresh();
                },
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              g.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
                      if (g.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          g.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatusChip(g.status),
                          StatusChip(
                            g.projectId == null ? 'Personal' : 'Shared',
                          ),
                          Chip(
                            avatar: const Icon(Icons.event_outlined, size: 16),
                            label: Text(readableDate(g.targetDate)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ProgressMeter(g.progress),
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
