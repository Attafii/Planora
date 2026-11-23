import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/services/app_session.dart';
import '../../core/services/personal_sync.dart';

class SyncIssueDialog extends StatefulWidget {
  const SyncIssueDialog({
    super.key,
    required this.session,
    required this.preview,
    required this.conflict,
  });
  final AppSession session;
  final Map<String, dynamic> preview;
  final bool conflict;
  @override
  State<SyncIssueDialog> createState() => _SyncIssueState();
}

class _SyncIssueState extends State<SyncIssueDialog> {
  bool busy = false;
  String? message, error;
  Future<void> explain() async {
    if (!widget.session.account!.cloudAi) {
      setState(
        () => error = 'Enable Cloud AI in Privacy to request an explanation. Manual recovery remains available.',
      );
      return;
    }
    final consent = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Review AI context'),
        content: Text(
          'OpenRouter will receive only: ${jsonEncode({
            for (final key in ['collection', 'base_revision', 'remote_revision', 'counts']) key: widget.preview[key],
          })}. Record contents, credentials, device names and timestamps are not sent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Send metadata'),
          ),
        ],
      ),
    );
    if (consent != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.session.request(
        'POST',
        '/users/me/sync-assist',
        {
          for (final key in [
            'collection',
            'base_revision',
            'remote_revision',
            'counts',
          ])
            key: widget.preview[key],
          'context_consent': true,
        },
      );
      if (mounted) setState(() => message = result['message'] as String);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(PersonalSync.labels[widget.preview['collection']]!),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This device is based on revision ${widget.preview['base_revision']}; the server preview is revision ${widget.preview['remote_revision']}.',
            ),
            const Text(
              'Device names and edit timestamps are unavailable. Added = only on device; removed = only on server; changed = different values. No automatic merge is available.',
            ),
            Text('Differences: ${widget.preview['counts']}'),
            ExpansionTile(
              title: const Text(
                'Review actual differences (stays on this device)',
              ),
              children: [
                for (final row in widget.preview['details'] as List)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ').convert(row),
                    ),
                  ),
              ],
            ),
            const Text(
              'Choose only after reviewing the preview. A copy of a conflicting version is retained on this device. Confirmation rechecks for changes.',
            ),
            OutlinedButton(
              onPressed: busy ? null : explain,
              child: const Text('Explain this issue with AI'),
            ),
            if (busy) const LinearProgressIndicator(),
            if (message != null) SelectableText(message!),
            if (error != null) Semantics(liveRegion: true, child: Text(error!)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      if (widget.conflict)
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, true),
          child: const Text('Confirm: keep this device'),
        ),
      FilledButton(
        onPressed: busy ? null : () => Navigator.pop(context, false),
        child: const Text('Confirm: use server version'),
      ),
    ],
  );
}

Future<void> showSyncFailureHelp(
  BuildContext context,
  AppSession session,
  bool offline,
) => showDialog<void>(
  context: context,
  builder: (dialog) {
    String text =
        'Your edits remain on this device. Reconnect and use Sync now, then review any conflicts. Server backup cannot be confirmed while disconnected.';
    bool busy = false;
    return StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: const Text('Sync recovery'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [Text(text), if (busy) const LinearProgressIndicator()],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    if (!session.account!.cloudAi) {
                      set(
                        () => text = 'Enable Cloud AI in Privacy for AI help. Manual recovery remains available.',
                      );
                      return;
                    }
                    final consent = await showDialog<bool>(
                      context: c,
                      builder: (p) => AlertDialog(
                        title: const Text(
                          'Send failure category to OpenRouter?',
                        ),
                        content: Text(
                          'Only ${offline ? 'offline' : 'server_error'} is sent. No record contents, credentials or raw errors are shared.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(p, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(p, true),
                            child: const Text('Send category'),
                          ),
                        ],
                      ),
                    );
                    if (consent != true || !c.mounted) return;
                    set(() => busy = true);
                    try {
                      final result = await session.request(
                        'POST',
                        '/users/me/sync-assist',
                        {
                          'issue': offline ? 'offline' : 'server_error',
                          'context_consent': true,
                        },
                      );
                      if (c.mounted) {
                        set(() => text = result['message'] as String);
                      }
                    } catch (e) {
                      if (c.mounted) {
                        set(
                          () => text = 'AI help is unavailable. Reconnect, retry sync and review conflicts. Your local edits are preserved.',
                        );
                      }
                    } finally {
                      if (c.mounted) set(() => busy = false);
                    }
                  },
            child: const Text('Ask AI for recovery guidance'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  },
);
