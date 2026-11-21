import 'package:flutter/material.dart';

class DailyDock extends StatelessWidget {
  const DailyDock({
    super.key,
    required this.destinations,
    required this.selected,
    required this.onSelect,
  });

  final List<(IconData, String)> destinations;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final largeLabels = MediaQuery.textScalerOf(context).scale(12) > 16;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NavigationBar(
          height: largeLabels ? 48 : 66,
          elevation: 0,
          backgroundColor: Colors.transparent,
          animationDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : null,
          labelBehavior: largeLabels
              ? NavigationDestinationLabelBehavior.alwaysHide
              : NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: selected,
          onDestinationSelected: onSelect,
          destinations: [
            for (final (icon, label) in destinations)
              NavigationDestination(icon: Icon(icon), label: label),
          ],
        ),
        if (largeLabels)
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                destinations[selected].$2,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
