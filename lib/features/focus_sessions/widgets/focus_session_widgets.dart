import 'package:flutter/material.dart';

import '../controllers/focus_session_controller.dart';
import '../models/focus_session.dart';

class FocusSessionCard extends StatelessWidget {
  const FocusSessionCard({
    required this.session,
    required this.controller,
    required this.onEdit,
    required this.onOpen,
    super.key,
  });

  final FocusSession session;
  final FocusSessionController controller;
  final VoidCallback onEdit;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isActive = controller.activeSession?.id == session.id;
    final progress =
        (session.elapsedSeconds / (session.estimatedDurationMinutes * 60))
            .clamp(0.0, 1.0);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: const Color(0xFF26362F).withValues(alpha: 0.08),
        ),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Actions de session',
                    onSelected: (action) {
                      switch (action) {
                        case 'edit':
                          onEdit();
                          break;
                        case 'archive':
                          controller.archiveSession(session.id);
                          break;
                        case 'restore':
                          controller.restoreSession(session.id);
                          break;
                        case 'delete':
                          controller.deleteSession(session.id);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      if (session.status != FocusSessionStatus.archived) ...[
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Modifier'),
                        ),
                        const PopupMenuItem(
                          value: 'archive',
                          child: Text('Archiver'),
                        ),
                      ] else
                        const PopupMenuItem(
                          value: 'restore',
                          child: Text('Restaurer'),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Supprimer'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '${focusModeLabel(session.mode)}  ·  ${session.estimatedDurationMinutes} min estimées  ·  ${focusStatusLabel(session.status)}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: const Color(0xFF68756E)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: progress,
                        backgroundColor: const Color(0xFFE7ECE7),
                        color: session.exceededEstimate
                            ? const Color(0xFFB5673F)
                            : colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${formatFocusDuration(session.elapsedSeconds)} / ${session.estimatedDurationMinutes} min',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
              if (session.exceededEstimate &&
                  session.status != FocusSessionStatus.completed) ...[
                const SizedBox(height: 8),
                const Text(
                  'Durée estimée dépassée',
                  style: TextStyle(color: Color(0xFF9D4B2E), fontSize: 12),
                ),
              ],
              if (isActive) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      controller.isPomodoroBreak ? Icons.coffee : Icons.bolt,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      session.mode == FocusMode.pomodoro
                          ? '${controller.isPomodoroBreak ? 'Pause' : 'Focus'} · ${formatFocusClock(controller.timerSecondsRemaining)}'
                          : 'En cours',
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton.filledTonal(
                      tooltip: 'Mettre en pause',
                      visualDensity: VisualDensity.compact,
                      onPressed: controller.pauseSession,
                      icon: const Icon(Icons.pause, size: 18),
                    ),
                  ],
                ),
              ] else if (session.status != FocusSessionStatus.completed &&
                  session.status != FocusSessionStatus.archived) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: () => session.status == FocusSessionStatus.paused
                        ? controller.resumeSession(session.id)
                        : controller.startSession(session.id),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: Text(
                      session.status == FocusSessionStatus.paused
                          ? 'Reprendre'
                          : 'Démarrer',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class FocusSessionDetailsSheet extends StatelessWidget {
  const FocusSessionDetailsSheet({
    required this.sessionId,
    required this.controller,
    required this.onEdit,
    super.key,
  });

  final String sessionId;
  final FocusSessionController controller;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final session = controller.sessions.firstWhere(
          (item) => item.id == sessionId,
        );
        final isActive = controller.activeSession?.id == session.id;
        final isEditable = session.status != FocusSessionStatus.archived;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    session.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${focusModeLabel(session.mode)} · ${focusStatusLabel(session.status)}',
                  ),
                  const SizedBox(height: 18),
                  DurationComparison(session: session),
                  if (isActive) ...[
                    const SizedBox(height: 16),
                    Text(
                      session.mode == FocusMode.pomodoro
                          ? '${controller.isPomodoroBreak ? 'Pause' : 'Focus'} · ${formatFocusClock(controller.timerSecondsRemaining)}'
                          : formatFocusClock(controller.timerSecondsRemaining),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (isEditable &&
                          session.status != FocusSessionStatus.completed)
                        FilledButton.icon(
                          onPressed: isActive
                              ? controller.pauseSession
                              : () =>
                                    session.status == FocusSessionStatus.paused
                                    ? controller.resumeSession(session.id)
                                    : controller.startSession(session.id),
                          icon: Icon(isActive ? Icons.pause : Icons.play_arrow),
                          label: Text(
                            isActive
                                ? 'Pause'
                                : session.status == FocusSessionStatus.paused
                                ? 'Reprendre'
                                : 'Démarrer',
                          ),
                        ),
                      if (isEditable &&
                          session.status != FocusSessionStatus.completed)
                        OutlinedButton.icon(
                          onPressed: () =>
                              controller.completeSession(session.id),
                          icon: const Icon(Icons.check),
                          label: const Text('Terminer'),
                        ),
                      if (isEditable)
                        OutlinedButton.icon(
                          onPressed: () =>
                              controller.requestMoreTime(session.id),
                          icon: const Icon(Icons.more_time),
                          label: const Text('Plus de temps (+10 min)'),
                        ),
                    ],
                  ),
                  if (session.exceededEstimate &&
                      session.status != FocusSessionStatus.completed) ...[
                    const SizedBox(height: 12),
                    Material(
                      color: const Color(0xFFFFF0E8),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'La session dépasse la durée prévue.',
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  controller.requestMoreTime(session.id),
                              child: const Text('+10 min'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Notes',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (isEditable)
                        TextButton.icon(
                          onPressed: () => _editNotes(context, session),
                          icon: const Icon(Icons.edit_note, size: 18),
                          label: const Text('Modifier'),
                        ),
                    ],
                  ),
                  Text(
                    session.notes.isEmpty
                        ? 'Aucune note pour le moment.'
                        : session.notes,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Journal (${session.log.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (isEditable)
                        TextButton.icon(
                          onPressed: () =>
                              _addInterruption(context, session.id),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Interruption'),
                        ),
                    ],
                  ),
                  if (isEditable)
                    OutlinedButton.icon(
                      onPressed: () => _markBlocked(context, session.id),
                      icon: const Icon(Icons.help_outline, size: 18),
                      label: const Text('Je suis bloqué'),
                    ),
                  if (session.log.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text('Aucune interruption enregistrée.'),
                    )
                  else
                    ...session.log.reversed.map(
                      (entry) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(_logIcon(entry.kind), size: 20),
                        title: Text(entry.description),
                        subtitle: Text(
                          'À ${formatFocusDuration(entry.elapsedSeconds)}',
                        ),
                      ),
                    ),
                  if (isEditable)
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Modifier la session'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _editNotes(BuildContext context, FocusSession session) async {
    final notes = await _textEntryDialog(
      context,
      title: 'Notes de session',
      initialValue: session.notes,
      hint: 'Ce que vous avez accompli, idées à garder…',
      multiline: true,
    );
    if (notes != null) controller.updateNotes(session.id, notes);
  }

  Future<void> _addInterruption(BuildContext context, String id) async {
    final description = await _textEntryDialog(
      context,
      title: 'Journaliser une interruption',
      hint: 'Qu’est-ce qui a interrompu votre concentration ?',
      multiline: true,
    );
    if (description != null) controller.logInterruption(id, description);
  }

  Future<void> _markBlocked(BuildContext context, String id) async {
    final description = await _textEntryDialog(
      context,
      title: 'Qu’est-ce qui vous bloque ?',
      hint: 'Décrivez brièvement le blocage…',
      multiline: true,
    );
    if (description != null) controller.markBlocked(id, description);
  }
}

class DurationComparison extends StatelessWidget {
  const DurationComparison({required this.session, super.key});

  final FocusSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4EF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _DurationValue(
              label: 'ESTIMÉ',
              value: '${session.estimatedDurationMinutes} min',
            ),
          ),
          Expanded(
            child: _DurationValue(
              label: 'RÉEL',
              value: formatFocusDuration(session.elapsedSeconds),
            ),
          ),
          Expanded(
            child: _DurationValue(
              label: 'ÉCART',
              value: formatFocusDuration(
                session.elapsedSeconds - session.estimatedDurationMinutes * 60,
                signed: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationValue extends StatelessWidget {
  const _DurationValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: Color(0xFF68756E)),
      ),
      const SizedBox(height: 4),
      Text(value, style: Theme.of(context).textTheme.titleSmall),
    ],
  );
}

class FocusSessionDraft {
  const FocusSessionDraft(this.title, this.minutes, this.mode);

  final String title;
  final int minutes;
  final FocusMode mode;
}

class FocusSessionFormDialog extends StatefulWidget {
  const FocusSessionFormDialog({this.session, super.key});

  final FocusSession? session;

  @override
  State<FocusSessionFormDialog> createState() => _FocusSessionFormDialogState();
}

class _FocusSessionFormDialogState extends State<FocusSessionFormDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _minutesController;
  late FocusMode _mode;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.session?.title ?? '');
    _minutesController = TextEditingController(
      text: '${widget.session?.estimatedDurationMinutes ?? 25}',
    );
    _mode = widget.session?.mode ?? FocusMode.focus;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.session == null ? 'Nouvelle session' : 'Modifier la session',
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nom de la session'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _minutesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Durée estimée (minutes)',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<FocusMode>(
            initialValue: _mode,
            decoration: const InputDecoration(labelText: 'Mode'),
            items: FocusMode.values
                .map(
                  (mode) => DropdownMenuItem(
                    value: mode,
                    child: Text(focusModeLabel(mode)),
                  ),
                )
                .toList(),
            onChanged: (mode) => setState(() => _mode = mode ?? _mode),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Enregistrer')),
    ],
  );

  void _submit() {
    final title = _titleController.text.trim();
    final minutes = int.tryParse(_minutesController.text.trim());
    if (title.isEmpty || minutes == null || minutes < 1 || minutes > 1440)
      return;
    Navigator.pop(context, FocusSessionDraft(title, minutes, _mode));
  }
}

Future<String?> _textEntryDialog(
  BuildContext context, {
  required String title,
  String initialValue = '',
  String? hint,
  bool multiline = false,
}) {
  final textController = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: textController,
        autofocus: true,
        maxLines: multiline ? 4 : 1,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, textController.text),
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  ).whenComplete(textController.dispose);
}

String focusModeLabel(FocusMode mode) => switch (mode) {
  FocusMode.free => 'Libre',
  FocusMode.focus => 'Concentration',
  FocusMode.pomodoro => 'Pomodoro 25/5',
};

String focusStatusLabel(FocusSessionStatus status) => switch (status) {
  FocusSessionStatus.planned => 'À faire',
  FocusSessionStatus.active => 'En cours',
  FocusSessionStatus.paused => 'En pause',
  FocusSessionStatus.completed => 'Terminée',
  FocusSessionStatus.archived => 'Archivée',
};

String formatFocusDuration(int seconds, {bool signed = false}) {
  final absolute = seconds.abs();
  final minutes = absolute ~/ 60;
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  final value = hours == 0 ? '${minutes}m' : '${hours}h ${remainder}m';
  if (!signed) return value;
  return seconds > 0
      ? '+$value'
      : seconds < 0
      ? '-$value'
      : '0m';
}

String formatFocusClock(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

IconData _logIcon(SessionLogKind kind) => switch (kind) {
  SessionLogKind.interruption => Icons.notifications_paused_outlined,
  SessionLogKind.blocked => Icons.help_outline,
  SessionLogKind.extension => Icons.more_time,
};
