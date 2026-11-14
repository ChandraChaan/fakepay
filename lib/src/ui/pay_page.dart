import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../pay_channel.dart';
import '../scenarios.dart';
import '../store.dart';
import '../upi_request.dart';
import 'widgets.dart';

/// The screen a developer's app lands on after firing a `upi://pay` intent.
class PayApp extends StatelessWidget {
  const PayApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FakePay',
        debugShowCheckedModeBanner: false,
        theme: fakePayTheme(Brightness.light),
        darkTheme: fakePayTheme(Brightness.dark),
        home: const PayPage(),
      );
}

class PayPage extends StatefulWidget {
  const PayPage({super.key});

  @override
  State<PayPage> createState() => _PayPageState();
}

class _PayPageState extends State<PayPage> {
  final _store = FakePayStore();
  final _rng = Random();

  UpiRequest? _req;
  String _choice = ModeIds.random;
  int _delay = 0;
  bool _auto = false;
  bool _responding = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final req = await PayChannel.getRequest();
    final mode = await _store.getMode();
    final delay = await _store.getDelaySeconds();

    // Per-request override from the URI wins over the saved mode.
    final overrideId = req.scenarioOverride;
    final overrideValid = overrideId == ModeIds.random ||
        scenarioFor(overrideId) != null;
    final effective = overrideValid ? overrideId! : mode;

    if (!mounted) return;
    setState(() {
      _req = req;
      _delay = req.delayOverride ?? delay;
      _choice = effective == ModeIds.ask ? ModeIds.random : effective;
      _auto = effective != ModeIds.ask;
    });
    if (_auto) {
      // Keep the screen visible for a moment so it is clear FakePay answered.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _respond();
    }
  }

  Future<void> _respond() async {
    final req = _req;
    if (req == null || _responding) return;
    setState(() => _responding = true);

    final scenario = _choice == ModeIds.random
        ? randomScenario(_rng)
        : scenarioById[_choice]!;

    if (_delay < 0) {
      setState(() => _status = 'Not answering on purpose. Press back to cancel.');
      return;
    }
    if (_delay > 0) {
      for (var left = _delay; left > 0; left--) {
        if (!mounted) return;
        setState(() => _status = 'Answering "${scenario.title}" in ${left}s…');
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }

    final outcome = scenario.build(req, _rng);
    await _store.addHistory(HistoryEntry(
      time: DateTime.now(),
      uri: req.rawUri,
      scenarioId: scenario.id,
      scenarioTitle: scenario.title,
      outcome: outcome.describe(),
      callingPackage: req.callingPackage,
    ));
    await PayChannel.finish(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final req = _req;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('FakePay'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Chip(label: Text('TEST MODE'), visualDensity: VisualDensity.compact),
          ),
        ],
      ),
      body: req == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                _Summary(req: req),
                _Warnings(warnings: req.validate()),
                if (_auto || _responding)
                  _StatusCard(
                    text: _status ??
                        (_auto
                            ? 'Auto-responding (${scenarioFor(_choice)?.title ?? 'Random'})…'
                            : 'Responding…'),
                  )
                else ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text('Respond after'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DelayChips(
                        value: _delay,
                        onChanged: (d) => setState(() => _delay = d)),
                  ),
                  ScenarioList(
                    selected: _choice,
                    onChanged: (id) => setState(() => _choice = id),
                  ),
                ],
                _RawParams(req: req, color: cs.surfaceContainerHighest),
              ],
            ),
      bottomNavigationBar: (req == null || _auto || _responding)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => PayChannel.finish(
                            scenarioById['cancelled']!.build(req, _rng)),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _respond,
                        child: const Text('Send response'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.req});
  final UpiRequest req;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final amount = req.amount;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paying', style: t.labelMedium),
          Text(req.payeeName ?? '(no payee name)', style: t.titleLarge),
          Text(req.payeeVpa ?? '(no UPI ID)', style: t.bodyMedium),
          const SizedBox(height: 12),
          Text(amount == null ? 'Amount not set' : '₹ $amount',
              style: t.displaySmall),
          if (req.note != null) Text('Note: ${req.note}'),
          if (req.callingPackage != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('From ${req.callingPackage}', style: t.bodySmall),
            ),
        ],
      ),
    );
  }
}

class _Warnings extends StatelessWidget {
  const _Warnings({required this.warnings});
  final List<RequestWarning> warnings;

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Icon(Icons.check_circle_outline, size: 18),
          SizedBox(width: 8),
          Text('Request looks valid'),
        ]),
      );
    }
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request check', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            for (final w in warnings)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      switch (w.level) {
                        WarningLevel.error => Icons.error_outline,
                        WarningLevel.warning => Icons.warning_amber,
                        WarningLevel.info => Icons.info_outline,
                      },
                      size: 18,
                      color: switch (w.level) {
                        WarningLevel.error => cs.error,
                        WarningLevel.warning => cs.tertiary,
                        WarningLevel.info => cs.outline,
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(w.message)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ]),
        ),
      );
}

class _RawParams extends StatelessWidget {
  const _RawParams({required this.req, required this.color});
  final UpiRequest req;
  final Color color;

  @override
  Widget build(BuildContext context) => ExpansionTile(
        title: const Text('Raw request'),
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(8)),
            child: SelectableText(
              req.rawUri,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      );
}
