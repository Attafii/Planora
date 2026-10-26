import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/widgets/product_widgets.dart';
import '../models/conversation.dart';
import 'proposal_page.dart';

class ActionHistoryPage extends StatefulWidget {
  const ActionHistoryPage({super.key});
  @override
  State<ActionHistoryPage> createState() => _ActionHistoryPageState();
}

class _ActionHistoryPageState extends State<ActionHistoryPage> {
  final _list = GlobalKey<PagedViewState<AgentProposal>>();
  String _status = '';
  @override
  Widget build(BuildContext context) => ProductPage(
    title: 'Action history',
    subtitle: 'A clear record of proposals and outcomes.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in {
              '': 'All',
              'pending': 'Pending',
              'executed': 'Completed',
              'rejected': 'Rejected',
              'failed': 'Failed',
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _status == entry.key,
                onSelected: (_) {
                  setState(() => _status = entry.key);
                  _list.currentState?.refresh();
                },
              ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: PagedView<AgentProposal>(
            key: _list,
            load: (offset) =>
                AppScope.of(context).assistant
                    .history(status: _status, offset: offset),
            emptyTitle: 'Nothing to review here',
            emptyMessage: 'Prepared actions and their confirmed outcomes will appear here.',
            itemBuilder: (ctx, p) => Surface(
              padding: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.all(20),
                title: Text(p.title),
                subtitle: Text('${p.actions.length} actions · ${p.status}'),
                leading: const Icon(Icons.history),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ProposalPage(id: p.id),
                    ),
                  );
                  _list.currentState?.refresh();
                },
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
