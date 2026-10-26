import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/widgets/product_widgets.dart';
import '../models/achievement.dart';

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});
  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  String _filter = 'all';
  @override
  Widget build(BuildContext context) => ProductPage(
    title: 'Small, meaningful challenges',
    subtitle: 'Choose an outcome that fits your week.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in {
              'all': 'All',
              'available': 'Available',
              'active': 'Active',
              'completed': 'Completed',
              'expired': 'Expired',
            }.entries)
              ChoiceChip(
                label: Text(f.value),
                selected: _filter == f.key,
                onSelected: (_) => setState(() => _filter = f.key),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: AsyncView<List<Challenge>>(
            load: () => AppScope.of(context).gamification.challenges(),
            builder: (ctx, items, refresh) {
              final list = items
                  .where((c) => _filter == 'all' || c.status == _filter)
                  .toList();
              if (list.isEmpty) {
                return const StateMessage(
                  title: 'No challenges in this view',
                  message: 'Choose another filter to find a challenge that fits your week.',
                );
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  for (final c in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Surface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 10),
                            Text(c.description),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              children: [
                                StatusChip(c.status),
                                if (c.expiresAt != null)
                                  StatusChip(
                                    'Until ${readableDate(c.expiresAt)}',
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ProgressMeter(
                              (c.progress / c.target * 100).round(),
                              label: '${c.progress} / ${c.target}',
                            ),
                            const SizedBox(height: 20),
                            OutlinedButton(
                              onPressed: () async {
                                await showModalBottomSheet<void>(
                                  context: context,
                                  useSafeArea: true,
                                  builder: (ctx) => Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(c.description),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Progress counts distinct verified events after joining. ${c.kind == 'focus_completed' ? 'Focus progress is supplied by the shared focus service.' : ''}',
                                        ),
                                        const SizedBox(height: 24),
                                        if (c.status == 'available')
                                          BusyButton(
                                            label: 'Join challenge',
                                            onPressed: () async {
                                              await AppScope.of(context)
                                                  .gamification
                                                  .join(c.id);
                                              if (context.mounted) {
                                                Navigator.pop(context);
                                              }
                                            },
                                          )
                                        else
                                          BusyButton(
                                            label: c.status == 'completed'
                                                ? 'Remove from my challenges'
                                                : 'Leave challenge',
                                            outlined: true,
                                            onPressed: () async {
                                              if (!await confirm(
                                                context,
                                                title: 'Leave this challenge?',
                                                message: 'Your completed work and achievements remain. Rejoining starts a new challenge period.',
                                                action: 'Leave',
                                              )) {
                                                return;
                                              }
                                              if (context.mounted) {
                                                await AppScope.of(context)
                                                    .gamification
                                                    .leave(c.id);
                                                if (context.mounted) {
                                                  Navigator.pop(context);
                                                }
                                              }
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                                refresh();
                              },
                              child: const Text('View challenge'),
                            ),
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
