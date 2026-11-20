import 'package:flutter/material.dart';

import '../controllers/focus_session_controller.dart';
import '../models/focus_session.dart';
import '../widgets/focus_session_widgets.dart';

class FocusSessionsPage extends StatefulWidget {
  const FocusSessionsPage({super.key});

  @override
  State<FocusSessionsPage> createState() => _FocusSessionsPageState();
}

class _FocusSessionsPageState extends State<FocusSessionsPage> {
  final FocusSessionController _controller = FocusSessionController();
  bool _showArchived = false;
  bool _focusView = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final active = _controller.activeSession;
        final visibleSessions = _controller.sessions.where((session) {
          if (_focusView) return session.id == active?.id;
          return _showArchived
              ? session.status == FocusSessionStatus.archived
              : session.status != FocusSessionStatus.archived;
        }).toList();
        final completed = _controller.sessions
            .where((session) => session.status == FocusSessionStatus.completed)
            .length;
        final totalSeconds = _controller.sessions.fold<int>(
          0,
          (total, session) => total + session.elapsedSeconds,
        );

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F2),
          appBar: AppBar(
            title: const Text('Focus sessions'),
            actions: [
              IconButton(
                tooltip: _focusView
                    ? 'Quitter la concentration'
                    : 'Mode concentration',
                onPressed: () => setState(() => _focusView = !_focusView),
                icon: Icon(
                  _focusView
                      ? Icons.fullscreen_exit
                      : Icons.center_focus_strong,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: _focusView && active == null
                ? const _EmptyFocusView()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_focusView) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: _SummaryTile(
                                  label: 'TERMINÉES',
                                  value: '$completed',
                                  icon: Icons.check_circle_outline,
                                  color: colors.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _SummaryTile(
                                  label: 'TEMPS FOCUS',
                                  value: formatFocusDuration(totalSeconds),
                                  icon: Icons.timelapse,
                                  color: const Color(0xFFB5673F),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _showArchived ? 'Archives' : 'Mes sessions',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => setState(
                                  () => _showArchived = !_showArchived,
                                ),
                                icon: Icon(
                                  _showArchived
                                      ? Icons.arrow_back
                                      : Icons.archive_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  _showArchived ? 'Sessions' : 'Archives',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Expanded(
                        child: visibleSessions.isEmpty
                            ? _EmptySessionsView(
                                archived: _showArchived && !_focusView,
                                focusView: _focusView,
                                onCreate: _createSession,
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  12,
                                  20,
                                  96,
                                ),
                                itemCount: visibleSessions.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final session = visibleSessions[index];
                                  return FocusSessionCard(
                                    session: session,
                                    controller: _controller,
                                    onEdit: () => _editSession(session),
                                    onOpen: () => _openSession(session),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          ),
          floatingActionButton: _showArchived || _focusView
              ? null
              : FloatingActionButton.extended(
                  onPressed: _createSession,
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvelle session'),
                ),
        );
      },
    );
  }

  Future<void> _createSession() async {
    final draft = await showDialog<FocusSessionDraft>(
      context: context,
      builder: (_) => const FocusSessionFormDialog(),
    );
    if (draft == null) return;
    _controller.createSession(
      title: draft.title,
      estimatedDurationMinutes: draft.minutes,
      mode: draft.mode,
    );
  }

  Future<void> _editSession(FocusSession session) async {
    final draft = await showDialog<FocusSessionDraft>(
      context: context,
      builder: (_) => FocusSessionFormDialog(session: session),
    );
    if (draft == null) return;
    _controller.updateSession(
      session.id,
      title: draft.title,
      estimatedDurationMinutes: draft.minutes,
      mode: draft.mode,
    );
  }

  void _openSession(FocusSession session) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FocusSessionDetailsSheet(
        sessionId: session.id,
        controller: _controller,
        onEdit: () {
          Navigator.pop(context);
          _editSession(session);
        },
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF26362F).withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF68756E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySessionsView extends StatelessWidget {
  const _EmptySessionsView({
    required this.archived,
    required this.focusView,
    required this.onCreate,
  });

  final bool archived;
  final bool focusView;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final message = focusView
        ? 'Démarrez une session pour passer en concentration.'
        : archived
        ? 'Aucune session archivée.'
        : 'Organisez votre prochain temps de focus.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              focusView ? Icons.center_focus_strong : Icons.timer_outlined,
              size: 38,
              color: const Color(0xFF60776B),
            ),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            if (!archived && !focusView) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Créer une session'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyFocusView extends StatelessWidget {
  const _EmptyFocusView();

  @override
  Widget build(BuildContext context) => const _EmptySessionsView(
    archived: false,
    focusView: true,
    onCreate: _ignoreAction,
  );
}

void _ignoreAction() {}
