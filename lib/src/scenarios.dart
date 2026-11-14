import 'dart:math';

import 'upi_request.dart';

/// What FakePay hands back to the calling app.
class UpiOutcome {
  const UpiOutcome({
    required this.ok,
    this.response,
    this.extras = const {},
  });

  /// RESULT_OK when true, RESULT_CANCELED when false.
  final bool ok;

  /// Value of the `response` string extra, null to leave it out.
  final String? response;

  /// Extra string extras returned next to (or instead of) `response`.
  final Map<String, String> extras;

  bool get hasData => response != null || extras.isNotEmpty;

  String describe() {
    final code = ok ? 'RESULT_OK' : 'RESULT_CANCELED';
    if (!hasData) return '$code, no data (Intent is null)';
    final parts = <String>[
      if (response != null) 'response="$response"',
      for (final e in extras.entries) '${e.key}="${e.value}"',
    ];
    return '$code, ${parts.join(', ')}';
  }
}

class Scenario {
  const Scenario(this.id, this.title, this.subtitle, this.group, this.build);

  final String id;
  final String title;
  final String subtitle;
  final ScenarioGroup group;
  final UpiOutcome Function(UpiRequest req, Random rng) build;
}

enum ScenarioGroup { success, failure, edge }

String _digits(Random rng, int n) =>
    List.generate(n, (_) => rng.nextInt(10)).join();

String _txnId(Random rng) => 'FPY${_digits(rng, 16)}';

/// Builds the classic `key=value&key=value` response string.
String _response(
  Random rng,
  UpiRequest req, {
  required String status,
  String? code,
  bool lowerKeys = false,
  bool includeRef = true,
  String? refOverride,
}) {
  String k(String key) => lowerKeys ? key.toLowerCase() : key;
  final parts = <String>[
    '${k('txnId')}=${_txnId(rng)}',
    if (code != null) '${k('responseCode')}=$code',
    '${k('Status')}=${lowerKeys ? status.toLowerCase() : status}',
    if (includeRef && (refOverride ?? req.txnRef) != null)
      '${k('txnRef')}=${refOverride ?? req.txnRef}',
  ];
  return parts.join('&');
}

UpiOutcome _fail(Random rng, UpiRequest req, String code) => UpiOutcome(
      ok: true,
      response: _response(rng, req, status: 'FAILURE', code: code),
    );

/// Every answer FakePay can give. Order here is the order in the UI.
final List<Scenario> scenarios = [
  Scenario(
    'success',
    'Success',
    'Status=SUCCESS, responseCode=00',
    ScenarioGroup.success,
    (req, rng) => UpiOutcome(
      ok: true,
      response: '${_response(rng, req, status: 'SUCCESS', code: '00')}'
          '&ApprovalRefNo=${_digits(rng, 12)}',
    ),
  ),
  Scenario(
    'pending',
    'Submitted (pending)',
    'Status=SUBMITTED, final result not known yet',
    ScenarioGroup.success,
    (req, rng) =>
        UpiOutcome(ok: true, response: _response(rng, req, status: 'SUBMITTED')),
  ),
  Scenario(
    'failure_u30',
    'Debit failed (U30)',
    'Status=FAILURE, responseCode=U30',
    ScenarioGroup.failure,
    (req, rng) => _fail(rng, req, 'U30'),
  ),
  Scenario(
    'failure_funds',
    'Insufficient funds (Z9)',
    'Status=FAILURE, responseCode=Z9',
    ScenarioGroup.failure,
    (req, rng) => _fail(rng, req, 'Z9'),
  ),
  Scenario(
    'failure_mpin',
    'Wrong UPI PIN (ZM)',
    'Status=FAILURE, responseCode=ZM',
    ScenarioGroup.failure,
    (req, rng) => _fail(rng, req, 'ZM'),
  ),
  Scenario(
    'failure_risk',
    'Risk threshold exceeded (U16)',
    'Status=FAILURE, responseCode=U16',
    ScenarioGroup.failure,
    (req, rng) => _fail(rng, req, 'U16'),
  ),
  Scenario(
    'cancelled',
    'User cancelled',
    'RESULT_CANCELED, no data',
    ScenarioGroup.failure,
    (req, rng) => const UpiOutcome(ok: false),
  ),
  Scenario(
    'success_lowercase',
    'Success with lowercase keys',
    'status=success&txnid=…: apps differ in casing',
    ScenarioGroup.edge,
    (req, rng) => UpiOutcome(
      ok: true,
      response:
          _response(rng, req, status: 'SUCCESS', code: '00', lowerKeys: true),
    ),
  ),
  Scenario(
    'success_wrong_ref',
    'Success with a different txnRef',
    'Your app should notice the reference does not match',
    ScenarioGroup.edge,
    (req, rng) => UpiOutcome(
      ok: true,
      response: _response(rng, req,
          status: 'SUCCESS', code: '00', refOverride: 'OTHER${_digits(rng, 6)}'),
    ),
  ),
  Scenario(
    'success_no_ref',
    'Success without txnRef',
    'Some apps drop the reference',
    ScenarioGroup.edge,
    (req, rng) => UpiOutcome(
      ok: true,
      response: _response(rng, req,
          status: 'SUCCESS', code: '00', includeRef: false),
    ),
  ),
  Scenario(
    'extras_only',
    'Extras only, no "response"',
    'Status/txnId as separate extras, response key absent',
    ScenarioGroup.edge,
    (req, rng) => UpiOutcome(
      ok: true,
      extras: {
        'Status': 'SUCCESS',
        'txnId': _txnId(rng),
        'responseCode': '00',
        if (req.txnRef != null) 'txnRef': req.txnRef!,
      },
    ),
  ),
  Scenario(
    'no_data',
    'RESULT_OK with no data',
    'The result Intent is null',
    ScenarioGroup.edge,
    (req, rng) => const UpiOutcome(ok: true),
  ),
  Scenario(
    'empty_response',
    'Empty response string',
    'response="" with RESULT_OK',
    ScenarioGroup.edge,
    (req, rng) => const UpiOutcome(ok: true, response: ''),
  ),
  Scenario(
    'malformed',
    'Malformed response',
    'Garbage that is not key=value pairs',
    ScenarioGroup.edge,
    (req, rng) => const UpiOutcome(
      ok: true,
      response: 'Status=&&=SUCCESS%txnId;;responseCode',
    ),
  ),
];

final Map<String, Scenario> scenarioById = {
  for (final s in scenarios) s.id: s,
};

Scenario? scenarioFor(String? id) => id == null ? null : scenarioById[id];

/// A random pick from every scenario (used by the "Random" mode).
Scenario randomScenario(Random rng) => scenarios[rng.nextInt(scenarios.length)];
