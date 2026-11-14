import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../scenarios.dart';
import '../store.dart';
import 'widgets.dart';

const _adbExample =
    'adb shell \'am start -n com.chandrachaan.fakepay/.PayActivity '
    '-a android.intent.action.VIEW -d '
    '"upi://pay?pa=shop@upi&pn=Test%20Shop&am=10.00&cu=INR&tr=T1&fakepay=success"\'';

class HomeApp extends StatelessWidget {
  const HomeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FakePay',
        debugShowCheckedModeBanner: false,
        theme: fakePayTheme(Brightness.light),
        darkTheme: fakePayTheme(Brightness.dark),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _store = FakePayStore();
  String _mode = ModeIds.ask;
  int _delay = 0;
  List<HistoryEntry> _history = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The payment screen runs in another engine; refresh when we come back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final mode = await _store.getMode();
    final delay = await _store.getDelaySeconds();
    final history = await _store.getHistory();
    if (!mounted) return;
    setState(() {
      _mode = scenarioFor(mode) != null ||
              mode == ModeIds.random ||
              mode == ModeIds.ask
          ? mode
          : ModeIds.ask;
      _delay = delay;
      _history = history;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('FakePay'),
        actions: [
          IconButton(
            tooltip: 'Request history',
            icon: Badge(
              isLabelVisible: _history.isNotEmpty,
              label: Text('${_history.length}'),
              child: const Icon(Icons.history),
            ),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => HistoryPage(store: _store),
              ));
              _load();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('A UPI app that moves no money', style: t.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  'When your app fires a upi://pay intent, FakePay appears in '
                  'the chooser and answers with whatever result you pick. '
                  'Nothing is sent to any bank. It has no internet permission.',
                ),
              ],
            ),
          ),
          const _SectionTitle('When a payment request arrives'),
          ScenarioList(
            includeAsk: true,
            selected: _mode,
            onChanged: (id) async {
              setState(() => _mode = id);
              await _store.setMode(id);
            },
          ),
          const _SectionTitle('Respond after'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DelayChips(
              value: _delay,
              onChanged: (d) async {
                setState(() => _delay = d);
                await _store.setDelaySeconds(d);
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '"Never" leaves the screen open until you press back, which '
              'returns RESULT_CANCELED. Use it to test timeouts.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const _SectionTitle('Control it from your app or tests'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add fakepay=<scenario> (and optionally fakepay_delay=<seconds>) '
                  'to the UPI link in debug builds. It beats the setting above, '
                  'and real UPI apps ignore unknown parameters.',
                ),
                const SizedBox(height: 8),
                Text('Scenario ids: random, ${scenarios.map((s) => s.id).join(', ')}',
                    style: t.bodySmall),
                const SizedBox(height: 12),
                _CodeBox(text: _adbExample),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied')));
                },
              ),
            ),
          ],
        ),
      );
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.store});
  final FakePayStore store;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<HistoryEntry> _items = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final h = await widget.store.getHistory();
    if (mounted) setState(() => _items = h);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Request history'),
          actions: [
            if (_items.isNotEmpty)
              IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await widget.store.clearHistory();
                  _refresh();
                },
              ),
          ],
        ),
        body: _items.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Nothing yet. Every request FakePay answers shows up here '
                    'with the exact link your app sent and what came back.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final e = _items[i];
                  final time = TimeOfDay.fromDateTime(e.time).format(context);
                  return ExpansionTile(
                    title: Text(e.scenarioTitle),
                    subtitle: Text(
                        '$time${e.callingPackage == null ? '' : ' · ${e.callingPackage}'}'),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Request',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      SelectableText(e.uri,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12)),
                      const SizedBox(height: 8),
                      const Text('Returned',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      SelectableText(e.outcome,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12)),
                    ],
                  );
                },
              ),
      );
}
