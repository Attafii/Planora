import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_services.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/product_widgets.dart';
import '../../../core/utils/validators.dart';
import '../models/project.dart';
import 'project_workspace.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({super.key, required this.id});
  final String id;
  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  String _search = '';
  @override
  Widget build(BuildContext context) => ProductPage(
    title: 'Project members',
    subtitle: 'Make responsibilities clear.',
    child: AsyncView<Project>(
      load: () => AppScope.of(context).collaboration.detail(widget.id),
      builder: (ctx, p, refresh) => Column(
        children: [
          SearchBox(
            hint: 'Search members',
            onSearch: (s) => setState(() => _search = s.toLowerCase()),
          ),
          const SizedBox(height: 20),
          if (p.canManage)
            Align(
              alignment: Alignment.centerLeft,
              child: BusyButton(
                label: 'Invite a member',
                icon: Icons.person_add_outlined,
                onPressed: () async {
                  await inviteMember(context, p.id, owner: p.role == 'owner');
                  refresh();
                },
              ),
            ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                for (final m in p.members.where(
                  (m) => '${m.name} ${m.email}'.toLowerCase().contains(_search),
                ))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Surface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              child: Text(m.name.substring(0, 1).toUpperCase()),
                            ),
                            title: Text(m.name),
                            subtitle: Text(m.email),
                          ),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              StatusChip(m.role),
                              if (p.canManage &&
                                  m.role != 'owner' &&
                                  (p.role == 'owner' || m.role != 'admin')) ...[
                                OutlinedButton(
                                  onPressed: () async {
                                    await _roleSheet(context, p, m);
                                    refresh();
                                  },
                                  child: const Text('Change role'),
                                ),
                                BusyButton(
                                  label: 'Remove',
                                  outlined: true,
                                  onPressed: () async {
                                    if (!await confirm(
                                      context,
                                      title: 'Remove ${m.name}?',
                                      message: 'They will lose project access and their task assignments will be cleared.',
                                      action: 'Remove',
                                    )) {
                                      return;
                                    }
                                    if (!context.mounted) return;
                                    await AppScope.of(context).collaboration
                                        .removeMember(p.id, m.id);
                                    refresh();
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _roleSheet(BuildContext context, Project p, Member m) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => _RoleSheet(project: p, member: m),
    );

class _RoleSheet extends StatefulWidget {
  const _RoleSheet({required this.project, required this.member});
  final Project project;
  final Member member;
  @override
  State<_RoleSheet> createState() => _RoleSheetState();
}

class _RoleSheetState extends State<_RoleSheet> {
  late String _role;
  @override
  void initState() {
    super.initState();
    _role = widget.member.role;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Role for ${widget.member.name}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: _role,
          decoration: const InputDecoration(labelText: 'Project role'),
          items: [
            if (widget.project.role == 'owner')
              const DropdownMenuItem(value: 'admin', child: Text('Admin')),
            const DropdownMenuItem(
              value: 'collaborator',
              child: Text('Collaborator'),
            ),
            const DropdownMenuItem(
              value: 'viewer',
              child: Text('Viewer — read only'),
            ),
          ],
          onChanged: (s) => setState(() => _role = s!),
        ),
        const SizedBox(height: 16),
        const Text(
          'Admins manage members and work. Collaborators update their own or assigned work. Viewers can read. Only the owner manages admin permissions.',
        ),
        const SizedBox(height: 24),
        BusyButton(
          label: 'Update role',
          onPressed: () async {
            await AppScope.of(context).collaboration
                .setRole(widget.project.id, widget.member.id, _role);
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    ),
  );
}

class InvitationsPage extends StatefulWidget {
  const InvitationsPage({super.key, required this.id});
  final String id;
  @override
  State<InvitationsPage> createState() => _InvitationsPageState();
}

class _InvitationsPageState extends State<InvitationsPage> {
  final _view = GlobalKey<AsyncViewState<List<Invitation>>>();
  String _filter = '';
  @override
  Widget build(BuildContext context) => ProductPage(
    title: 'Project invitations',
    subtitle: 'Invite deliberately. Access stays under your control.',
    actions: [
      BusyButton(
        label: 'Invite a member',
        icon: Icons.person_add_outlined,
        onPressed: () async {
          final p = await AppScope.of(context).collaboration.detail(widget.id);
          if (context.mounted) {
            await inviteMember(context, p.id, owner: p.role == 'owner');
            _view.currentState?.refresh();
          }
        },
      ),
    ],
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
              'accepted': 'Accepted',
              'expired': 'Expired',
              'revoked': 'Revoked',
              'rejected': 'Rejected',
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _filter == entry.key,
                onSelected: (_) => setState(() => _filter = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: AsyncView<List<Invitation>>(
            key: _view,
            load: () =>
                AppScope.of(context).collaboration.invitations(widget.id),
            builder: (ctx, items, refresh) {
              final list = items
                  .where((i) => _filter.isEmpty || i.status == _filter)
                  .toList();
              if (list.isEmpty) {
                return const StateMessage(
                  title: 'No invitations here',
                  message: 'Create an invitation and share its link with the intended recipient.',
                );
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  for (final i in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Surface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              i.email,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                StatusChip(i.role),
                                StatusChip(i.status),
                                StatusChip(
                                  'Expires ${readableDate(i.expiresAt)}',
                                ),
                              ],
                            ),
                            if (i.status == 'pending') ...[
                              const SizedBox(height: 12),
                              BusyButton(
                                label: 'Revoke invitation',
                                outlined: true,
                                onPressed: () async {
                                  if (!await confirm(
                                    context,
                                    title: 'Revoke this invitation?',
                                    message: 'The shared link will no longer grant project access.',
                                    action: 'Revoke',
                                  )) {
                                    return;
                                  }
                                  if (!context.mounted) return;
                                  await AppScope.of(context).collaboration
                                      .revoke(widget.id, i.id);
                                  refresh();
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

Future<void> inviteMember(
  BuildContext context,
  String projectId, {
  required bool owner,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (ctx) => _InviteSheet(projectId: projectId, owner: owner),
);

class _InviteSheet extends StatefulWidget {
  const _InviteSheet({required this.projectId, required this.owner});
  final String projectId;
  final bool owner;
  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _form = GlobalKey<FormState>(), _email = TextEditingController();
  String _role = 'collaborator';
  String? _link;
  @override
  void dispose() {
    _email.dispose();
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
              'Invite a collaborator',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _email,
              enabled: _link == null,
              validator: Validators.email,
              keyboardType: TextInputType.emailAddress,
              maxLength: 254,
              decoration: const InputDecoration(labelText: 'Recipient email'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: [
                if (widget.owner)
                  const DropdownMenuItem(value: 'admin', child: Text('Admin')),
                const DropdownMenuItem(
                  value: 'collaborator',
                  child: Text('Collaborator'),
                ),
                const DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
              ],
              onChanged: _link != null
                  ? null
                  : (s) => setState(() => _role = s!),
            ),
            const SizedBox(height: 20),
            const Text(
              'The recipient must sign in using this email. Invitations expire after seven days.',
            ),
            const SizedBox(height: 24),
            if (_link == null)
              BusyButton(
                label: 'Create invitation',
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  final d = await AppScope.of(context).collaboration
                      .invite(widget.projectId, _email.text, _role);
                  final configured = const String.fromEnvironment(
                    'INVITATION_BASE_URL',
                  );
                  final origin = configured.isNotEmpty
                      ? configured
                      : (Uri.base.hasScheme &&
                                Uri.base.scheme.startsWith('http')
                            ? Uri.base.origin
                            : 'http://localhost:5300');
                  if (mounted) {
                    setState(
                      () => _link = '$origin/#/invitations/${d['token']}',
                    );
                  }
                },
              )
            else ...[
              const Text(
                'Invitation ready. Save and share this link with the recipient.',
              ),
              const SizedBox(height: 12),
              SelectableText(_link!),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _link!));
                  if (context.mounted) {
                    feedback(context, 'Invitation link copied');
                  }
                },
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy invitation link'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

Future<void> openInvitation(BuildContext context) async {
  final controller = TextEditingController();
  String? token;
  final input = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Open an invitation'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'Invitation link or token',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Open'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (input == null || input.isEmpty) return;
  final match = RegExp(r'/invitations/([^/?#]+)').firstMatch(input);
  token = match?.group(1) ?? input;
  if (context.mounted) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => InvitationResponsePage(token: token!),
      ),
    );
  }
}

class InvitationResponsePage extends StatelessWidget {
  const InvitationResponsePage({super.key, required this.token});
  final String token;
  @override
  Widget build(BuildContext context) => ProductPage(
    title: 'Project invitation',
    child: AsyncView<JsonMap>(
      load: () => AppScope.of(context).collaboration.invitation(token),
      builder: (ctx, i, refresh) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.mail_outline, size: 40),
                const SizedBox(height: 20),
                Text(
                  i['title'] as String,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  '${i['sender']} invited ${i['email']} to join as ${i['role']}.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    StatusChip(i['status'] as String),
                    StatusChip(
                      'Expires ${readableDate(i['expires_at'] as String)}',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (i['status'] == 'pending')
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      BusyButton(
                        label: 'Accept invitation',
                        onPressed: () async {
                          final result = await AppScope.of(context)
                              .collaboration
                              .respond(token, true);
                          if (context.mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => ProjectWorkspace(
                                  id: result['project_id'] as String,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      BusyButton(
                        label: 'Decline',
                        outlined: true,
                        onPressed: () async {
                          await AppScope.of(context).collaboration
                              .respond(token, false);
                          refresh();
                        },
                      ),
                    ],
                  )
                else
                  const Text(
                    'This invitation is no longer pending. If it expired or was revoked, request a new link from the project owner.',
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
