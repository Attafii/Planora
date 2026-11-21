import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';

/// Values come from server record aggregation, never from generated AI text.
class MessageChart extends StatelessWidget {
  const MessageChart({super.key, required this.data});
  final JsonMap data;
  @override
  Widget build(BuildContext context) {
    final items = ((data['items'] as List?) ?? []).cast<JsonMap>();
    final maxValue = items.fold<double>(
      1,
      (value, row) => math.max(value, (row['value'] as num).toDouble()),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['title'] as String,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final row in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Semantics(
                label: '${row['label']}: ${row['value']} ${data['unit']}',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${(row['label'] as String).replaceAll('_', ' ')}: ${row['value']}',
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: (row['value'] as num).toDouble() / maxValue,
                      minHeight: 8,
                    ),
                  ],
                ),
              ),
            ),
          Text(
            '${data['source']} · ${data['generated_at']}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
