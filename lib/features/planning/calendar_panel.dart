import 'package:flutter/material.dart';

import '../tasks/task_store.dart';
import 'planning_engine.dart';

enum CalendarView { month, week, day }

const firstCalendarYear = 1900;
const lastCalendarYear = 2100;

DateTime addCalendarDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

DateTime firstDateOfWeek(DateTime date, int firstWeekday) =>
    addCalendarDays(date, -((date.weekday % 7 - firstWeekday) % 7));

DateTime shiftCalendarDate(DateTime date, CalendarView view, int offset) {
  if (view == CalendarView.month) {
    final target = DateTime(date.year, date.month + offset);
    final lastDay = DateTime(target.year, target.month + 1, 0).day;
    return DateTime(target.year, target.month, date.day.clamp(1, lastDay));
  }
  return addCalendarDays(date, offset * (view == CalendarView.week ? 7 : 1));
}

IconData blockIcon(BlockKind kind) => switch (kind) {
  BlockKind.task => Icons.checklist_rounded,
  BlockKind.commitment => Icons.lock_outline_rounded,
  BlockKind.pause => Icons.coffee_outlined,
  BlockKind.unavailable => Icons.do_not_disturb_on_outlined,
};

String blockType(BlockKind kind) => switch (kind) {
  BlockKind.task => 'Task',
  BlockKind.commitment => 'Fixed commitment',
  BlockKind.pause => 'Break',
  BlockKind.unavailable => 'Unavailable',
};

Color blockColor(ColorScheme scheme, BlockKind kind) => switch (kind) {
  BlockKind.task => scheme.primaryContainer,
  BlockKind.commitment => scheme.tertiaryContainer,
  BlockKind.pause => scheme.secondaryContainer,
  BlockKind.unavailable => scheme.surfaceContainerHighest,
};

class CalendarPanel extends StatelessWidget {
  const CalendarPanel({
    super.key,
    required this.date,
    required this.view,
    required this.enabled,
    required this.blocksFor,
    required this.onDate,
    required this.onView,
    required this.onJump,
    this.today,
  });

  final DateTime date;
  final DateTime? today;
  final CalendarView view;
  final bool enabled;
  final List<PlanBlock> Function(String) blocksFor;
  final ValueChanged<DateTime> onDate;
  final ValueChanged<CalendarView> onView;
  final VoidCallback onJump;

  @override
  Widget build(BuildContext context) {
    final local = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final firstWeekday = local.firstDayOfWeekIndex;
    final monthStart = DateTime(date.year, date.month);
    final firstDate = firstDateOfWeek(
      view == CalendarView.month ? monthStart : date,
      firstWeekday,
    );
    final now = today ?? DateTime.now();
    final previous = shiftCalendarDate(date, view, -1);
    final next = shiftCalendarDate(date, view, 1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: enabled ? onJump : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        local.formatMonthYear(date),
                        style: theme.textTheme.titleLarge,
                      ),
                      const Icon(Icons.expand_more_rounded),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: enabled ? () => onDate(now) : null,
                      child: const Text('Today'),
                    ),
                    IconButton(
                      tooltip: 'Previous ${view.name}',
                      onPressed: enabled && previous.year >= firstCalendarYear
                          ? () => onDate(previous)
                          : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    IconButton(
                      tooltip: 'Next ${view.name}',
                      onPressed: enabled && next.year <= lastCalendarYear
                          ? () => onDate(next)
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 16),
              child: SegmentedButton<CalendarView>(
                segments: const [
                  ButtonSegment(
                    value: CalendarView.month,
                    label: Text('Month'),
                  ),
                  ButtonSegment(value: CalendarView.week, label: Text('Week')),
                  ButtonSegment(value: CalendarView.day, label: Text('Day')),
                ],
                showSelectedIcon: false,
                selected: {view},
                onSelectionChanged: enabled
                    ? (selection) => onView(selection.single)
                    : null,
              ),
            ),
            Row(
              children: [
                for (var index = 0; index < 7; index++)
                  Expanded(
                    child: Center(
                      child: Text(
                        local.narrowWeekdays[(firstWeekday + index) % 7],
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                final detailed =
                    constraints.maxWidth >= 460 || view == CalendarView.week;
                final rows = view == CalendarView.month
                    ? ((DateTime(date.year, date.month + 1, 0).day +
                                  (monthStart.weekday % 7 - firstWeekday) % 7) /
                              7)
                          .ceil()
                    : 1;
                return Column(
                  children: [
                    for (var row = 0; row < rows; row++)
                      Row(
                        children: [
                          for (var column = 0; column < 7; column++)
                            Expanded(
                              child: _DateCell(
                                day: addCalendarDays(
                                  firstDate,
                                  row * 7 + column,
                                ),
                                selection: date,
                                today: now,
                                blocksFor: blocksFor,
                                onDate: enabled ? onDate : null,
                                detailed: detailed,
                                showEntries: view != CalendarView.day,
                                tall: view == CalendarView.week,
                                offMonth:
                                    view == CalendarView.month &&
                                    addCalendarDays(
                                          firstDate,
                                          row * 7 + column,
                                        ).month !=
                                        date.month,
                              ),
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({
    required this.day,
    required this.selection,
    required this.today,
    required this.blocksFor,
    required this.onDate,
    required this.detailed,
    required this.showEntries,
    required this.tall,
    required this.offMonth,
  });
  final DateTime day, selection, today;
  final List<PlanBlock> Function(String) blocksFor;
  final ValueChanged<DateTime>? onDate;
  final bool detailed, showEntries, tall, offMonth;

  @override
  Widget build(BuildContext context) {
    final key = dayKey(day);
    final selected = key == dayKey(selection);
    final current = key == dayKey(today);
    final valid = day.year >= firstCalendarYear && day.year <= lastCalendarYear;
    final blocks = valid ? blocksFor(key) : const <PlanBlock>[];
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = MaterialLocalizations.of(context).formatFullDate(day);
    final VoidCallback? select = onDate == null || !valid
        ? null
        : () => onDate!(day);
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return Semantics(
      label: '$label${current ? ', today' : ''}, ${blocks.length} entries',
      selected: selected,
      button: true,
      excludeSemantics: true,
      onTap: select,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('calendar-$key'),
          borderRadius: BorderRadius.circular(10),
          onTap: select,
          child: Container(
            height:
                (tall
                    ? 108
                    : detailed && showEntries
                    ? 78
                    : 51) *
                scale.clamp(1.0, 3.0),
            margin: const EdgeInsets.all(1),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primaryContainer
                  : tall
                  ? scheme.surfaceContainerLow
                  : null,
              borderRadius: BorderRadius.circular(10),
              border: current ? Border.all(color: scheme.primary) : null,
            ),
            child: Column(
              children: [
                Text(
                  '${day.day}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected
                        ? scheme.onPrimaryContainer
                        : offMonth
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                    fontWeight: current || selected
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
                if (blocks.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  if (detailed && showEntries)
                    for (final block in blocks.take(tall ? 3 : 2))
                      Container(
                        alignment: AlignmentDirectional.centerStart,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 1,
                        ),
                        margin: const EdgeInsets.only(bottom: 1),
                        decoration: BoxDecoration(
                          color: blockColor(scheme, block.kind),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          block.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            height: 1.2,
                          ),
                        ),
                      )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final kind
                            in blocks
                                .map((block) => block.kind)
                                .toSet()
                                .take(3))
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: switch (kind) {
                                BlockKind.task => scheme.primary,
                                BlockKind.commitment => scheme.tertiary,
                                BlockKind.pause => scheme.secondary,
                                BlockKind.unavailable => scheme.outline,
                              },
                            ),
                          ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
