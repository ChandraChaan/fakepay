import 'package:flutter/material.dart';

import '../scenarios.dart';
import '../store.dart';

ThemeData fakePayTheme(Brightness b) => ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF0E7490),
      brightness: b,
    );

const delayOptions = <int>[0, 3, 10, 30, -1];

String delayLabel(int s) => s < 0 ? 'Never' : (s == 0 ? 'Instant' : '${s}s');

/// Pick one scenario (or a mode such as "Ask every time").
class ScenarioList extends StatelessWidget {
  const ScenarioList({
    super.key,
    required this.selected,
    required this.onChanged,
    this.includeAsk = false,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  /// Home screen only: lets the user choose "Ask every time".
  final bool includeAsk;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    Widget tile(String id, String title, String subtitle) {
      final isSel = id == selected;
      final cs = Theme.of(context).colorScheme;
      return ListTile(
        dense: true,
        selected: isSel,
        selectedTileColor: cs.primaryContainer.withValues(alpha: .5),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: isSel ? Icon(Icons.check_circle, color: cs.primary) : null,
        onTap: () => onChanged(id),
      );
    }

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(text,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.primary)),
        );

    if (includeAsk) {
      children.add(tile(ModeIds.ask, 'Ask every time',
          'Show the payment screen and let me pick'));
    }
    children.add(
        tile(ModeIds.random, 'Random', 'Pick any scenario below at random'));

    const groups = {
      ScenarioGroup.success: 'Success',
      ScenarioGroup.failure: 'Failure',
      ScenarioGroup.edge: 'Edge cases your app should survive',
    };
    for (final g in ScenarioGroup.values) {
      children.add(header(groups[g]!));
      for (final s in scenarios.where((s) => s.group == g)) {
        children.add(tile(s.id, s.title, s.subtitle));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

class DelayChips extends StatelessWidget {
  const DelayChips({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        children: [
          for (final d in delayOptions)
            ChoiceChip(
              label: Text(delayLabel(d)),
              selected: d == value,
              onSelected: (_) => onChanged(d),
            ),
        ],
      );
}
