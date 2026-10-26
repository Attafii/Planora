import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/services/app_session.dart';
import 'account_screens.dart';
import 'export_delivery_stub.dart'
    if (dart.library.html) 'export_delivery_web.dart'
    as delivery;

void openAccountPanel(BuildContext context, String title, Widget child) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        appBar: AppBar(title: Text(title), centerTitle: false),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 600 ? 20 : 40,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Entrance(child: child),
            ),
          ),
        ),
      ),
    ),
  );
}

String accountDate(BuildContext context, dynamic value) {
  final date = value is String ? DateTime.tryParse(value) : null;
  return date == null
      ? tr(context, 'Not recorded', 'Non enregistré')
      : DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
            .add_Hm()
            .format(date.toLocal());
}

class AccountSection extends StatelessWidget {
  final IconData icon;
  final String title, description;
  final Widget child;
  const AccountSection({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 7),
                    Text(
                      description,
                      style: TextStyle(
                        height: 1.6,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    ),
  );
}

class AccountBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  const AccountBadge({super.key, required this.label, this.icon});
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: ExcludeSemantics(
      child: Chip(
        avatar: icon == null ? null : Icon(icon, size: 18),
        label: Text(label),
      ),
    ),
  );
}

typedef AccountBuilder = Widget Function(
  Map<String, dynamic> data,
  VoidCallback refresh,
);

class AccountResource extends StatefulWidget {
  final AppSession session;
  final String path;
  final AccountBuilder builder;
  const AccountResource({
    super.key,
    required this.session,
    required this.path,
    required this.builder,
  });
  @override
  State<AccountResource> createState() => _AccountResourceState();
}

class _AccountResourceState extends State<AccountResource> {
  late Future<Map<String, dynamic>> future = widget.session.request(
    'GET',
    widget.path,
  );
  void refresh() {
    if (mounted) {
      setState(() {
        future = widget.session.request('GET', widget.path);
      });
    }
  }

  @override
  void didUpdateWidget(covariant AccountResource oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) refresh();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return Semantics(
          label: tr(
            context,
            'Loading account information',
            'Chargement du compte',
          ),
          child: Column(
            children: List.generate(
              3,
              (i) => Container(
                height: 18,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        );
      }
      if (snapshot.hasError) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Notice(text: snapshot.error.toString(), isError: true),
            TextButton.icon(
              onPressed: refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(tr(context, 'Try again', 'Réessayer')),
            ),
          ],
        );
      }
      return widget.builder(snapshot.data ?? {}, refresh);
    },
  );
}

class AccountAction extends StatefulWidget {
  final String label, success;
  final IconData icon;
  final Future<void> Function() action;
  final bool destructive;
  const AccountAction({
    super.key,
    required this.label,
    required this.action,
    this.success = '',
    this.icon = Icons.arrow_forward_rounded,
    this.destructive = false,
  });
  @override
  State<AccountAction> createState() => _AccountActionState();
}

class _AccountActionState extends State<AccountAction> {
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: widget.destructive
              ? Theme.of(context).colorScheme.error
              : null,
        ),
        onPressed: busy
            ? null
            : () async {
                setState(() {
                  busy = true;
                  error = null;
                });
                try {
                  await widget.action();
                  if (context.mounted && widget.success.isNotEmpty) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(widget.success)));
                  }
                } catch (e) {
                  if (mounted) setState(() => error = e.toString());
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              },
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(widget.icon, size: 19),
        label: Text(
          busy ? tr(context, 'Working…', 'En cours…') : widget.label,
          textAlign: TextAlign.center,
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Notice(text: error!, isError: true),
        ),
    ],
  );
}

Future<bool> confirmAccountAction(
  BuildContext context, {
  required String title,
  required String message,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'Cancel', 'Annuler')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'Confirm', 'Confirmer')),
          ),
        ],
      ),
    ) ??
    false;

Future<bool> reauthenticate(
  BuildContext context,
  AppSession session, {
  bool deletion = false,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) =>
            _ReauthenticationDialog(session: session, deletion: deletion),
      ) ??
      false;
}

class _ReauthenticationDialog extends StatefulWidget {
  final AppSession session;
  final bool deletion;
  const _ReauthenticationDialog({
    required this.session,
    required this.deletion,
  });
  @override
  State<_ReauthenticationDialog> createState() =>
      _ReauthenticationDialogState();
}

class _ReauthenticationDialogState extends State<_ReauthenticationDialog> {
  final password = TextEditingController(),
      confirmation = TextEditingController();
  bool busy = false, hidden = true;
  String? error;
  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (password.text.isEmpty ||
        (widget.deletion && confirmation.text != 'DELETE')) {
      setState(
        () => error = tr(
          context,
          'Enter your password and the requested confirmation.',
          'Saisissez votre mot de passe et la confirmation demandée.',
        ),
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.session.request('POST', '/users/me/reauthenticate', {
        'password': password.text,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(tr(context, 'Confirm it’s you', 'Confirmez votre identité')),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(
                  context,
                  'Your password confirms this sensitive account action. It is never included in an export or AI context.',
                  'Votre mot de passe confirme cette action sensible. Il est exclu des exports et du contexte IA.',
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: password,
                autofocus: true,
                obscureText: hidden,
                onSubmitted: (_) {
                  if (!busy && !widget.deletion) submit();
                },
                decoration: InputDecoration(
                  labelText: tr(context, 'Password', 'Mot de passe'),
                  suffixIcon: IconButton(
                    tooltip: tr(
                      context,
                      'Show or hide password',
                      'Afficher ou masquer le mot de passe',
                    ),
                    onPressed: () => setState(() => hidden = !hidden),
                    icon: Icon(
                      hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              if (widget.deletion) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: confirmation,
                  decoration: InputDecoration(
                    labelText: tr(
                      context,
                      'Type DELETE to confirm',
                      'Saisissez DELETE pour confirmer',
                    ),
                  ),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 16),
                Notice(text: error!, isError: true),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: Text(tr(context, 'Cancel', 'Annuler')),
        ),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(
            busy
                ? tr(context, 'Checking…', 'Vérification…')
                : tr(context, 'Continue', 'Continuer'),
          ),
        ),
      ],
    ),
  );
}

class ProfileQualityCard extends StatelessWidget {
  final AppSession session;
  final VoidCallback onPreferences;
  const ProfileQualityCard({
    super.key,
    required this.session,
    required this.onPreferences,
  });
  @override
  Widget build(BuildContext context) => AccountSection(
    icon: Icons.fact_check_outlined,
    title: tr(
      context,
      'A profile that fits your day',
      'Un profil adapté à votre journée',
    ),
    description: tr(
      context,
      'A quick check of the settings behind your personal insights.',
      'Vérifiez les réglages de vos statistiques personnelles.',
    ),
    child: AccountResource(
      key: ValueKey(session.account),
      session: session,
      path: '/users/me/profile-quality',
      builder: (data, refresh) {
        final checks = (data['checks'] as List?) ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: checks.map((raw) {
                final check = raw as Map;
                final ready = check['status'] == 'ready';
                final label = switch (check['field']) {
                  'timezone' => tr(context, 'Timezone', 'Fuseau horaire'),
                  'language' => tr(context, 'Language', 'Langue'),
                  'theme' => tr(context, 'Appearance', 'Apparence'),
                  _ => tr(context, 'Name', 'Nom'),
                };
                final status = switch (check['status']) {
                  'ready' => tr(context, 'Ready', 'Prêt'),
                  'review' => tr(
                    context,
                    'Review default',
                    'Vérifier la valeur par défaut',
                  ),
                  'missing' => tr(context, 'Missing', 'Manquant'),
                  _ => tr(context, 'Unsupported', 'Non pris en charge'),
                };
                return AccountBadge(
                  icon: ready
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  label: '$label · $status',
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                context,
                'Calendar days and weeks in insights follow your saved timezone. An incorrect setting can move activity into a different day.',
                'Les jours et semaines suivent votre fuseau horaire enregistré. Un réglage incorrect peut déplacer une activité vers un autre jour.',
              ),
              style: const TextStyle(height: 1.6),
            ),
            if (data['ready'] != true)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onPreferences,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: Text(
                    tr(
                      context,
                      'Review preferences',
                      'Vérifier les préférences',
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

String noticeText(BuildContext context, String type) => switch (type) {
  'new_session' => tr(
    context,
    'A new sign-in started a session.',
    'Une connexion a ouvert une session.',
  ),
  'session_revoked' => tr(
    context,
    'A session was signed out.',
    'Une session a été déconnectée.',
  ),
  'other_sessions_revoked' => tr(
    context,
    'All other sessions were signed out.',
    'Toutes les autres sessions ont été déconnectées.',
  ),
  'profile_updated' => tr(
    context,
    'Your profile was updated.',
    'Votre profil a été modifié.',
  ),
  'preferences_updated' => tr(
    context,
    'Your preferences were updated.',
    'Vos préférences ont été modifiées.',
  ),
  'privacy_updated' => tr(
    context,
    'Your Cloud AI preference changed.',
    'Votre préférence IA cloud a changé.',
  ),
  'insights_consent_enabled' => tr(
    context,
    'Personal insights AI consent was enabled.',
    'Le consentement IA des statistiques a été activé.',
  ),
  'insights_consent_withdrawn' => tr(
    context,
    'Personal insights AI consent was withdrawn.',
    'Le consentement IA des statistiques a été retiré.',
  ),
  'export_created' => tr(
    context,
    'An account export was created.',
    'Un export du compte a été créé.',
  ),
  'deletion_scheduled' => tr(
    context,
    'Account deletion was scheduled.',
    'La suppression du compte a été programmée.',
  ),
  'deletion_cancelled' => tr(
    context,
    'Account deletion was cancelled.',
    'La suppression du compte a été annulée.',
  ),
  _ => tr(
    context,
    'Your account settings changed.',
    'Les réglages de votre compte ont changé.',
  ),
};

class SecurityPage extends StatefulWidget {
  final AppSession session;
  const SecurityPage({super.key, required this.session});
  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  AppSession get session => widget.session;
  int noticesRevision = 0;
  void changed() {
    if (mounted) setState(() => noticesRevision++);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PageHeading(
        title: tr(
          context,
          'Know where you’re signed in.',
          'Gardez un œil sur vos connexions.',
        ),
        subtitle: tr(
          context,
          'Review your devices and recent account changes, in one place.',
          'Vos appareils et les changements récents du compte, au même endroit.',
        ),
      ),
      AccountSection(
        icon: Icons.devices_rounded,
        title: tr(context, 'Active sessions', 'Sessions actives'),
        description: tr(
          context,
          'Device labels are approximate. Times below use this device’s local clock.',
          'Les noms des appareils sont approximatifs. Les heures utilisent le fuseau de cet appareil.',
        ),
        child: AccountResource(
          session: session,
          path: '/users/me/sessions',
          builder: (data, refresh) {
            final sessions = (data['sessions'] as List?) ?? [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final s in sessions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.devices_other_rounded, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                s['device'] as String? ??
                                    tr(context, 'Device', 'Appareil'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (s['current'] == true)
                              AccountBadge(
                                label: tr(
                                  context,
                                  'This device',
                                  'Cet appareil',
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${tr(context, 'Signed in', 'Connexion')} · ${accountDate(context, s['created_at'])}\n${tr(context, 'Last active', 'Dernière activité')} · ${accountDate(context, s['last_used_at'])}\n${tr(context, 'Expires', 'Expiration')} · ${accountDate(context, s['expires_at'])}',
                          style: TextStyle(
                            height: 1.8,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AccountAction(
                          label: s['current'] == true
                              ? tr(
                                  context,
                                  'Sign out this device',
                                  'Déconnecter cet appareil',
                                )
                              : tr(
                                  context,
                                  'Revoke session',
                                  'Révoquer la session',
                                ),
                          icon: Icons.logout_rounded,
                          action: () async {
                            final confirmed = await confirmAccountAction(
                              context,
                              title: tr(
                                context,
                                'Sign out this session?',
                                'Déconnecter cette session ?',
                              ),
                              message: tr(
                                context,
                                'This device will need to sign in again. Revocation takes effect on its next request.',
                                'Cet appareil devra se reconnecter. La révocation prend effet à sa prochaine requête.',
                              ),
                            );
                            if (!confirmed || !context.mounted) return;
                            if (s['current'] == true) {
                              final messenger = ScaffoldMessenger.of(context);
                              final revoked = await session.signOut();
                              if (!revoked) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Signed out here. The server session could not be revoked and will expire automatically.',
                                    ),
                                  ),
                                );
                              }
                            } else {
                              await session.request(
                                'DELETE',
                                '/users/me/sessions/${s['id']}',
                                {},
                              );
                              refresh();
                              changed();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                if (sessions.isEmpty)
                  Text(
                    tr(
                      context,
                      'No active sessions returned. Refresh to check again.',
                      'Aucune session renvoyée. Actualisez pour vérifier.',
                    ),
                  ),
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton.icon(
                      onPressed: refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(tr(context, 'Refresh', 'Actualiser')),
                    ),
                  ],
                ),
                if (sessions.length > 1)
                  AccountAction(
                    label: tr(
                      context,
                      'Sign out all other devices',
                      'Déconnecter les autres appareils',
                    ),
                    icon: Icons.phonelink_erase_rounded,
                    action: () async {
                      if (!await reauthenticate(context, session)) return;
                      await session.request('DELETE', '/users/me/sessions', {});
                      refresh();
                      changed();
                    },
                  ),
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 24),
      AccountSection(
        icon: Icons.notifications_none_rounded,
        title: tr(context, 'Account notices', 'Notifications du compte'),
        description: tr(
          context,
          'Private notices are stored in your account. Email and push delivery are not configured.',
          'Ces notifications privées restent dans votre compte. Les envois par e-mail et push ne sont pas configurés.',
        ),
        child: AccountResource(
          session: session,
          path: '/users/me/notices',
          key: ValueKey(noticesRevision),
          builder: (data, refresh) {
            final notices = (data['notices'] as List?) ?? [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (notices.isEmpty)
                  Notice(
                    text: tr(
                      context,
                      'No account changes to show yet.',
                      'Aucun changement du compte à afficher.',
                    ),
                  ),
                for (final n in notices)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      n['read_at'] == null
                          ? Icons.circle_notifications_outlined
                          : Icons.check_circle_outline_rounded,
                      color: n['read_at'] == null
                          ? Theme.of(context).colorScheme.secondary
                          : null,
                    ),
                    title: Text(noticeText(context, n['type'] as String)),
                    subtitle: Text(accountDate(context, n['created_at'])),
                  ),
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton.icon(
                      onPressed: refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(tr(context, 'Refresh', 'Actualiser')),
                    ),
                    if (notices.any((n) => n['read_at'] == null))
                      TextButton(
                        onPressed: () async {
                          try {
                            await session.request(
                              'POST',
                              '/users/me/notices/read',
                              {},
                            );
                            refresh();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          }
                        },
                        child: Text(
                          tr(
                            context,
                            'Mark all as read',
                            'Tout marquer comme lu',
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    ],
  );
}

class AccountPrivacyPage extends StatelessWidget {
  final AppSession session;
  const AccountPrivacyPage({super.key, required this.session});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PageHeading(
        title: tr(
          context,
          'Your space. Your rules.',
          'Votre espace. Vos règles.',
        ),
        subtitle: tr(
          context,
          'See what your data is used for, before you make a choice.',
          'Comprenez l’utilisation de vos données avant de choisir.',
        ),
      ),
      PrivacyContextCard(session: session),
      const SizedBox(height: 24),
      AccountSection(
        icon: Icons.cloud_outlined,
        title: tr(
          context,
          'Cloud AI, only if you choose',
          'L’IA cloud, à votre choix',
        ),
        description: tr(
          context,
          'This account preference is separate from consent for a personal insights summary.',
          'Cette préférence est distincte du consentement pour un résumé des statistiques.',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CloudPreference(session: session),
            Notice(
              text: tr(
                context,
                'This saves your preference. No AI provider is called by these account screens. This choice does not authorize access to unrelated data.',
                'Ce réglage enregistre votre choix. Ces écrans ne contactent aucun fournisseur IA. Il n’autorise pas l’accès à des données sans rapport.',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      PersonalDataCard(session: session),
    ],
  );
}

class _CloudPreference extends StatefulWidget {
  final AppSession session;
  const _CloudPreference({required this.session});
  @override
  State<_CloudPreference> createState() => _CloudPreferenceState();
}

class _CloudPreferenceState extends State<_CloudPreference> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) => SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(
        tr(
          context,
          'Allow selected context for Cloud AI',
          'Autoriser le contexte choisi pour l’IA cloud',
        ),
      ),
      subtitle: Text(
        tr(
          context,
          'Off by default. Change your choice anytime.',
          'Désactivé par défaut. Modifiable à tout moment.',
        ),
      ),
      value: widget.session.account?.cloudAi ?? false,
      onChanged: busy
          ? null
          : (value) async {
              setState(() => busy = true);
              try {
                await widget.session.savePreferences({'cloud_ai': value});
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e.toString())));
                }
              } finally {
                if (mounted) setState(() => busy = false);
              }
            },
    ),
  );
}

class PrivacyContextCard extends StatefulWidget {
  final AppSession session;
  const PrivacyContextCard({super.key, required this.session});
  @override
  State<PrivacyContextCard> createState() => _PrivacyContextCardState();
}

class _PrivacyContextCardState extends State<PrivacyContextCard> {
  String period = 'month';
  late DateTime anchor = DateTime.now();
  @override
  Widget build(BuildContext context) {
    late ({DateTime from, DateTime to}) range;
    try {
      range = analyticsRange(widget.session.account!.timezone, period, anchor);
    } catch (_) {
      return Notice(
        text: tr(
          context,
          'Choose a supported timezone in Preferences before previewing dated analytics.',
          'Choisissez un fuseau horaire pris en charge dans Préférences avant cet aperçu.',
        ),
      );
    }
    final query = Uri(
      queryParameters: {
        'from': range.from.toUtc().toIso8601String(),
        'to': range.to.toUtc().toIso8601String(),
      },
    ).query;
    return AccountSection(
      icon: Icons.visibility_outlined,
      title: tr(
        context,
        'Before AI sees anything',
        'Avant tout partage avec l’IA',
      ),
      description: tr(
        context,
        'An exact preview of the personal insights context. Nothing is transmitted by this preview.',
        'Un aperçu exact du contexte de vos statistiques. Cet aperçu ne transmet aucune donnée.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(tr(context, 'This week', 'Cette semaine')),
                selected: period == 'week',
                onSelected: (_) => setState(() => period = 'week'),
              ),
              ChoiceChip(
                label: Text(tr(context, 'This month', 'Ce mois-ci')),
                selected: period == 'month',
                onSelected: (_) => setState(() => period = 'month'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AccountResource(
            key: ValueKey(widget.session.account),
            session: widget.session,
            path: '/users/me/privacy/preview?$query',
            builder: (data, refresh) {
              final contextData = data['context'] as Map? ?? {};
              final consent = data['consent'] as Map? ?? {};
              final provider = data['provider_available'] == true;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          tr(
                            context,
                            'Included in this preview',
                            'Inclus dans cet aperçu',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '${tr(context, 'Timezone', 'Fuseau horaire')} · ${contextData['timezone'] ?? '—'}',
                          style: const TextStyle(height: 1.8),
                        ),
                        Text(
                          '${tr(context, 'Data coverage', 'Couverture des données')} · ${switch (contextData['status']) {
                            'available' => tr(context, 'Available', 'Disponible'),
                            'partial' => tr(context, 'Partial', 'Partielle'),
                            _ => tr(context, 'Unavailable', 'Indisponible'),
                          }}',
                          style: const TextStyle(height: 1.8),
                        ),
                        Text(
                          '${tr(context, 'Completed tasks', 'Tâches terminées')} · ${contextData['tasks_completed'] ?? tr(context, 'Unavailable', 'Indisponible')}',
                          style: const TextStyle(height: 1.8),
                        ),
                        Text(
                          '${tr(context, 'Completed goals', 'Objectifs terminés')} · ${contextData['goals_completed'] ?? tr(context, 'Unavailable', 'Indisponible')}',
                          style: const TextStyle(height: 1.8),
                        ),
                        Text(
                          '${tr(context, 'UTC range (end excluded)', 'Période UTC (fin exclue)')}\n${(contextData['range'] as Map?)?['from'] ?? '—'} → ${(contextData['range'] as Map?)?['to'] ?? '—'}',
                          style: const TextStyle(height: 1.8),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr(
                      context,
                      'Excluded: your name, email, credentials, raw records and unrelated preferences.',
                      'Exclus : nom, e-mail, identifiants, données brutes et préférences sans rapport.',
                    ),
                    style: const TextStyle(height: 1.7),
                  ),
                  const SizedBox(height: 16),
                  Notice(
                    text: provider
                        ? '${data['provider']} · ${data['retention_notice']}'
                        : tr(
                            context,
                            'Preview only. An approved AI provider and its retention details are required before opt-in becomes available. No summary is generated here.',
                            'Aperçu uniquement. Un fournisseur IA approuvé et ses règles de conservation sont nécessaires avant l’activation. Aucun résumé n’est généré ici.',
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    consent['enabled'] == true
                        ? tr(
                            context,
                            'Personal insights consent: on',
                            'Consentement des statistiques : activé',
                          )
                        : tr(
                            context,
                            'Personal insights consent: off',
                            'Consentement des statistiques : désactivé',
                          ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (consent['updated_at'] != null)
                    Text(
                      '${tr(context, 'Last choice', 'Dernier choix')} · ${accountDate(context, consent['updated_at'])}',
                    ),
                  const SizedBox(height: 12),
                  if (provider && data['cloud_ai_enabled'] != true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Notice(
                        text: tr(
                          context,
                          'Cloud AI is off. Enable the account preference below before allowing these insight fields. Turning Cloud AI off blocks all subsequent insights context requests.',
                          'L’IA cloud est désactivée. Activez la préférence ci-dessous avant d’autoriser ces champs. Sa désactivation bloque les requêtes de contexte suivantes.',
                        ),
                      ),
                    ),
                  if ((provider && data['cloud_ai_enabled'] == true) ||
                      consent['enabled'] == true)
                    AccountAction(
                      label: consent['enabled'] == true
                          ? tr(
                              context,
                              'Withdraw consent',
                              'Retirer le consentement',
                            )
                          : tr(
                              context,
                              'Allow these insight fields',
                              'Autoriser ces champs statistiques',
                            ),
                      icon: Icons.verified_user_outlined,
                      action: () async {
                        await widget.session.request(
                          'PATCH',
                          '/users/me/privacy/consent',
                          {
                            'enabled': consent['enabled'] != true,
                            'version': data['version'],
                          },
                        );
                        refresh();
                      },
                    ),
                  Text(
                    tr(
                      context,
                      'Withdrawing consent blocks subsequent context requests. It does not delete account data already held by Planify.',
                      'Le retrait bloque les requêtes de contexte suivantes. Il ne supprime pas les données déjà conservées par Planify.',
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.7,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class PersonalDataCard extends StatelessWidget {
  final AppSession session;
  const PersonalDataCard({super.key, required this.session});
  @override
  Widget build(BuildContext context) => AccountSection(
    icon: Icons.folder_copy_outlined,
    title: tr(context, 'Your account data', 'Vos données de compte'),
    description: tr(
      context,
      'Profile, preferences, session metadata and consent history belong to your account.',
      'Profil, préférences, métadonnées des sessions et historique du consentement.',
    ),
    child: AccountResource(
      session: session,
      path: '/users/me/data-tools',
      builder: (data, refresh) {
        final available = data['available'] == true;
        final policy = data['policy'] as Map? ?? {};
        final deletion = data['deletion'] as Map?;
        final exports = data['exports'] as List? ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!available)
              Notice(
                text: tr(
                  context,
                  'Export and deletion are awaiting approved retention, recovery and shared-record rules. No export or deletion will start until these are configured.',
                  'L’export et la suppression attendent les règles approuvées de conservation, récupération et données partagées. Aucune action ne démarrera avant leur configuration.',
                ),
              ),
            if (available) ...[
              Text(
                '${policy['retentionNotice']}\n${policy['backupNotice']}',
                style: const TextStyle(height: 1.7),
              ),
              const SizedBox(height: 14),
              Notice(
                text: tr(
                  context,
                  'This export covers account records only. Passwords, token hashes and records from other feature modules are excluded.',
                  'Cet export couvre uniquement le compte. Mots de passe, jetons hachés et données des autres modules sont exclus.',
                ),
              ),
            ],
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.download_outlined),
              title: Text(
                tr(context, 'Export account data', 'Exporter les données'),
              ),
              subtitle: Text(
                available
                    ? tr(
                        context,
                        'A private JSON snapshot, with an expiring, single-use download.',
                        'Un fichier JSON privé avec téléchargement unique et temporaire.',
                      )
                    : tr(
                        context,
                        'Not available · policy pending',
                        'Indisponible · politique en attente',
                      ),
              ),
            ),
            if (available)
              AccountAction(
                label: tr(
                  context,
                  'Create secure export',
                  'Créer un export sécurisé',
                ),
                icon: Icons.download_rounded,
                action: () async {
                  if (!await reauthenticate(context, session)) return;
                  await session.request('POST', '/users/me/export', {});
                  refresh();
                },
              ),
            for (final e in exports)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${tr(context, 'Export expires', 'Expiration de l’export')} · ${accountDate(context, e['expires_at'])}',
                    ),
                    if (e['consumed_at'] != null)
                      Text(
                        tr(
                          context,
                          'Downloaded · create a new export to download again.',
                          'Téléchargé · créez un nouvel export pour recommencer.',
                        ),
                      )
                    else if (available)
                      AccountAction(
                        label: tr(
                          context,
                          'Download JSON export',
                          'Télécharger l’export JSON',
                        ),
                        icon: Icons.file_download_outlined,
                        action: () async {
                          if (!await reauthenticate(context, session)) return;
                          final result = await session.request(
                            'POST',
                            '/users/me/export/${e['id']}',
                            {},
                          );
                          final content = const JsonEncoder.withIndent('  ')
                              .convert(result['content']);
                          delivery.downloadAccountExport(content);
                          if (context.mounted) {
                            await showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(
                                  tr(
                                    context,
                                    'Your account export',
                                    'Votre export du compte',
                                  ),
                                ),
                                content: SizedBox(
                                  width: 600,
                                  child: SingleChildScrollView(
                                    child: SelectableText(content),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: content),
                                      );
                                    },
                                    child: Text(
                                      tr(
                                        context,
                                        'Copy JSON',
                                        'Copier le JSON',
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(tr(context, 'Close', 'Fermer')),
                                  ),
                                ],
                              ),
                            );
                          }
                          refresh();
                        },
                      ),
                  ],
                ),
              ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.person_remove_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(tr(context, 'Delete account', 'Supprimer le compte')),
              subtitle: Text(
                available
                    ? tr(
                        context,
                        'Review consequences and recovery time before confirming.',
                        'Vérifiez les conséquences et le délai de récupération.',
                      )
                    : tr(
                        context,
                        'Not available · recovery and shared-record policy pending',
                        'Indisponible · règles de récupération et données partagées en attente',
                      ),
              ),
            ),
            if (deletion != null) ...[
              Notice(
                text:
                    '${tr(context, 'Deletion', 'Suppression')} · ${deletion['status']}\n${tr(context, 'Scheduled for', 'Prévue le')} ${accountDate(context, deletion['execute_at'])}',
              ),
              AccountAction(
                label: tr(context, 'Cancel deletion', 'Annuler la suppression'),
                icon: Icons.undo_rounded,
                action: () async {
                  if (!await reauthenticate(context, session)) return;
                  await session.request('DELETE', '/users/me/deletion', {});
                  refresh();
                },
              ),
            ] else if (available)
              AccountAction(
                label: tr(
                  context,
                  'Review account deletion',
                  'Vérifier la suppression',
                ),
                icon: Icons.person_remove_outlined,
                destructive: true,
                action: () async {
                  final recovery = Duration(
                    seconds: policy['recoverySeconds'] as int,
                  );
                  final confirmed = await confirmAccountAction(
                    context,
                    title: tr(
                      context,
                      'Review deletion consequences',
                      'Conséquences de la suppression',
                    ),
                    message:
                        '${tr(context, 'Your account, preferences, sessions, notices and consent history will be removed. All sessions will end when deletion executes. You can cancel during the recovery window:', 'Le compte, les préférences, sessions, notifications et consentements seront supprimés. Toutes les sessions prendront fin. Annulation possible pendant le délai :')} ${recovery.inMinutes} ${tr(context, 'minutes', 'minutes')}.\n\n${policy['retentionNotice']}\n${policy['backupNotice']}',
                  );
                  if (!confirmed || !context.mounted) return;
                  if (!await reauthenticate(context, session, deletion: true)) {
                    return;
                  }
                  await session.request('POST', '/users/me/deletion', {
                    'confirmation': 'DELETE',
                  });
                  refresh();
                },
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  tr(context, 'Refresh status', 'Actualiser le statut'),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class AccountHelpPage extends StatefulWidget {
  final AppSession? session;
  const AccountHelpPage({super.key, this.session});
  @override
  State<AccountHelpPage> createState() => _AccountHelpPageState();
}

class _AccountHelpPageState extends State<AccountHelpPage> {
  String query = '';
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topics = <({String title, String body, IconData icon})>[
      (
        title: tr(
          context,
          'Signing in and recovery',
          'Connexion et récupération',
        ),
        body: tr(
          context,
          'Sign in with your registered email and password. Passwords use 12–128 characters. If a session expires, sign in again. Password recovery is unavailable until email delivery is configured; no reset email is sent today.',
          'Connectez-vous avec votre e-mail et mot de passe. Les mots de passe utilisent 12 à 128 caractères. Reconnectez-vous après expiration. La récupération attend un service e-mail ; aucun message de réinitialisation n’est envoyé actuellement.',
        ),
        icon: Icons.login_rounded,
      ),
      (
        title: tr(context, 'Sessions and devices', 'Sessions et appareils'),
        body: tr(
          context,
          'Open Security to see your active sessions. Revoke a session to require that device to sign in again on its next request. Signing out all other devices requires your password. Offline sign-out clears this device; server revocation may wait until expiry.',
          'Ouvrez Sécurité pour voir vos sessions. La révocation oblige l’appareil à se reconnecter à sa prochaine requête. Déconnecter les autres appareils demande votre mot de passe. Hors ligne, seul cet appareil est déconnecté ; la session serveur peut rester valide jusqu’à son expiration.',
        ),
        icon: Icons.devices_rounded,
      ),
      (
        title: tr(
          context,
          'Your profile and preferences',
          'Profil et préférences',
        ),
        body: tr(
          context,
          'Edit your display name from My space. Preferences saves your timezone, English or French language, and light, dark or system appearance. Email changes and email verification are not available until verified email delivery exists.',
          'Modifiez votre nom dans Mon espace. Les préférences enregistrent le fuseau horaire, la langue anglaise ou française et le thème clair, sombre ou système. La modification et la vérification des e-mails attendent un service de vérification.',
        ),
        icon: Icons.tune_rounded,
      ),
      (
        title: tr(
          context,
          'Timezone and insight dates',
          'Fuseau horaire et dates',
        ),
        body: tr(
          context,
          'Personal insights group calendar days and weeks using your saved timezone, including daylight-saving changes. Review a default timezone in Preferences. Missing activity sources appear as unavailable; they are never reported as zero.',
          'Les statistiques regroupent les jours et semaines selon le fuseau enregistré, y compris les changements d’heure. Vérifiez le fuseau par défaut dans Préférences. Les sources absentes sont indiquées indisponibles, jamais comme zéro.',
        ),
        icon: Icons.schedule_rounded,
      ),
      (
        title: tr(
          context,
          'AI choices and context preview',
          'Choix IA et aperçu du contexte',
        ),
        body: tr(
          context,
          'Privacy shows the exact allowlisted fields for a personal insights summary: date range, timezone and verified totals. Your name, email, credentials and raw activity records are excluded. Previewing sends nothing to an AI provider. Opt-in requires an approved provider and retention details. You can withdraw consent anytime.',
          'Confidentialité affiche les champs autorisés : période, fuseau et totaux vérifiés. Nom, e-mail, identifiants et activité brute sont exclus. L’aperçu ne transmet rien à un fournisseur IA. L’activation exige un fournisseur approuvé et ses règles de conservation. Le consentement est révocable.',
        ),
        icon: Icons.visibility_outlined,
      ),
      (
        title: tr(
          context,
          'Export, deletion and data handling',
          'Export, suppression et données',
        ),
        body: tr(
          context,
          'Planify stores profile, preferences and hashed credentials to operate your account. Export and deletion stay unavailable until retention, recovery and shared-record rules are approved. When enabled, exports are private JSON files; deletion requires your password, explicit confirmation and a recovery window. Security notices are in-app; email and push notices are not configured.',
          'Planify conserve profil, préférences et identifiants hachés pour gérer le compte. Export et suppression attendent les règles approuvées de conservation, récupération et données partagées. Une fois activés, les exports sont des fichiers JSON privés ; la suppression exige mot de passe, confirmation et délai de récupération. Les notifications restent dans l’application ; e-mail et push ne sont pas configurés.',
        ),
        icon: Icons.folder_copy_outlined,
      ),
    ];
    final filtered = topics
        .where(
          (t) => '${t.title} ${t.body}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeading(
          title: tr(
            context,
            'A little guidance, right here.',
            'Un peu d’aide, juste ici.',
          ),
          subtitle: tr(
            context,
            'Clear answers about your Planify account. No personal data is sent to search.',
            'Des réponses claires sur votre compte. La recherche ne transmet aucune donnée.',
          ),
        ),
        TextField(
          controller: search,
          onChanged: (value) => setState(() => query = value.trim()),
          decoration: InputDecoration(
            labelText: tr(
              context,
              'Search account help',
              'Rechercher dans l’aide',
            ),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: tr(
                      context,
                      'Clear search',
                      'Effacer la recherche',
                    ),
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      search.clear();
                      setState(() => query = '');
                    },
                  ),
          ),
        ),
        const SizedBox(height: 24),
        AnimatedSize(
          duration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
          ),
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (filtered.isEmpty) ...[
                Notice(
                  text: tr(
                    context,
                    'No matching topic. Try “sessions”, “timezone” or “privacy”.',
                    'Aucun résultat. Essayez « sessions », « fuseau » ou « données ».',
                  ),
                ),
                TextButton(
                  onPressed: () {
                    search.clear();
                    setState(() => query = '');
                  },
                  child: Text(
                    tr(context, 'Show all topics', 'Afficher tous les sujets'),
                  ),
                ),
              ],
              for (final t in filtered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AccountSection(
                    icon: t.icon,
                    title: t.title,
                    description: t.body,
                    child: const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ),
        if (widget.session != null)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => openAccountPanel(
                  context,
                  tr(context, 'Security', 'Sécurité'),
                  SecurityPage(session: widget.session!),
                ),
                icon: const Icon(Icons.fingerprint_rounded),
                label: Text(tr(context, 'Open security', 'Ouvrir la sécurité')),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/preferences'),
                icon: const Icon(Icons.tune_rounded),
                label: Text(
                  tr(context, 'Open preferences', 'Ouvrir les préférences'),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Text(
          tr(
            context,
            'Account help · content version 1',
            'Aide du compte · contenu version 1',
          ),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
