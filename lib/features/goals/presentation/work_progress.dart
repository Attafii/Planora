import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/widgets/product_widgets.dart';
import '../../planning/planning_engine.dart';
import '../../focus/pages.dart' show clock;

class WorkProgress extends StatelessWidget {
  const WorkProgress({
    super.key,
    required this.percent,
    required this.summary,
    this.checkedAt,
    this.taskIds = const {},
  });

  final int? percent;
  final String summary;
  final String? checkedAt;
  final Set<String> taskIds;

  @override
  Widget build(BuildContext context) {
    final work = AppScope.of(context).workActivity;
    final timestamp = DateTime.tryParse(checkedAt ?? '')?.toLocal();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (percent case final value?)
          ProgressMeter(value, label: 'Work completed'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(summary),
        ),
        if (timestamp != null)
          Text(
            'Checked ${MaterialLocalizations.of(context).formatShortDate(timestamp)} '
            '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(timestamp))}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (work != null && taskIds.isNotEmpty)
          ListenableBuilder(
            listenable: work.changes,
            builder: (context, _) {
              final slots = work.upcoming(taskIds).take(5).toList();
              final seconds = work.focusSeconds(taskIds);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    seconds > 0
                        ? 'Your recorded focus time · ${clock(seconds)}'
                        : 'No recorded focus time for this work.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    slots.isEmpty
                        ? 'No upcoming blocks in your calendar.'
                        : 'Upcoming in your calendar',
                  ),
                  for (final slot in slots)
                    Text(
                      '${slot.date} · ${intervalLabel(slot.block.start, slot.block.end)} · ${slot.block.title}',
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}
