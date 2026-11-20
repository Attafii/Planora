import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../focus/focus_store.dart';
import '../focus/pages.dart';

/// Shared home surface. Other branches inject their task/schedule sections here.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.store,
    required this.onFocus,
    required this.onReminders,
    this.sections = const [],
    this.tools,
  });
  final FocusStore store;
  final VoidCallback onFocus, onReminders;
  final List<Widget> sections;
  final Widget? tools;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime selected = DateTime.now();
  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final today = DateUtils.isSameDay(selected, s.now);
    final minutes =
        s.sessions
            .where((x) => DateUtils.isSameDay(x.created, selected))
            .fold<int>(0, (n, x) => n + x.elapsed(s.now)) ~/
        60;
    final reminders =
        s.reminders
            .where(
              (r) => r.enabled && DateUtils.isSameDay(r.next(s.now), selected),
            )
            .toList()
          ..sort((a, b) => a.when.compareTo(b.when));
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
      children: [
        Row(
          children: [
            Image.asset(
              'assets/branding/identity-source/approved-logo.png',
              width: 114,
              height: 42,
              fit: BoxFit.contain,
            ),
            const Spacer(),
            IconButton.filledTonal(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => InboxPage(store: s)),
              ),
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ],
        ),
        if (widget.tools != null) ...[
          const SizedBox(height: 16),
          widget.tools!,
        ],
        const SizedBox(height: 28),
        Text(
          today ? 'Make room\nfor your day.' : 'A little space\nto plan ahead.',
          style: Theme.of(context).textTheme.headlineLarge
              ?.copyWith(height: 1.15),
        ),
        const SizedBox(height: 10),
        Text(
          '${dayLabel(selected)} · One thing at a time.',
          style: const TextStyle(color: Color(0xFF637083), height: 1.5),
        ),
        const SizedBox(height: 24),
        Row(
          children: List.generate(7, (i) {
            final start = s.now.subtract(Duration(days: s.now.weekday - 1));
            final d = DateTime(start.year, start.month, start.day + i);
            final chosen = DateUtils.isSameDay(d, selected);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => setState(() => selected = d),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: chosen ? ink : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Text(
                          ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                          style: TextStyle(
                            fontSize: 12,
                            color: chosen ? Colors.white70 : Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: chosen ? Colors.white : ink,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: DateUtils.isSameDay(d, s.now)
                                ? teal
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.spa_outlined, color: teal),
                  SizedBox(width: 8),
                  Text(
                    'A MOMENT OF FOCUS',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                s.active != null
                    ? 'Pick up where\nyou left off.'
                    : 'Small steps.\nSteady progress.',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  color: Colors.white,
                  fontSize: 27,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                s.active?.title ?? 'Give one thing your full attention.',
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDCF7EE),
                  foregroundColor: ink,
                ),
                onPressed: widget.onFocus,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  s.active != null
                      ? 'Return to focus'
                      : 'Start a focus session',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Metric(
                value: '$minutes min',
                label: 'Focused ${today ? 'today' : 'that day'}',
                icon: Icons.timelapse,
                color: const Color(0xFFEAF2FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Metric(
                value: '${reminders.length}',
                label: 'Reminders',
                icon: Icons.notifications_none,
                color: const Color(0xFFF0EAFF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        sectionTitle(
          context,
          'Your reminders',
          action: 'See all',
          onTap: widget.onReminders,
        ),
        if (reminders.isEmpty)
          const EmptyPanel(
            icon: Icons.wb_twilight_outlined,
            title: 'A little breathing room',
            body: 'No reminders for this day. Add one when you need a gentle nudge.',
          )
        else
          ...reminders.map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F8F3),
                child: Icon(Icons.notifications_none, color: ink),
              ),
              title: Text(r.title),
              subtitle: Text('${timeLabel(r.next(s.now))} · ${r.repeat}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => editReminder(context, s, r),
            ),
          ),
        ...widget.sections,
      ],
    );
  }
}
