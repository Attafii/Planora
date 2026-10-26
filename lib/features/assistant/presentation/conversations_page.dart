import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/widgets/product_widgets.dart';
import '../models/conversation.dart';
import 'chat_page.dart';
import 'history_page.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  final _list = GlobalKey<PagedViewState<Conversation>>();
  String _search = '';
  Future<void> _create() async {
    final c = await AppScope.of(context).assistant.create();
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => ChatPage(id: c.id)),
      );
      _list.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) => ProductPage(
    title: 'Your assistant',
    subtitle: 'Think it through. Review the next step.',
    embedded: widget.embedded,
    actions: [
      OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const ActionHistoryPage()),
        ),
        icon: const Icon(Icons.history),
        label: const Text('Action history'),
      ),
      BusyButton(
        label: 'New conversation',
        icon: Icons.add,
        onPressed: _create,
      ),
    ],
    child: Column(
      children: [
        SearchBox(
          hint: 'Search conversations',
          onSearch: (s) {
            _search = s;
            _list.currentState?.refresh();
          },
        ),
        const SizedBox(height: 24),
        Expanded(
          child: PagedView<Conversation>(
            key: _list,
            load: (offset) =>
                AppScope.of(context).assistant
                    .conversations(search: _search, offset: offset),
            emptyTitle: 'A clearer next step starts here',
            emptyMessage: 'Prepare a revision outline, capture a task or ask about your stored work. Important changes stay yours to approve.',
            emptyAction: BusyButton(
              label: 'Start a conversation',
              onPressed: _create,
            ),
            itemBuilder: (ctx, c) => Surface(
              padding: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 16,
                ),
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(
                  c.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(
                  c.goalId != null
                      ? 'Goal context'
                      : c.projectId != null
                      ? 'Project context'
                      : 'Personal conversation',
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => ChatPage(id: c.id)),
                  );
                  _list.currentState?.refresh();
                },
                trailing: PopupMenuButton<String>(
                  tooltip: 'Conversation actions',
                  onSelected: (s) async {
                    if (await confirm(
                      context,
                      title: 'Delete conversation?',
                      message: 'This removes its messages. Action history and created tasks and goals are preserved.',
                      action: 'Delete',
                    )) {
                      if (!context.mounted) return;
                      try {
                        await AppScope.of(context).assistant
                            .deleteConversation(c.id);
                        _list.currentState?.refresh();
                      } catch (e) {
                        if (context.mounted) {
                          feedback(context, e.toString(), error: true);
                        }
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
