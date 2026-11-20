import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'focus_store.dart';
import 'focus_task_link.dart';
import 'smart_tools.dart';

String clock(int seconds) {
  final n = seconds.abs();
  return '${seconds < 0 ? '+' : ''}${(n ~/ 60).toString().padLeft(2, '0')}:${(n % 60).toString().padLeft(2, '0')}';
}

String timeLabel(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String dayLabel(DateTime d) =>
    '${['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1]}, ${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.day}';
Widget sectionTitle(
  BuildContext c,
  String title, {
  String? action,
  VoidCallback? onTap,
}) => Row(
  children: [
    Expanded(child: Text(title, style: Theme.of(c).textTheme.titleLarge)),
    if (action != null) TextButton(onPressed: onTap, child: Text(action)),
  ],
);

class Metric extends StatelessWidget {
  const Metric({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
  final String value, label;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: ink, size: 22),
        const SizedBox(height: 16),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF526078)),
        ),
      ],
    ),
  );
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title, body;
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Column(
      children: [
        Icon(icon, size: 38, color: const Color(0xFF8290A5)),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF637083), height: 1.6),
        ),
      ],
    ),
  );
}

void openFocus(
  BuildContext context,
  FocusStore store, {
  ScheduledFocus? scheduled,
  Widget? syncStatus,
}) {
  final active = store.active;
  final resume =
      active != null &&
      (scheduled == null || scheduled.sameSlot(active.scheduled));
  Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => resume
          ? FocusTimerPage(
              store: store,
              sessionId: active.id,
              syncStatus: syncStatus,
            )
          : FocusSetup(
              store: store,
              scheduled: scheduled,
              syncStatus: syncStatus,
            ),
    ),
  );
}

Widget _focusSaveStatus(FocusStore store, Widget? syncStatus) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    ?syncStatus,
    if (store.saving) const Text('Saving on this device…'),
    if (store.error case final error?)
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(error),
        trailing: TextButton(
          onPressed: store.save,
          child: const Text('Retry save'),
        ),
      ),
  ],
);

class FocusLanding extends StatelessWidget {
  const FocusLanding({super.key, required this.store, this.syncStatus});
  final FocusStore store;
  final Widget? syncStatus;
  @override
  Widget build(BuildContext c) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Text(
              'Find your flow.',
              style: Theme.of(c).textTheme.headlineLarge,
            ),
          ),
          IconButton.filledTonal(
            onPressed: () => openContextAssist(c, store, 'AI focus coach'),
            tooltip: 'AI focus coach',
            icon: const Icon(Icons.auto_awesome_outlined),
          ),
        ],
      ),
      const SizedBox(height: 12),
      const Text(
        'A little structure. A lot more headspace.',
        style: TextStyle(color: Color(0xFF637083)),
      ),
      const SizedBox(height: 40),
      Container(
        height: 190,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFE3F8F3),
        ),
        child: const Icon(Icons.spa_outlined, size: 80, color: ink),
      ),
      const SizedBox(height: 32),
      Text(
        store.active?.title ?? 'What will you focus on?',
        textAlign: TextAlign.center,
        style: Theme.of(c).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      const Text(
        'Choose a timer that works for you.\nTake a break whenever you need one.',
        textAlign: TextAlign.center,
        style: TextStyle(height: 1.7, color: Color(0xFF637083)),
      ),
      const SizedBox(height: 28),
      FilledButton.icon(
        onPressed: () => openFocus(c, store, syncStatus: syncStatus),
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(
          store.active == null ? 'Set up a session' : 'Continue your session',
        ),
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF146C52)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${adaptiveMinutes(store.sessions)} min · Your suggested rhythm',
              style: const TextStyle(color: Color(0xFF526078)),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => openFocus(c, store, syncStatus: syncStatus),
            tooltip: 'Use adaptive focus duration',
            icon: const Icon(Icons.arrow_forward_rounded, size: 20),
          ),
        ],
      ),
      const SizedBox(height: 32),
      const ListTile(
        leading: Icon(Icons.timer_outlined),
        title: Text('Countdown'),
        subtitle: Text('Make space for one focused block.'),
      ),
      const ListTile(
        leading: Icon(Icons.coffee_outlined),
        title: Text('Pomodoro'),
        subtitle: Text('25 minutes of focus, then a gentle break.'),
      ),
      const ListTile(
        leading: Icon(Icons.all_inclusive),
        title: Text('Stopwatch'),
        subtitle: Text('Follow your own pace. Count time up.'),
      ),
    ],
  );
}

class FocusSetup extends StatefulWidget {
  const FocusSetup({
    super.key,
    required this.store,
    this.scheduled,
    this.syncStatus,
  });
  final FocusStore store;
  final ScheduledFocus? scheduled;
  final Widget? syncStatus;
  @override
  State<FocusSetup> createState() => _FocusSetupState();
}

class _FocusSetupState extends State<FocusSetup> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  String mode = 'Countdown';
  int minutes = 25;
  late ScheduledFocus? slot;
  String? startError;

  String? get slotIssue {
    final scheduled = slot;
    if (scheduled == null) return null;
    try {
      final taskContext = widget.store.taskContext;
      if (taskContext == null) return 'The focus workspace is unavailable.';
      taskContext.eligibleTask(scheduled);
      return null;
    } on StateError catch (error) {
      return error.message;
    }
  }

  void openTimer(BuildContext context, FocusSession session) {
    Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute(
        builder: (_) => FocusTimerPage(
          store: widget.store,
          sessionId: session.id,
          syncStatus: widget.syncStatus,
        ),
      ),
    );
  }

  void begin(BuildContext context) {
    if (!form.currentState!.validate()) return;
    if (widget.store.active != null) {
      setState(
        () => startError = 'Continue or finish the active session first.',
      );
      return;
    }
    try {
      final selected = slot;
      if (selected == null) {
        widget.store.start(title.text, minutes, mode);
      } else {
        widget.store.startScheduled(selected, minutes, mode);
      }
      if (widget.store.active case final session?) openTimer(context, session);
    } on StateError catch (error) {
      setState(() => startError = error.message);
    }
  }

  @override
  void initState() {
    super.initState();
    slot = widget.scheduled;
    final selected = slot;
    minutes = selected == null
        ? adaptiveMinutes(widget.store.sessions)
        : (selected.end - selected.start).clamp(1, 120);
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.store,
      widget.store.taskContext?.tasks,
      widget.store.taskContext?.plan,
    ]),
    builder: (c, _) {
      final selected = slot;
      final task = selected == null
          ? null
          : widget.store.taskContext?.tasks.get(selected.taskId);
      final issue = slotIssue;
      final active = widget.store.active;
      return Scaffold(
        appBar: AppBar(title: const Text('A fresh start')),
        body: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Text(
                'One thing\nat a time.',
                style: Theme.of(c).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              _focusSaveStatus(widget.store, widget.syncStatus),
              if (selected != null) ...[
                Text(
                  task?.title ?? 'Scheduled task',
                  style: Theme.of(c).textTheme.titleLarge,
                ),
                Text(selected.label),
                Text('${selected.end - selected.start} min scheduled'),
                const Text('You can start before the scheduled time.'),
                if (issue != null) ...[
                  Text(issue),
                  TextButton(
                    onPressed: () => setState(() {
                      slot = null;
                      startError = null;
                      title.text = task?.title ?? '';
                      minutes = minutes.clamp(5, 120);
                    }),
                    child: const Text('Use unassigned focus'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Back to plan'),
                  ),
                ],
              ] else ...[
                const Text(
                  'Name what you want to give your attention to.',
                  style: TextStyle(color: Color(0xFF637083)),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: title,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'What are you working on?',
                    hintText: 'e.g. Read a chapter',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Give your session a name'
                      : null,
                ),
              ],
              if (startError != null && startError != issue) Text(startError!),
              if (active != null) ...[
                Text('There is an active session for ${active.title}.'),
                TextButton(
                  onPressed: () => openTimer(c, active),
                  child: const Text('Continue active session'),
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'YOUR FOCUS STYLE',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: mode,
                onChanged: (v) => setState(() {
                  mode = v!;
                  if (mode == 'Pomodoro') minutes = 25;
                }),
                child: Column(
                  children: ['Countdown', 'Pomodoro', 'Stopwatch']
                      .map(
                        (m) => RadioListTile<String>(
                          value: m,
                          title: Text(m),
                          subtitle: Text(
                            m == 'Pomodoro'
                                ? '25-minute blocks with optional 5-minute breaks'
                                : m == 'Countdown'
                                ? 'A clear target, with room to extend'
                                : 'No time pressure. Just begin.',
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              if (mode != 'Stopwatch') ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$minutes minutes',
                        style: Theme.of(c).textTheme.titleLarge,
                      ),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.tune, size: 16),
                      label: Text(
                        'Suggested ${adaptiveMinutes(widget.store.sessions)}m',
                      ),
                      onPressed: () => setState(
                        () => minutes = adaptiveMinutes(widget.store.sessions),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: minutes.toDouble(),
                  min: selected == null ? 5 : 1,
                  max: 120,
                  divisions: selected == null ? 23 : 119,
                  label: '$minutes min',
                  onChanged: (v) => setState(() => minutes = v.round()),
                ),
              ],
              const SizedBox(height: 30),
              FilledButton.icon(
                onPressed: issue != null || active != null
                    ? null
                    : () => begin(c),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Begin focus'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class FocusTimerPage extends StatelessWidget {
  const FocusTimerPage({
    super.key,
    required this.store,
    this.sessionId,
    this.syncStatus,
  });
  final FocusStore store;
  final String? sessionId;
  final Widget? syncStatus;
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: store,
    builder: (c, _) {
      final s = store.active;
      if (s == null || (sessionId != null && sessionId != s.id)) {
        return Scaffold(
          appBar: AppBar(),
          body: const Center(
            child: Text('This focus session is no longer active.'),
          ),
        );
      }
      final elapsed = s.elapsed(store.now);
      final breaking = s.status == 'break';
      final remaining = breaking
          ? s.breakUntil!.difference(store.now).inSeconds.clamp(0, 1 << 31)
          : s.minutes * 60 - elapsed;
      return Scaffold(
        appBar: AppBar(
          title: Text(breaking ? 'A moment to recharge' : 'Your focus space'),
          actions: [
            IconButton(
              onPressed: () => _notes(c, s),
              tooltip: 'Session notes',
              icon: const Icon(Icons.edit_note_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _focusSaveStatus(store, syncStatus),
            const SizedBox(height: 20),
            Text(
              s.title,
              textAlign: TextAlign.center,
              style: Theme.of(c).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            if (s.scheduled case final slot?)
              Text(slot.label, textAlign: TextAlign.center),
            Text(
              '${s.mode} · ${s.statusLabel}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF637083)),
            ),
            const SizedBox(height: 40),
            Center(
              child: SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: breaking
                            ? remaining / 300
                            : s.mode == 'Stopwatch'
                            ? null
                            : (elapsed / (s.minutes * 60)).clamp(0, 1),
                        strokeWidth: 9,
                        backgroundColor: const Color(0xFFE4EAE8),
                        color: breaking ? violet : teal,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            child: Text(
                              clock(
                                s.mode == 'Stopwatch' && !breaking
                                    ? elapsed
                                    : remaining,
                              ),
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 52,
                                fontWeight: FontWeight.w600,
                                color: ink,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            breaking
                                ? 'Breathe. You have time.'
                                : remaining < 0 && s.mode != 'Stopwatch'
                                ? 'Extra time · no rush'
                                : s.mode == 'Stopwatch'
                                ? 'Time well spent'
                                : 'Minutes to make yours',
                            style: const TextStyle(
                              color: Color(0xFF637083),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 36),
            if (s.mode == 'Pomodoro' && !breaking && remaining <= 0) ...[
              const Text(
                'Your focus block is complete. Take a break or finish your session.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: store.takeBreak,
                icon: const Icon(Icons.coffee_outlined),
                label: const Text('Take a 5-minute break'),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: s.status == 'running' ? store.pause : store.resume,
              icon: Icon(
                s.status == 'running'
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
              label: Text(
                s.status == 'running'
                    ? 'Pause focus'
                    : breaking
                    ? 'Return to focus'
                    : 'Resume focus',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _finish(c, s),
              child: const Text('Finish session'),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => store.addTime(10),
                  icon: const Icon(Icons.more_time),
                  label: const Text('+10 minutes'),
                ),
                TextButton.icon(
                  onPressed: () => _log(c, 'Blocked'),
                  icon: const Icon(Icons.help_outline),
                  label: const Text("I'm blocked"),
                ),
                if (store.onPlanRecovery case final recover?)
                  if (s.mode != 'Stopwatch' && !breaking && remaining <= 0)
                    TextButton.icon(
                      onPressed: () => recover('focus-${s.id}-overrun'),
                      icon: const Icon(Icons.event_repeat_outlined),
                      label: const Text('Review focus overrun in Calendar'),
                    ),
                TextButton.icon(
                  onPressed: () => _log(c, 'Interruption'),
                  icon: const Icon(Icons.bolt_outlined),
                  label: const Text('Interruption'),
                ),
              ],
            ),
            TextButton(
              onPressed: () async {
                if (await confirm(
                  c,
                  'Abandon this session?',
                  'Your recorded time will remain in the time log. The task will stay open.',
                )) {
                  if (!c.mounted || store.active?.id != s.id) return;
                  final result = store.finish(cancelled: true);
                  if (result != null) _reflection(c, result);
                }
              },
              child: const Text(
                'Abandon session',
                style: TextStyle(color: Color(0xFF637083)),
              ),
            ),
          ],
        ),
      );
    },
  );
  Future<void> _finish(BuildContext context, FocusSession session) async {
    final early =
        session.mode != 'Stopwatch' &&
        session.elapsed(store.currentTime) < session.minutes * 60;
    if (early) {
      final end = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('End focus early?'),
          content: const Text(
            'Your active focus time will be saved. You can continue the work later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Keep focusing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('End early'),
            ),
          ],
        ),
      );
      if (end != true) return;
    }
    if (!context.mounted || store.active?.id != session.id) return;
    final result = store.finish();
    if (result != null) _reflection(context, result);
  }

  void _reflection(BuildContext context, FocusSession result) {
    Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute(
        builder: (_) => SessionDetail(
          store: store,
          session: result,
          syncStatus: syncStatus,
        ),
      ),
    );
  }

  Future<void> _notes(BuildContext c, FocusSession s) async {
    final value = await textPrompt(c, 'Session notes', initial: s.notes);
    if (value != null) {
      s.notes = value;
      store.save();
    }
  }

  Future<void> _log(BuildContext c, String kind) async {
    final text = await textPrompt(
      c,
      kind == 'Blocked'
          ? 'What is getting in the way?'
          : 'What interrupted you?',
    );
    if (text == null || text.trim().isEmpty || !c.mounted) return;
    final session = store.active;
    if (session == null) return;
    store.log(kind, text.trim());
    final recover = store.onPlanRecovery;
    if (recover != null &&
        await confirm(
          c,
          'Review this disruption in Calendar?',
          'Choose the unavailable time and review the new schedule before approving it.',
        ) &&
        c.mounted) {
      recover('focus-${session.id}-${session.logs.length}');
    }
  }
}

Future<String?> textPrompt(
  BuildContext c,
  String title, {
  String initial = '',
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: c,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 4,
        maxLength: 1000,
        decoration: const InputDecoration(hintText: 'Write a little context…'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  return result;
}

Future<bool> confirm(BuildContext c, String title, String body) async =>
    await showDialog<bool>(
      context: c,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.store, this.syncStatus});
  final FocusStore store;
  final Widget? syncStatus;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String filter = 'All';
  @override
  Widget build(BuildContext c) {
    final sessions = widget.store.sessions
        .where(
          (s) =>
              s.finished &&
              widget.store.hasSavedFinish(s.id) &&
              (filter == 'All' ||
                  (filter == 'Today'
                      ? DateUtils.isSameDay(s.created, DateTime.now())
                      : s.created.isAfter(
                          DateTime.now().subtract(const Duration(days: 7)),
                        ))),
        )
        .toList();
    final seconds = sessions.fold<int>(0, (n, s) => n + s.seconds);
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        _focusSaveStatus(widget.store, widget.syncStatus),
        const SizedBox(height: 16),
        Text(
          'Your time,\nwell spent.',
          style: Theme.of(c).textTheme.headlineLarge,
        ),
        const SizedBox(height: 12),
        const Text(
          'Every small step adds up.',
          style: TextStyle(color: Color(0xFF637083)),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          children: ['All', 'Today', '7 days']
              .map(
                (v) => ChoiceChip(
                  label: Text(v),
                  selected: filter == v,
                  onSelected: (_) => setState(() => filter = v),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Metric(
                value: '${seconds ~/ 60} min',
                label: 'Actual focus time',
                icon: Icons.timelapse,
                color: const Color(0xFFE3F8F3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Metric(
                value: '${sessions.length}',
                label: 'Sessions recorded',
                icon: Icons.check_circle_outline,
                color: const Color(0xFFEAF2FF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (sessions.isEmpty)
          const EmptyPanel(
            icon: Icons.history_rounded,
            title: 'Your story starts here',
            body: 'Finish your first focus session to see your time here.',
          ),
        ...sessions.map(
          (s) => ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 6),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFF0EAFF),
              child: Icon(
                s.status == 'cancelled'
                    ? Icons.stop_rounded
                    : Icons.check_rounded,
                color: ink,
              ),
            ),
            title: Text(s.title),
            subtitle: Text(
              '${dayLabel(s.created)} · ${s.statusLabel}${s.interrupted ? ' · Interrupted' : ''}',
            ),
            trailing: Text(clock(s.seconds)),
            onTap: () => Navigator.push(
              c,
              MaterialPageRoute(
                builder: (_) => SessionDetail(
                  store: widget.store,
                  session: s,
                  syncStatus: widget.syncStatus,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SessionDetail extends StatefulWidget {
  const SessionDetail({
    super.key,
    required this.store,
    required this.session,
    this.syncStatus,
  });
  final FocusStore store;
  final FocusSession session;
  final Widget? syncStatus;
  @override
  State<SessionDetail> createState() => _SessionDetailState();
}

class _SessionDetailState extends State<SessionDetail> {
  bool markingDone = false;
  String? taskError;

  Future<void> markDone(FocusSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Mark the linked task done?'),
        content: Text(session.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Keep open'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Mark done'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      markingDone = true;
      taskError = null;
    });
    try {
      await widget.store.completeLinkedTask(session.id);
    } catch (error) {
      if (mounted) {
        setState(() {
          taskError = error is StateError
              ? error.message
              : 'Could not mark the task done. Try again.';
        });
      }
    } finally {
      if (mounted) setState(() => markingDone = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.store,
      widget.store.taskContext?.tasks,
    ]),
    builder: (context, _) {
      final store = widget.store;
      final session = store.sessions
          .where((entry) => entry.id == widget.session.id)
          .firstOrNull;
      final theme = Theme.of(context);
      if (session == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Session reflection')),
          body: const Center(
            child: Text('This session is unavailable in the current history.'),
          ),
        );
      }
      final slot = session.scheduled;
      final tasks = store.taskContext?.tasks;
      final task = slot == null ? null : tasks?.get(slot.taskId);
      final done = task != null && tasks!.completed(task);
      final saved = store.hasSavedFinish(session.id);
      return Scaffold(
        appBar: AppBar(title: const Text('Session reflection')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _focusSaveStatus(store, widget.syncStatus),
            const SizedBox(height: 16),
            Icon(
              session.status == 'cancelled'
                  ? Icons.stop_circle_outlined
                  : Icons.verified_outlined,
              size: 52,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              session.statusLabel,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 14),
            Text(session.title, textAlign: TextAlign.center),
            if (session.interrupted)
              const Text('Interruption recorded', textAlign: TextAlign.center),
            if (slot != null) Text(slot.label, textAlign: TextAlign.center),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Metric(
                    value: clock(session.seconds),
                    label: 'Actual focus (min:sec)',
                    icon: Icons.timelapse,
                    color: const Color(0xFFE3F8F3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Metric(
                    value: session.mode == 'Stopwatch'
                        ? '—'
                        : '${session.minutes} min',
                    label: 'Time target',
                    icon: Icons.flag_outlined,
                    color: const Color(0xFFEAF2FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              '${dayLabel(session.created)} · ${timeLabel(session.created)} – ${timeLabel(session.ended ?? session.created)}',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (slot != null) ...[
              if (!saved)
                const Text('Save the session before updating its linked task.')
              else if (session.status == 'cancelled')
                const Text('Abandoned time stays in the time log.')
              else if (task == null || task.skipped)
                const Text(
                  'The linked task is unavailable. This session stays in the time log.',
                )
              else ...[
                Text(
                  done
                      ? 'Linked task is done.'
                      : 'Focus time recorded. The linked task is open.',
                ),
                if (!done)
                  FilledButton.tonal(
                    onPressed: markingDone ? null : () => markDone(session),
                    child: Text(
                      markingDone ? 'Saving task…' : 'Mark task done',
                    ),
                  ),
              ],
              if (taskError case final error?) Text(error),
            ] else if (session.status != 'cancelled')
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('I completed what I set out to do'),
                subtitle: const Text('Saved as a reflection on this session.'),
                value: session.taskCompleted,
                onChanged: (value) {
                  session.taskCompleted = value!;
                  store.save();
                },
              ),
            sectionTitle(
              context,
              'Notes',
              action: 'Edit',
              onTap: () async {
                final note = await textPrompt(
                  context,
                  'Reflection',
                  initial: session.notes,
                );
                if (note == null ||
                    !mounted ||
                    !store.sessions.any((item) => identical(item, session))) {
                  return;
                }
                session.notes = note;
                store.save();
              },
            ),
            Text(
              session.notes.isEmpty
                  ? 'What helped you focus today?'
                  : session.notes,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 24),
            if (session.logs.isNotEmpty) ...[
              sectionTitle(context, 'Along the way'),
              for (final entry in session.logs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.short_text),
                  title: Text(entry),
                ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                slot != null && !done && session.status != 'cancelled'
                    ? 'Continue later'
                    : 'Back to my day',
              ),
            ),
          ],
        ),
      );
    },
  );
}

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key, required this.store});
  final FocusStore store;
  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  String filter = 'Upcoming';
  @override
  Widget build(BuildContext c) {
    final s = widget.store;
    final items =
        s.reminders
            .where(
              (r) => filter == 'All' || filter == 'Disabled'
                  ? !r.enabled || filter == 'All'
                  : r.enabled && (r.repeat != 'Once' || r.when.isAfter(s.now)),
            )
            .toList()
          ..sort((a, b) => a.next(s.now).compareTo(b.next(s.now)));
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Gentle nudges.',
                style: Theme.of(c).textTheme.headlineMedium,
              ),
            ),
            IconButton.filled(
              onPressed: () => editReminder(c, s),
              tooltip: 'Add reminder',
              icon: const Icon(Icons.add),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: () => openContextAssist(c, s, 'AI reminder agent'),
              tooltip: 'AI reminder agent',
              icon: const Icon(Icons.auto_awesome_outlined),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Less to remember. More room to breathe.',
          style: TextStyle(color: Color(0xFF637083)),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.notifications_active_outlined, color: ink),
              const SizedBox(height: 10),
              Text(
                s.notifications.message,
                style: const TextStyle(height: 1.5),
              ),
              if (s.notifications.supported)
                TextButton(
                  onPressed: () async {
                    await s.notifications.request();
                    for (final r in s.reminders) {
                      await s.putReminder(r);
                    }
                    if (mounted) setState(() {});
                  },
                  child: const Text('Enable notifications'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 8,
          children: ['Upcoming', 'All', 'Disabled']
              .map(
                (v) => ChoiceChip(
                  label: Text(v),
                  selected: filter == v,
                  onSelected: (_) => setState(() => filter = v),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        if (items.isEmpty)
          const EmptyPanel(
            icon: Icons.notifications_none_rounded,
            title: 'Nothing to keep in your head',
            body: 'Add a reminder for a deadline, a break, or a little everyday thing.',
          ),
        ...items.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  ListTile(
                    onTap: () => editReminder(c, s, r),
                    contentPadding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFF0EAFF),
                      child: Icon(Icons.notifications_none, color: ink),
                    ),
                    title: Text(
                      r.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${dayLabel(r.next(s.now))} · ${timeLabel(r.next(s.now))}\n${r.repeat}',
                    ),
                    isThreeLine: true,
                    trailing: Switch(
                      value: r.enabled,
                      onChanged: (v) {
                        r.enabled = v;
                        s.putReminder(r);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            await s.snooze(r);
                            if (c.mounted) {
                              ScaffoldMessenger.of(c).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Reminder moved to 10 minutes from now.',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.snooze, size: 18),
                          label: const Text('Snooze'),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Find a calmer time',
                          onPressed: () => openContextAssist(
                            c,
                            s,
                            'Reminder guard',
                            reminder: r,
                          ),
                          icon: const Icon(Icons.shield_outlined, size: 21),
                        ),
                        IconButton(
                          tooltip: 'Delete reminder',
                          onPressed: () async {
                            if (await confirm(
                              c,
                              'Delete reminder?',
                              'This reminder and its scheduled alert will be removed.',
                            )) {
                              await s.deleteReminder(r);
                            }
                          },
                          icon: const Icon(Icons.delete_outline, size: 21),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> editReminder(BuildContext c, FocusStore s, [Reminder? r]) =>
    Navigator.push(
      c,
      MaterialPageRoute(
        builder: (_) => ReminderEditor(store: s, reminder: r),
      ),
    );

class ReminderEditor extends StatefulWidget {
  const ReminderEditor({super.key, required this.store, this.reminder});
  final FocusStore store;
  final Reminder? reminder;
  @override
  State<ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends State<ReminderEditor> {
  final form = GlobalKey<FormState>();
  late TextEditingController title, note;
  late DateTime when;
  late String repeat;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.reminder?.title);
    note = TextEditingController(text: widget.reminder?.note);
    when =
        widget.reminder?.next(DateTime.now()) ??
        DateTime.now().add(const Duration(hours: 1));
    repeat = widget.reminder?.repeat ?? 'Once';
  }

  @override
  void dispose() {
    title.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.reminder == null ? 'A little reminder' : 'Edit reminder',
      ),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Text(
            'Let it off\nyour mind.',
            style: Theme.of(c).textTheme.headlineLarge,
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: title,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Remind me to…'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Add a reminder title' : null,
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Date'),
            subtitle: Text(dayLabel(when)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final d = await showDatePicker(
                context: c,
                initialDate: when.isBefore(DateTime.now())
                    ? DateTime.now()
                    : when,
                firstDate: DateUtils.dateOnly(DateTime.now()),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (d != null) {
                setState(
                  () => when = DateTime(
                    d.year,
                    d.month,
                    d.day,
                    when.hour,
                    when.minute,
                  ),
                );
              }
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: const Text('Time'),
            subtitle: Text('${timeLabel(when)} · Device timezone'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final t = await showTimePicker(
                context: c,
                initialTime: TimeOfDay.fromDateTime(when),
              );
              if (t != null) {
                setState(
                  () => when = DateTime(
                    when.year,
                    when.month,
                    when.day,
                    t.hour,
                    t.minute,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: repeat,
            decoration: const InputDecoration(labelText: 'Repeat'),
            items: [
              'Once',
              'Daily',
              'Weekly',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => repeat = v!),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: note,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'A note to yourself (optional)',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    if (!when.isAfter(DateTime.now())) {
                      ScaffoldMessenger.of(c).showSnackBar(
                        const SnackBar(
                          content: Text('Choose a future date and time.'),
                        ),
                      );
                      return;
                    }
                    setState(() => saving = true);
                    await widget.store.putReminder(
                      Reminder(
                        id: widget.reminder?.id ?? newId(),
                        title: title.text.trim(),
                        when: when,
                        repeat: repeat,
                        note: note.text.trim(),
                        enabled: widget.reminder?.enabled ?? true,
                      ),
                    );
                    if (c.mounted) Navigator.pop(c);
                  },
            child: Text(saving ? 'Saving…' : 'Save reminder'),
          ),
        ],
      ),
    ),
  );
}

class InboxPage extends StatelessWidget {
  const InboxPage({super.key, required this.store});
  final FocusStore store;
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: AnimatedBuilder(
      animation: store,
      builder: (c, _) => ListView(
        padding: const EdgeInsets.all(22),
        children: [
          if (store.inbox.isEmpty)
            const EmptyPanel(
              icon: Icons.mark_email_read_outlined,
              title: 'All quiet here',
              body: 'Session blockers and requests for more time will appear here.',
            ),
          ...store.inbox.map(
            (text) => ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              leading: const Icon(Icons.info_outline),
              title: Text(text),
            ),
          ),
          if (store.inbox.isNotEmpty)
            TextButton(
              onPressed: () {
                store.inbox.clear();
                store.save();
              },
              child: const Text('Clear updates'),
            ),
        ],
      ),
    ),
  );
}
