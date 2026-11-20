import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/planning/planning_engine.dart';
import '../features/planning/planning_store.dart';
import '../features/tasks/task_store.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({
    super.key,
    required this.tasks,
    required this.planning,
    required this.accountId,
    required this.storage,
    required this.onTasks,
    required this.onCalendar,
  });
  final TaskStore tasks;
  final PlanningStore planning;
  final SharedPreferencesAsync storage;
  final String accountId;
  final VoidCallback onTasks, onCalendar;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  late DateTime now = widget.planning.localNow;
  Timer? timer;
  static const moods = ['Low', 'Quiet', 'Steady', 'Good', 'Great'];
  String? mood;
  bool saving = false;
  String get moodKey => 'planify.mood.${widget.accountId}.${dayKey(now)}';

  @override
  void initState() {
    super.initState();
    loadMood();
    widget.planning.addListener(publishWidget);
    publishWidget();
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      final previous = dayKey(now);
      setState(() => now = widget.planning.localNow);
      if (previous != dayKey(now)) {
        publishWidget();
        mood = null;
        loadMood();
      }
    });
  }

  Future<void> publishWidget({bool clear = false}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final date = dayKey(now);
    try {
      await const MethodChannel('planify/today_widget')
          .invokeMethod<void>('update', {
            if (!clear) 'date': date,
            if (!clear)
              'entries': [
                for (final block in widget.planning.calendarEntries(date))
                  {'title': block.title, 'end': block.end},
              ],
          });
    } on MissingPluginException {
      // A Flutter test host has no Android launcher.
    } on PlatformException {
      // Planning remains available when the launcher rejects a widget update.
    }
  }

  Future<void> loadMood() async {
    final key = moodKey;
    try {
      final value = await widget.storage.getString(key);
      if (mounted && key == moodKey && !saving && mood == null) {
        setState(() => mood = value);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load your check-in.')),
        );
      }
    }
  }

  Future<void> checkIn() async {
    final key = moodKey;
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'How are you feeling?',
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
            ),
            for (final entry in moods)
              ListTile(
                title: Text(entry),
                selected: entry == mood,
                onTap: () => Navigator.pop(sheet, entry),
              ),
          ],
        ),
      ),
    );
    if (!mounted || result == null || key != moodKey) return;
    setState(() => saving = true);
    try {
      await widget.storage.setString(key, result);
      if (mounted && key == moodKey) setState(() => mood = result);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save your check-in. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    widget.planning.removeListener(publishWidget);
    publishWidget(clear: true);
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.tasks, widget.planning]),
    builder: (context, _) {
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      final blocks = widget.planning.calendarEntries(dayKey(now));
      final minute = now.hour * 60 + now.minute;
      final next = blocks.where((b) => b.end > minute).firstOrNull;
      final ready = widget.tasks
          .forPlanningDate(dayKey(now))
          .where(
            (t) =>
                (t.due == null || t.due!.compareTo(dayKey(now)) <= 0) &&
                widget.tasks.ready(t),
          )
          .length;
      return ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          Text(
            MaterialLocalizations.of(context).formatFullDate(now),
            style: theme.textTheme.labelLarge,
          ),
          Text('Today', style: theme.textTheme.displayMedium),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: [colors.primaryContainer, colors.secondaryContainer],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  next == null
                      ? Icons.event_available_outlined
                      : Icons.timelapse,
                  color: colors.onPrimaryContainer,
                ),
                const SizedBox(height: 18),
                Text(
                  next == null
                      ? 'Open time'
                      : next.start <= minute
                      ? 'Happening now'
                      : 'Up next',
                  style: theme.textTheme.labelLarge,
                ),
                Text(
                  next?.title ??
                      (blocks.isEmpty
                          ? 'Plan your day'
                          : 'Your schedule is clear'),
                  style: theme.textTheme.headlineMedium,
                ),
                if (next != null) Text(intervalLabel(next.start, next.end)),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: widget.onCalendar,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: const Text('Open calendar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.checklist_rounded),
              title: const Text('My tasks'),
              subtitle: Text('$ready ready to start'),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.onTasks,
            ),
          ),
          const SizedBox(height: 20),
          Text('Day timeline', style: theme.textTheme.titleLarge),
          if (blocks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No activities scheduled for today.'),
            ),
          for (final block in blocks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text(clockLabel(block.start)),
              title: Text(block.title),
              subtitle: Text(
                '${block.end - block.start} min · ${block.kind.name}',
              ),
              trailing: block == next ? const Icon(Icons.timelapse) : null,
            ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.mood_outlined),
            title: const Text('Daily check-in'),
            subtitle: Text(mood ?? 'How are you feeling?'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: saving ? null : checkIn,
          ),
        ],
      );
    },
  );
}
