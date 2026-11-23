import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/services/app_session.dart';

Future<void> openAccountSetup(BuildContext context, AppSession session) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => AccountSetupPage(session: session)),
    );

class AccountSetupPage extends StatefulWidget {
  const AccountSetupPage({super.key, required this.session, this.storage});
  final AppSession session;
  final SharedPreferencesAsync? storage;
  @override
  State<AccountSetupPage> createState() => _AccountSetupState();
}

class _AccountSetupState extends State<AccountSetupPage> {
  final needs = TextEditingController(), zone = TextEditingController();
  late final disk = widget.storage ?? SharedPreferencesAsync();
  late final accountId = widget.session.account!.id;
  late final key = 'planify.setup.v1.${widget.session.baseUrl}.$accountId';
  late final baseline = widget.session.account!;
  String language = 'en', theme = 'system';
  int revision = 0;
  bool loading = true, busy = false;
  String? error, reply;
  Map<String, dynamic>? suggestions;
  Future<void> diskWrites = Future.value();
  Map<String, dynamic> get draft => {
    'needs': needs.text,
    'timezone': zone.text,
    'language': language,
    'theme': theme,
  };
  bool get owns => mounted && widget.session.account?.id == accountId;
  @override
  void initState() {
    super.initState();
    zone.text = baseline.timezone;
    language = baseline.language;
    theme = baseline.theme;
    load();
  }

  Future<void> load() async {
    try {
      final local = await disk.getString(key);
      Map<String, dynamic>? data;
      if (local != null) data = jsonDecode(local) as Map<String, dynamic>;
      try {
        final remote = await widget.session.request(
          'GET',
          '/users/me/onboarding',
        );
        if (data == null || data['pending'] != true) data = remote;
      } catch (e) {
        error = 'Connection unavailable. Your draft stays on this device; manual choices remain available.';
      }
      if (!mounted || !owns) return;
      if (data != null) {
        revision = data['revision'] as int;
        final d = data['draft'] as Map;
        needs.text = d['needs'] as String? ?? '';
        zone.text = d['timezone'] as String? ?? baseline.timezone;
        language = d['language'] as String? ?? baseline.language;
        theme = d['theme'] as String? ?? baseline.theme;
      }
    } catch (e) {
      error = e.toString();
    } finally {
      if (owns) setState(() => loading = false);
    }
  }

  void changed() {
    unawaited(stash());
  }

  Future<void> stash() {
    final value = jsonEncode({
      'revision': revision,
      'draft': draft,
      'pending': true,
    });
    final next = diskWrites.then((_) => disk.setString(key, value));
    diskWrites = next.catchError((Object e) {
      if (owns) {
        setState(
          () => error = 'Could not save this draft on the device. Keep this page open and retry.',
        );
      }
    });
    return next;
  }

  Future<void> reviewServerDraft() async {
    await run(() async {
      final remote = await widget.session.request(
        'GET',
        '/users/me/onboarding',
      );
      if (!mounted || !owns) return;
      final accept = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Review server setup'),
          content: Text(
            'Server draft: ${remote['draft']}. Keep your current choices and use this server revision as the baseline for your next confirmed save?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Keep my choices and rebase'),
            ),
          ],
        ),
      );
      if (accept == true && owns) {
        revision = remote['revision'] as int;
        await stash();
      }
    });
  }

  Future<void> saveState(String status) async {
    await stash();
    final saved = await widget.session.request(
      'PATCH',
      '/users/me/onboarding',
      {'revision': revision, 'status': status, 'draft': draft},
    );
    if (!mounted || !owns) return;
    revision = saved['revision'] as int;
    await disk.setString(key, jsonEncode({...saved, 'pending': false}));
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (owns) setState(() => error = e.toString());
    } finally {
      if (owns) setState(() => busy = false);
    }
  }

  Future<void> ask() async {
    if (!widget.session.account!.cloudAi) {
      setState(
        () => error = 'Enable Cloud AI in Privacy to request suggestions. Manual setup works without AI.',
      );
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Send setup context to OpenRouter?'),
        content: const Text(
          'Only your written needs and current timezone, language and appearance will be sent. Do not enter passwords, tokens or sensitive personal details. Suggestions do not save settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Send this context'),
          ),
        ],
      ),
    );
    if (approved != true || !owns) return;
    await run(() async {
      await stash();
      final result = await widget.session.request(
        'POST',
        '/users/me/setup-assist',
        {'needs': needs.text, 'context_consent': true},
      );
      if (owns) {
        setState(() {
          reply = result['message'] as String;
          suggestions = result['suggestions'] as Map<String, dynamic>;
        });
      }
    });
  }

  @override
  void dispose() {
    needs.dispose();
    zone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Set up your everyday')),
    body: SafeArea(
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Choose manually or ask AI for suggestions. You can skip and revisit this from Preferences.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    enabled: !busy,
                    controller: needs,
                    maxLength: 600,
                    maxLines: 3,
                    onChanged: (_) => changed(),
                    decoration: const InputDecoration(
                      labelText: 'What would make planning easier?',
                      hintText: 'For example: French language and a dark appearance. Avoid sensitive information.',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : ask,
                    child: const Text('Ask AI for suggestions'),
                  ),
                  if (reply != null) ...[
                    SelectableText(reply!),
                    Text('Suggested settings: ${suggestions ?? {}}'),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              setState(() {
                                zone.text =
                                    suggestions?['timezone'] as String? ??
                                    zone.text;
                                language =
                                    suggestions?['language'] as String? ??
                                    language;
                                theme =
                                    suggestions?['theme'] as String? ?? theme;
                              });
                              changed();
                            },
                      child: const Text('Review suggested settings below'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    enabled: !busy,
                    controller: zone,
                    onChanged: (_) => changed(),
                    decoration: const InputDecoration(
                      labelText: 'IANA timezone',
                      helperText:
                          'Example: Africa/Tunis. Use your preferred timezone.',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: language,
                    key: ValueKey('lang-$language'),
                    decoration: const InputDecoration(labelText: 'Language'),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'fr', child: Text('Français')),
                    ],
                    onChanged: busy
                        ? null
                        : (v) {
                            setState(() => language = v!);
                            changed();
                          },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: theme,
                    key: ValueKey('theme-$theme'),
                    decoration: const InputDecoration(labelText: 'Appearance'),
                    items: [
                      for (final value in ['system', 'light', 'dark'])
                        DropdownMenuItem(value: value, child: Text(value)),
                    ],
                    onChanged: busy
                        ? null
                        : (v) {
                            setState(() => theme = v!);
                            changed();
                          },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Accessibility, planning and notification preferences are not account settings in this version. Use your device accessibility settings and the existing planning controls.',
                  ),
                  if (error != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (busy) const LinearProgressIndicator(),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            if (!tz.timeZoneDatabase.locations.containsKey(
                              zone.text,
                            )) {
                              throw const ApiFailure(
                                'Choose a valid IANA timezone.',
                              );
                            }
                            await widget.session.savePreferences({
                              'timezone': zone.text,
                              'language': language,
                              'theme': theme,
                              'expected': {
                                'timezone': baseline.timezone,
                                'language': baseline.language,
                                'theme': baseline.theme,
                              },
                            });
                            await saveState('completed');
                            if (context.mounted && owns) {
                              Navigator.pop(context);
                            }
                          }),
                    child: const Text('Confirm and save settings'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            await saveState('draft');
                            if (context.mounted && owns) {
                              Navigator.pop(context);
                            }
                          }),
                    child: const Text('Save draft for later'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            try {
                              await saveState('skipped');
                            } catch (_) {
                              await disk.setString(
                                key,
                                jsonEncode({
                                  'revision': revision,
                                  'status': 'skipped',
                                  'draft': draft,
                                  'pending': true,
                                }),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Setup skipped on this device. Revisit Preferences when connected to save it to your account.',
                                  ),
                                ),
                              );
                            }
                            if (context.mounted && owns) {
                              Navigator.pop(context);
                            }
                          }),
                    child: const Text('Skip setup'),
                  ),
                  if (error != null)
                    TextButton(
                      onPressed: busy ? null : reviewServerDraft,
                      child: const Text('Review server setup conflict'),
                    ),
                ],
              ),
            ),
    ),
  );
}
