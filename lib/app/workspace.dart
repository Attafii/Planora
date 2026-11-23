import 'dart:convert';

import '../features/account/account_setup.dart';
import '../features/account/sync_issue_dialog.dart';

import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';

import 'package:flutter/material.dart';

import 'app_services.dart' show AppServices;
import 'daily_dock.dart';
import 'today_page.dart';
import 'work_activity.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/account/account_screens.dart';
import '../features/tasks/task_agent.dart';
import '../features/planning/planning_agent.dart';
import '../core/services/app_session.dart';
import '../core/services/personal_sync.dart';
import '../features/assistant/presentation/conversations_page.dart';
import '../features/focus/focus_store.dart';
import '../features/focus/focus_task_link.dart';
import '../features/focus/pages.dart' show openFocus;
import '../features/planning/planning_engine.dart' show PlanBlock;
import 'focus_app.dart' show MobileShell;
import '../features/planning/planning_page.dart';
import '../features/planning/planning_store.dart';
import '../features/tasks/task_store.dart';
import '../features/tasks/tasks_page.dart';

class Workspace extends StatefulWidget {
  const Workspace({super.key, required this.session, this.services});

  final AppSession session;
  final AppServices? services;

  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> with WidgetsBindingObserver {
  late final sync = PersonalSync(widget.session, SharedPreferencesAsync());
  late final storage = SyncedPreferences(sync);
  late final accountId = sync.accountId;
  int workspaceVersion = 0;
  late final tasks = TaskStore(storage, accountId: accountId);
  late final planning = PlanningStore(
    storage,
    tasks,
    accountId: accountId,
    timezone: () => widget.session.account?.timezone,
  );
  PlanningAgent get planningAgent =>
      PlanningAgent(session: widget.session, accountId: accountId);
  Widget get focusSyncStatus =>
      ListenableBuilder(listenable: sync, builder: (_, _) => syncStatus());

  Future<void>? _sharedRefresh;
  Timer? _sharedTimer;
  late final activity = WorkActivity(
    tasks: tasks,
    planning: planning,
    focus: focus,
    openCalendar: openWorkCalendar,
    openTask: openPersonalTask,
    syncPersonal: () async {
      await tasks.settled;
      await sync.sync();
      if (sync.pending &&
          !sync.offline &&
          sync.error == null &&
          !sync.updates.containsKey('tasks')) {
        await sync.sync();
      }
      if (sync.offline ||
          sync.error != null ||
          sync.updates.containsKey('tasks')) {
        throw StateError(
          'Resolve task sync from Today before refreshing goal activity.',
        );
      }
    },
  );

  Future<void> refreshSharedWork() => _sharedRefresh ??= _loadSharedWork()
      .whenComplete(() => _sharedRefresh = null);

  Future<void> _loadSharedWork() async {
    if (!mounted || widget.session.account?.id != accountId) {
      throw const ApiFailure(AppSession.ended, status: 401);
    }
    try {
      final data = await widget.session.request(
        'GET',
        '/projects/planning-tasks',
      );
      if (!mounted || widget.session.account?.id != accountId) return;
      tasks.setSharedTasks([
        for (final row in (data['items'] as List).cast<Map<String, dynamic>>())
          Task(
            id: sharedTaskKey(row['id'] as String),
            title: sharedTaskLabel(row['id'] as String),
            minutes: row['estimated_minutes'] as int,
            due: row['deadline'] as String?,
            done: row['status'] == 'completed',
          ),
      ]);
    } catch (_) {
      if (mounted) tasks.setSharedTasks([]);
      rethrow;
    }
  }

  Future<void> completeSharedWork(String id) async {
    if (!mounted || widget.session.account?.id != accountId) {
      throw const ApiFailure(AppSession.ended, status: 401);
    }
    await widget.session.request('PATCH', '/tasks/$id', {
      'status': 'completed',
      'from_plan': true,
    });
    refreshSharedWork().ignore();
  }

  Future<void> openPersonalTask(String id) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TasksPage(
          store: tasks,
          focus: focus,
          syncStatus: focusSyncStatus,
          initialTaskId: id,
          agent: TaskAgent(session: widget.session, accountId: accountId),
        ),
      ),
    );
  }

  Future<void> openWorkCalendar() async {
    await refreshSharedWork();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PlanningPage(
          session: widget.session,
          store: planning,
          agent: planningAgent,
          onStartFocus: startFocus,
          syncStatus: focusSyncStatus,
        ),
      ),
    );
  }

  Future<void> startFocus(String date, PlanBlock block) async {
    if (isSharedTaskKey(block.id)) {
      try {
        await refreshSharedWork();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reconnect to verify access to this project task.'),
            ),
          );
        }
        return;
      }
    }
    if (!mounted || widget.session.account?.id != accountId) return;
    openFocus(
      context,
      focus,
      scheduled: ScheduledFocus.fromBlock(block, date, planning.clock.zone()),
      syncStatus: focusSyncStatus,
    );
  }

  late final focus = FocusStore(
    accountId: accountId,
    storage: storage,
    taskContext: FocusTaskContext(tasks, planning),
    onPlanRecovery: (id) {
      if (!mounted || widget.session.account?.id != accountId) return;
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => PlanningPage(
            session: widget.session,
            store: planning,
            agent: planningAgent,
            initialInterruptionId: id,
            onStartFocus: startFocus,
            syncStatus: ListenableBuilder(
              listenable: sync,
              builder: (_, _) => syncStatus(),
            ),
          ),
        ),
      );
    },
    proposeAgent: (body) {
      if (widget.session.account?.id != accountId) {
        throw const ApiFailure(AppSession.ended, status: 401);
      }
      return widget.session.request('POST', '/agents/focus', body);
    },
  );
  late Future<void> ready = load();
  int selected = 0;

  static const destinations = [
    (Icons.wb_sunny_outlined, 'Today'),
    (Icons.calendar_month_outlined, 'Calendar'),
    (Icons.timer_outlined, 'Focus'),
    (Icons.auto_awesome_outlined, 'Assistant'),
    (Icons.more_horiz, 'More'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => offerSetup());
  }

  Future<void> offerSetup() async {
    try {
      final cached = await SharedPreferencesAsync().getString(
        'planify.setup.v1.${widget.session.baseUrl}.$accountId',
      );
      if (cached != null &&
          (jsonDecode(cached) as Map)['status'] == 'skipped') {
        return;
      }
      final state = await widget.session.request('GET', '/users/me/onboarding');
      if (!mounted ||
          ModalRoute.of(context)?.isCurrent != true ||
          state['status'] != 'new') {
        return;
      }
      final start = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Make Planify yours'),
          content: const Text(
            'Set up your language, appearance and timezone manually or with AI suggestions. You can revisit setup from Preferences.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Set up'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (start == true) {
        await openAccountSetup(context, widget.session);
      } else {
        await widget.session.request('PATCH', '/users/me/onboarding', {
          'revision': state['revision'],
          'status': 'skipped',
          'draft': {},
        });
      }
    } catch (_) {
      /* Setup remains available from Preferences when reconnected. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      sync.sync();
      if (widget.services != null) refreshSharedWork().ignore();
    }
  }

  Future<void> load() async {
    await sync.open();
    await reloadStores();
    if (!mounted || widget.services == null) return;
    tasks.refreshShared = refreshSharedWork;
    tasks.completeShared = completeSharedWork;
    widget.services!.workActivity = activity;
    _sharedTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      refreshSharedWork().ignore();
    });
    refreshSharedWork().ignore();
  }

  Future<void> reloadStores() async {
    if (!mounted) return;
    await tasks.load();
    await Future.wait([planning.load(), focus.load()]);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sharedTimer?.cancel();
    if (widget.services?.workActivity == activity) {
      widget.services!.workActivity = null;
    }
    if (widget.session.account?.id != accountId) focus.clearDeviceAlerts();
    sync.dispose();
    planning.dispose();
    focus.dispose();
    tasks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Brand(),
        actions: [
          ListenableBuilder(
            listenable: sync,
            builder: (_, _) => IconButton(
              tooltip: 'Personal data sync',
              onPressed: showSync,
              icon: Icon(
                sync.offline || sync.error != null || sync.updates.isNotEmpty
                    ? Icons.sync_problem
                    : Icons.sync,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Account and preferences',
            onPressed: () => Navigator.pushNamed(context, '/account'),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ListenableBuilder(
              listenable: sync,
              builder: (_, _) => syncStatus(),
            ),
            Expanded(
              child: FutureBuilder<void>(
                future: ready,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: FilledButton(
                        onPressed: () => setState(() => ready = load()),
                        child: const Text(
                          'Could not load your workspace. Retry',
                        ),
                      ),
                    );
                  }
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: selected == 0
                          ? 0
                          : MediaQuery.paddingOf(context).bottom,
                    ),
                    child: IndexedStack(
                      index: selected,
                      children: [
                        TodayPage(
                          key: ValueKey(workspaceVersion),
                          tasks: tasks,
                          planning: planning,
                          storage: storage,
                          accountId: accountId,
                          onCalendar: () => select(1),
                          onStartFocus: startFocus,
                          onTasks: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => TasksPage(
                                syncStatus: ListenableBuilder(
                                  listenable: sync,
                                  builder: (_, _) => syncStatus(),
                                ),
                                store: tasks,
                                focus: focus,
                                agent: TaskAgent(
                                  session: widget.session,
                                  accountId: accountId,
                                ),
                              ),
                            ),
                          ),
                        ),
                        PlanningPage(
                          session: widget.session,
                          store: planning,
                          embedded: true,
                          agent: planningAgent,
                          onStartFocus: startFocus,
                        ),
                        ListenableBuilder(
                          listenable: focus,
                          builder: (_, _) => MobileShell(
                            store: focus,
                            embedded: true,
                            syncStatus: focusSyncStatus,
                          ),
                        ),
                        const ConversationsPage(embedded: true),
                        const _MorePage(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      extendBody: true,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Align(
          heightFactor: 1,
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .12),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface
                          .withValues(alpha: .86),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: MediaQuery.removePadding(
                      context: context,
                      removeBottom: true,
                      child: DailyDock(
                        destinations: destinations,
                        selected: selected,
                        onSelect: select,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get syncMessage {
    if (sync.syncing) return 'Syncing personal data…';
    if (sync.offline) {
      return sync.pending
          ? 'Offline. Changes saved on this device.'
          : 'Offline. Showing data saved on this device.';
    }
    if (sync.error != null) {
      return 'Sync failed. Device data is still available.';
    }
    if (sync.updates.values.contains(true)) {
      return 'Review changes from another device.';
    }
    if (sync.updates.isNotEmpty) {
      return 'Updates are available from another device.';
    }
    if (sync.pending) return 'Changes saved on this device. Waiting to sync.';
    return sync.synced ? 'Personal data is up to date' : 'Waiting to connect';
  }

  Widget syncStatus() {
    if (!sync.offline &&
        sync.error == null &&
        !sync.pending &&
        sync.updates.isEmpty) {
      return const SizedBox.shrink();
    }
    return ListTile(
      dense: true,
      title: Semantics(liveRegion: true, child: Text(syncMessage)),
      trailing: TextButton(
        onPressed: sync.updates.isNotEmpty
            ? showSync
            : sync.syncing
            ? null
            : sync.sync,
        child: Text(sync.updates.isEmpty ? 'Retry' : 'Review'),
      ),
    );
  }

  Future<void> showSync() => showDialog<void>(
    context: context,
    builder: (dialog) => ListenableBuilder(
      listenable: sync,
      builder: (_, _) => AlertDialog(
        title: const Text('Personal data sync'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(syncMessage),
              if (sync.error case final message?) Text(message),
              if (sync.offline || sync.error != null)
                TextButton(
                  onPressed: () =>
                      showSyncFailureHelp(dialog, widget.session, sync.offline),
                  child: const Text('Explain this sync failure'),
                ),
              for (final entry in sync.updates.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(PersonalSync.labels[entry.key]!),
                  subtitle: Text(
                    entry.value
                        ? 'Both devices changed this collection.'
                        : 'A newer version is available.',
                  ),
                  onTap: () => chooseVersion(dialog, entry.key, entry.value),
                ),
              for (final entry in PersonalSync.labels.entries)
                if (sync.versions(entry.key).isNotEmpty)
                  TextButton(
                    onPressed: () => showVersions(dialog, entry.key),
                    child: Text('Saved versions · ${entry.value}'),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: sync.syncing ? null : sync.sync,
            child: const Text('Sync now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );

  Future<void> chooseVersion(
    BuildContext dialog,
    String collection,
    bool conflict,
  ) async {
    final preview = sync.preview(collection);
    final keepLocal = await showDialog<bool>(
      context: dialog,
      builder: (_) => SyncIssueDialog(
        session: widget.session,
        preview: preview,
        conflict: conflict,
      ),
    );
    if (keepLocal == null || !mounted || !dialog.mounted) return;
    Navigator.pop(dialog);
    focus.suspend();
    setState(
      () => ready = applyVersion(
        collection,
        keepLocal,
        expectedPreview: preview['fingerprint'] as String,
      ),
    );
  }

  Future<void> applyVersion(
    String collection,
    bool keepLocal, {
    String? expectedPreview,
  }) async {
    await Future.wait([tasks.settled, planning.settled, focus.settled]);
    if (!mounted) return;
    try {
      await sync.resolve(
        collection,
        keepLocal: keepLocal,
        expectedPreview: expectedPreview,
      );
      workspaceVersion++;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not switch versions. Reconnect and review a fresh preview; your edits are preserved.',
            ),
          ),
        );
      }
    }
    await reloadStores();
  }

  Future<void> showVersions(
    BuildContext dialog,
    String collection,
  ) => showDialog<void>(
    context: dialog,
    builder: (context) => AlertDialog(
      title: Text('Saved versions · ${PersonalSync.labels[collection]}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, snapshot) in sync.versions(collection).indexed)
              ListTile(
                title: Text('Saved version ${index + 1}'),
                trailing: IconButton(
                  tooltip: 'Copy saved data',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: snapshot));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Saved version copied.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_outlined),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  void select(int index) {
    setState(() => selected = index);
    if (index == 1 && widget.services != null) refreshSharedWork().ignore();
  }
}

class _MorePage extends StatelessWidget {
  const _MorePage();

  static const links = [
    (
      Icons.flag_outlined,
      'Goals',
      'Set milestones and track long-term progress',
      '/goals',
    ),
    (
      Icons.people_outline,
      'Projects',
      'Plan work together and manage invitations',
      '/projects',
    ),
    (
      Icons.workspace_premium_outlined,
      'Achievements',
      'See your progress, streaks and rewards',
      '/achievements',
    ),
    (
      Icons.emoji_events_outlined,
      'Challenges',
      'Find and join a productivity challenge',
      '/challenges',
    ),
    (
      Icons.settings_outlined,
      'Preferences',
      'Change appearance, language and timezone',
      '/preferences',
    ),
  ];

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Your workspace',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          for (final (icon, title, description, route) in links)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(icon),
                title: Text(title),
                subtitle: Text(description),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, route),
              ),
            ),
        ],
      ),
    ),
  );
}
