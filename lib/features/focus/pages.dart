import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'focus_store.dart';
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

void openFocus(BuildContext c, FocusStore s) => Navigator.push(
  c,
  MaterialPageRoute(
    builder: (_) =>
        s.active == null ? FocusSetup(store: s) : FocusTimerPage(store: s),
  ),
);

class FocusLanding extends StatelessWidget {
  const FocusLanding({super.key, required this.store});
  final FocusStore store;
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
        onPressed: () => openFocus(c, store),
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
            onPressed: () => openFocus(c, store),
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
  const FocusSetup({super.key, required this.store});
  final FocusStore store;
  @override
  State<FocusSetup> createState() => _FocusSetupState();
}

class _FocusSetupState extends State<FocusSetup> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  String mode = 'Countdown';
  int minutes = 25;
  @override
  void initState() {
    super.initState();
    minutes = adaptiveMinutes(widget.store.sessions);
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
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
              min: 5,
              max: 120,
              divisions: 23,
              label: '$minutes min',
              onChanged: (v) => setState(() => minutes = v.round()),
            ),
          ],
          const SizedBox(height: 30),
          FilledButton.icon(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              if (widget.store.active != null) {
                Navigator.pop(c);
                return;
              }
              widget.store.start(title.text, minutes, mode);
              Navigator.pushReplacement(
                c,
                MaterialPageRoute(
                  builder: (_) => FocusTimerPage(store: widget.store),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Begin focus'),
          ),
        ],
      ),
    ),
  );
}

class FocusTimerPage extends StatelessWidget {
  const FocusTimerPage({super.key, required this.store});
  final FocusStore store;
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: store,
    builder: (c, _) {
      final s = store.active;
      if (s == null) {
        return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('No active session.')),
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
            const SizedBox(height: 20),
            Text(
              s.title,
              textAlign: TextAlign.center,
              style: Theme.of(c).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              '${s.mode} · ${breaking
                  ? 'Break'
                  : s.status == 'paused'
                  ? 'Paused'
                  : 'In progress'}',
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
              onPressed: () {
                final result = store.finish();
                if (result != null) {
                  Navigator.pushReplacement(
                    c,
                    MaterialPageRoute(
                      builder: (_) =>
                          SessionDetail(store: store, session: result),
                    ),
                  );
                }
              },
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
                  'Cancel this session?',
                  'Your recorded focus time will remain in the time log.',
                )) {
                  store.finish(cancelled: true);
                  if (c.mounted) Navigator.pop(c);
                }
              },
              child: const Text(
                'Cancel session',
                style: TextStyle(color: Color(0xFF637083)),
              ),
            ),
          ],
        ),
      );
    },
  );
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
    if (text != null && text.trim().isNotEmpty) store.log(kind, text.trim());
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
  const HistoryPage({super.key, required this.store});
  final FocusStore store;
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
            subtitle: Text('${dayLabel(s.created)} · ${s.status}'),
            trailing: Text('${s.seconds ~/ 60} min'),
            onTap: () => Navigator.push(
              c,
              MaterialPageRoute(
                builder: (_) => SessionDetail(store: widget.store, session: s),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SessionDetail extends StatefulWidget {
  const SessionDetail({super.key, required this.store, required this.session});
  final FocusStore store;
  final FocusSession session;
  @override
  State<SessionDetail> createState() => _SessionDetailState();
}

class _SessionDetailState extends State<SessionDetail> {
  @override
  Widget build(BuildContext c) {
    final s = widget.session;
    return Scaffold(
      appBar: AppBar(title: const Text('Session reflection')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),
          const Icon(
            Icons.verified_outlined,
            size: 52,
            color: Color(0xFF146C52),
          ),
          const SizedBox(height: 20),
          Text(
            s.status == 'cancelled'
                ? 'Every minute counts.'
                : 'A little progress.\nA good feeling.',
            textAlign: TextAlign.center,
            style: Theme.of(c).textTheme.headlineMedium,
          ),
          const SizedBox(height: 14),
          Text(s.title, textAlign: TextAlign.center),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Metric(
                  value: '${s.seconds ~/ 60} min',
                  label: 'Actual focus',
                  icon: Icons.timelapse,
                  color: const Color(0xFFE3F8F3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Metric(
                  value: s.mode == 'Stopwatch' ? '—' : '${s.minutes} min',
                  label: 'Time target',
                  icon: Icons.flag_outlined,
                  color: const Color(0xFFEAF2FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '${dayLabel(s.created)} · ${timeLabel(s.created)} – ${timeLabel(s.ended ?? s.created)}',
            style: const TextStyle(color: Color(0xFF637083)),
          ),
          if (s.status == 'completed')
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('I completed what I set out to do'),
              subtitle: const Text(
                'Saved with this session; task status will connect later.',
              ),
              value: s.taskCompleted,
              onChanged: (v) => setState(() {
                s.taskCompleted = v!;
                widget.store.save();
              }),
            ),
          sectionTitle(
            c,
            'Notes',
            action: 'Edit',
            onTap: () async {
              final note = await textPrompt(c, 'Reflection', initial: s.notes);
              if (note != null && mounted) {
                setState(() {
                  s.notes = note;
                  widget.store.save();
                });
              }
            },
          ),
          Text(
            s.notes.isEmpty ? 'What helped you focus today?' : s.notes,
            style: const TextStyle(color: Color(0xFF637083), height: 1.7),
          ),
          const SizedBox(height: 24),
          if (s.logs.isNotEmpty) ...[
            sectionTitle(c, 'Along the way'),
            ...s.logs.map(
              (l) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.short_text),
                title: Text(l),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Back to my day'),
          ),
        ],
      ),
    );
  }
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
