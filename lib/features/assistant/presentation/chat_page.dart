import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/product_widgets.dart';
import '../models/conversation.dart';
import 'proposal_page.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.id});
  final String id;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _view = GlobalKey<AsyncViewState<Conversation>>(),
      _input = TextEditingController(),
      _scroll = ScrollController();
  bool _sending = false, _cloud = false;
  String? _sendError;
  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _input.text.trim();
    if (message.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      await AppScope.of(context).assistant
          .send(widget.id, message, cloud: _cloud);
      if (!mounted) return;
      _input.clear();
      _view.currentState?.refresh();
    } catch (e) {
      if (mounted) setState(() => _sendError = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _mode() async {
    if (_cloud) {
      setState(() {
        _cloud = false;
        _sendError = null;
      });
      return;
    }
    if (await confirm(
      context,
      title: 'Use cloud AI?',
      message: 'Your message and authorized goal/task context will be sent to the configured AI provider. Approval is still required before product changes. Local mode keeps the conversation on this server.',
      action: 'Use cloud AI',
    )) {
      if (mounted) setState(() => _cloud = true);
    }
  }

  @override
  Widget build(BuildContext context) => ProductPage(
    title: 'Planify assistant',
    subtitle: 'Your work. Your approval.',
    actions: [
      OutlinedButton(
        onPressed: _sending ? null : _mode,
        child: Text(_cloud ? 'Cloud AI' : 'Local assistant'),
      ),
    ],
    child: AsyncView<Conversation>(
      key: _view,
      load: () => AppScope.of(context).assistant.conversation(widget.id),
      builder: (ctx, c, refresh) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
        return Column(
          children: [
            if (c.goalId != null || c.projectId != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: StatusChip(
                    c.goalId != null
                        ? 'Goal context: ${c.title}'
                        : 'Project context: ${c.title}',
                  ),
                ),
              ),
            Expanded(
              child: c.messages.isEmpty
                  ? SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 36),
                          Image.asset(
                            'assets/branding/identity-source/approved-logo.png',
                            width: 230,
                            height: 90,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Make room for a clearer plan.',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Local mode prepares structured outlines and summaries using rules. Cloud mode requires a configured provider.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final s in [
                                'Plan four chapters before Friday, maximum two hours per day',
                                'Summarize my work',
                                'Create task: draft an introduction',
                              ])
                                ActionChip(
                                  label: Text(s),
                                  onPressed: () => _input.text = s,
                                ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        for (final m in c.messages)
                          Align(
                            alignment: m.role == 'user'
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 700),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: m.role == 'user'
                                        ? AppColors.ink
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: m.role == 'user'
                                        ? null
                                        : Border.all(color: AppColors.border),
                                  ),
                                  child: SelectableText(
                                    m.body,
                                    style: TextStyle(
                                      color: m.role == 'user'
                                          ? Colors.white
                                          : AppColors.ink,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        for (final p in c.proposals)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Surface(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 10,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      StatusChip(p.status),
                                      OutlinedButton(
                                        onPressed: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  ProposalPage(id: p.id),
                                            ),
                                          );
                                          refresh();
                                        },
                                        child: const Text('Review actions'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            if (_sending)
              Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      _cloud
                          ? 'Waiting for cloud AI. Free models can take up to a minute.'
                          : 'Preparing your response…',
                    ),
                  ],
                ),
              ),
            if (_sendError != null)
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Surface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _sendError!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              children: [
                                OutlinedButton(
                                  onPressed: _sending ? null : _send,
                                  child: const Text('Retry message'),
                                ),
                                if (_cloud)
                                  TextButton(
                                    onPressed: _sending ? null : _mode,
                                    child: const Text('Use local assistant'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: !_sending,
                      maxLines: 4,
                      minLines: 1,
                      maxLength: 4000,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        hintText: 'What would you like to work on?',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.arrow_upward),
                    constraints: const BoxConstraints(
                      minHeight: 52,
                      minWidth: 52,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                'Check proposals before approving. Estimates and suggested steps remain editable.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ],
        );
      },
    ),
  );
}
