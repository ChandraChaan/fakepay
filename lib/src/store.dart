import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// How FakePay decides what to answer.
class ModeIds {
  static const ask = 'ask';
  static const random = 'random';
}

class HistoryEntry {
  HistoryEntry({
    required this.time,
    required this.uri,
    required this.scenarioId,
    required this.scenarioTitle,
    required this.outcome,
    this.callingPackage,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        time: DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
        uri: j['u'] as String,
        scenarioId: j['s'] as String,
        scenarioTitle: j['st'] as String,
        outcome: j['o'] as String,
        callingPackage: j['p'] as String?,
      );

  final DateTime time;
  final String uri;
  final String scenarioId;
  final String scenarioTitle;
  final String outcome;
  final String? callingPackage;

  Map<String, dynamic> toJson() => {
        't': time.millisecondsSinceEpoch,
        'u': uri,
        's': scenarioId,
        'st': scenarioTitle,
        'o': outcome,
        'p': callingPackage,
      };
}

/// Settings and request history. Both the home screen and the payment screen
/// run in separate Flutter engines, so every read reloads from disk first.
class FakePayStore {
  static const _kMode = 'mode';
  static const _kDelay = 'delay';
  static const _kHistory = 'history';
  static const maxHistory = 50;

  Future<SharedPreferences> _prefs() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    return p;
  }

  Future<String> getMode() async =>
      (await _prefs()).getString(_kMode) ?? ModeIds.ask;

  Future<void> setMode(String mode) async =>
      (await _prefs()).setString(_kMode, mode);

  Future<int> getDelaySeconds() async =>
      (await _prefs()).getInt(_kDelay) ?? 0;

  Future<void> setDelaySeconds(int s) async =>
      (await _prefs()).setInt(_kDelay, s);

  Future<List<HistoryEntry>> getHistory() async {
    final raw = (await _prefs()).getStringList(_kHistory) ?? const [];
    final out = <HistoryEntry>[];
    for (final s in raw) {
      try {
        out.add(HistoryEntry.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {
        // Skip corrupt rows.
      }
    }
    return out;
  }

  Future<void> addHistory(HistoryEntry e) async {
    final p = await _prefs();
    final list = [jsonEncode(e.toJson()), ...?p.getStringList(_kHistory)];
    await p.setStringList(_kHistory, list.take(maxHistory).toList());
  }

  Future<void> clearHistory() async => (await _prefs()).remove(_kHistory);
}
