import 'dart:math';

import 'package:fakepay/src/scenarios.dart';
import 'package:fakepay/src/upi_request.dart';
import 'package:flutter_test/flutter_test.dart';

const _good =
    'upi://pay?pa=shop@upi&pn=Test%20Shop&am=10.00&cu=INR&tr=T123&tn=Order%201&mc=5411';

void main() {
  group('UpiRequest', () {
    test('parses and decodes parameters', () {
      final r = UpiRequest.parse(_good);
      expect(r.payeeVpa, 'shop@upi');
      expect(r.payeeName, 'Test Shop');
      expect(r.amount, '10.00');
      expect(r.txnRef, 'T123');
      expect(r.validate().where((w) => w.level != WarningLevel.info), isEmpty);
    });

    test('keys are case-insensitive and sloppy URIs do not throw', () {
      final r = UpiRequest.parse('upi://pay?PA=a@b&pn=Big Shop&am=5&%zz=1&&x');
      expect(r.payeeVpa, 'a@b');
      expect(r.payeeName, 'Big Shop');
    });

    test('flags the mistakes real apps reject', () {
      final r = UpiRequest.parse('upi://pay?pa=nobank&am=1.234&cu=USD');
      final msgs = r.validate().map((w) => w.message).join('|');
      expect(msgs, contains('not a valid UPI ID'));
      expect(msgs, contains('pn (payee name) is missing'));
      expect(msgs, contains('at most 2 places'));
      expect(msgs, contains('not INR'));
      expect(msgs, contains('tr (transaction reference)'));
    });

    test('control parameters are hidden from display and read as overrides', () {
      final r = UpiRequest.parse('$_good&fakepay=failure_u16&fakepay_delay=3');
      expect(r.scenarioOverride, 'failure_u16');
      expect(r.delayOverride, 3);
      expect(r.displayParams.containsKey('fakepay'), isFalse);
      expect(r.displayParams.containsKey('fakepay_delay'), isFalse);
    });
  });

  group('scenarios', () {
    final req = UpiRequest.parse(_good);
    final rng = Random(1);

    test('ids are unique', () {
      expect(scenarioById.length, scenarios.length);
    });

    test('success carries SUCCESS, 00 and the original txnRef', () {
      final o = scenarioById['success']!.build(req, rng);
      expect(o.ok, isTrue);
      expect(o.response, contains('Status=SUCCESS'));
      expect(o.response, contains('responseCode=00'));
      expect(o.response, contains('txnRef=T123'));
      expect(o.response, contains('ApprovalRefNo='));
    });

    test('failures use their response codes', () {
      for (final e in {
        'failure_u30': 'U30',
        'failure_funds': 'Z9',
        'failure_mpin': 'ZM',
        'failure_risk': 'U16',
      }.entries) {
        final o = scenarioById[e.key]!.build(req, rng);
        expect(o.response, contains('Status=FAILURE'));
        expect(o.response, contains('responseCode=${e.value}'));
      }
    });

    test('cancelled is RESULT_CANCELED with no data', () {
      final o = scenarioById['cancelled']!.build(req, rng);
      expect(o.ok, isFalse);
      expect(o.hasData, isFalse);
    });

    test('edge cases behave as described', () {
      expect(scenarioById['no_data']!.build(req, rng).hasData, isFalse);
      expect(scenarioById['empty_response']!.build(req, rng).response, '');
      final extras = scenarioById['extras_only']!.build(req, rng);
      expect(extras.response, isNull);
      expect(extras.extras['Status'], 'SUCCESS');
      final lower = scenarioById['success_lowercase']!.build(req, rng);
      expect(lower.response, contains('status=success'));
      final wrong = scenarioById['success_wrong_ref']!.build(req, rng);
      expect(wrong.response, isNot(contains('txnRef=T123')));
      final none = scenarioById['success_no_ref']!.build(req, rng);
      expect(none.response, isNot(contains('txnRef')));
    });

    test('every scenario builds without throwing, even for an empty request', () {
      final empty = UpiRequest.parse('');
      for (final s in scenarios) {
        expect(() => s.build(empty, rng), returnsNormally, reason: s.id);
      }
    });
  });
}
