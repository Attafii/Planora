import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/product_widgets.dart';
import '../models/achievement.dart';
import 'challenges_page.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  String _filter = 'all';
  @override
  Widget build(BuildContext context) => ProductPage(
    title: 'Meaningful progress',
    subtitle: 'Consistency grows from work that matters.',
    embedded: widget.embedded,
    actions: [
      OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const ChallengesPage()),
        ),
        icon: const Icon(Icons.flag_outlined),
        label: const Text('Challenges'),
      ),
    ],
    child: AsyncView<GamificationSummary>(
      load: () => AppScope.of(context).gamification.summary(),
      builder: (ctx, s, refresh) => ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Surface(
            child: LayoutBuilder(
              builder: (ctx, c) => Wrap(
                spacing: 36,
                runSpacing: 24,
                children: [
                  SizedBox(
                    width: c.maxWidth < 650 ? c.maxWidth : 280,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Level ${s.level}',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 10),
                        Text('${s.points} points from earned achievements'),
                        const SizedBox(height: 20),
                        ProgressMeter(s.levelProgress, label: 'Next level'),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: c.maxWidth < 650 ? c.maxWidth : 280,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s.streak}',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const Text('qualifying weekdays in your streak'),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('How progress works'),
                              content: Text(
                                '${s.streakRule}\n\nEach earned badge awards its points once. A level is 100 points. Creating tasks alone does not earn points. Your profile timezone is ${AppScope.of(context).session.user!.timezone}.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Got it'),
                                ),
                              ],
                            ),
                          ),
                          child: const Text('Understand the rules'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in {
                'all': 'All badges',
                'earned': 'Earned',
                'next': 'In progress',
              }.entries)
                ChoiceChip(
                  label: Text(f.value),
                  selected: _filter == f.key,
                  onSelected: (_) => setState(() => _filter = f.key),
                ),
            ],
          ),
          const SizedBox(height: 24),
          for (final a in s.achievements.where(
            (a) =>
                _filter == 'all' ||
                (_filter == 'earned' ? a.earned : !a.earned),
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Surface(
                padding: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AchievementDetailPage(id: a.id),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BadgeMark(earned: a.earned),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(a.description),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 10,
                                children: [
                                  StatusChip(
                                    a.earned
                                        ? 'Earned'
                                        : '${a.progress} / ${a.target}',
                                  ),
                                  StatusChip('${a.points} points'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (!s.achievements.any((a) => a.earned) && _filter == 'earned')
            const StateMessage(
              title: 'Your first achievement is ahead',
              message: 'Complete meaningful work. Your achievements will update from confirmed activity.',
            ),
          const SizedBox(height: 8),
          const Text(
            'Focus and planning badges use verified events from the shared Focus and Calendar services.',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class BadgeMark extends StatelessWidget {
  const BadgeMark({super.key, required this.earned, this.size = 60});
  final bool earned;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: earned ? 'Achievement earned' : 'Achievement not yet earned',
    child: Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .2),
      decoration: BoxDecoration(
        color: earned ? AppColors.ink : AppColors.tint,
        borderRadius: BorderRadius.circular(size * .25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final e in [1.0, .75, .5].asMap().entries)
            Padding(
              padding: EdgeInsets.symmetric(vertical: size * .03),
              child: Container(
                width: size * .6 * e.value,
                height: size * .09,
                decoration: BoxDecoration(
                  color: earned
                      ? [
                          AppColors.teal,
                          AppColors.blue,
                          AppColors.violet,
                        ][e.key]
                      : AppColors.muted,
                  borderRadius: BorderRadius.circular(size),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class AchievementDetailPage extends StatelessWidget {
  const AchievementDetailPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => ProductPage(
    title: 'Achievement',
    child: AsyncView<Achievement>(
      load: () => AppScope.of(context).gamification.achievement(id),
      builder: (ctx, a, refresh) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BadgeMark(earned: a.earned, size: 100),
                const SizedBox(height: 28),
                Text(a.title, style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 12),
                Text(a.description),
                const SizedBox(height: 24),
                ProgressMeter(
                  (a.progress / a.target * 100).round(),
                  label: '${a.progress} / ${a.target} qualifying events',
                ),
                const SizedBox(height: 20),
                Text(
                  a.earned
                      ? 'Earned on ${readableDate(a.earnedAt)}'
                      : 'Progress is based on confirmed activity.',
                ),
                const SizedBox(height: 12),
                Text('${a.points} points when earned'),
                const Divider(),
                const Text(
                  'Your progress is personal. Rest days are part of the rhythm; there are no public rankings.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
