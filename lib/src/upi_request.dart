/// A parsed `upi://pay` request plus lint warnings about it.
class UpiRequest {
  UpiRequest({
    required this.rawUri,
    required this.params,
    this.callingPackage,
  });

  /// Lenient parser: real UPI apps accept sloppy URIs, so this never throws.
  factory UpiRequest.parse(String uri, {String? callingPackage}) {
    final params = <String, String>{};
    final q = uri.indexOf('?');
    if (q >= 0) {
      for (final part in uri.substring(q + 1).split('&')) {
        if (part.isEmpty) continue;
        final eq = part.indexOf('=');
        final key = eq < 0 ? part : part.substring(0, eq);
        final value = eq < 0 ? '' : part.substring(eq + 1);
        params[_decode(key).toLowerCase()] = _decode(value);
      }
    }
    return UpiRequest(
      rawUri: uri,
      params: params,
      callingPackage: callingPackage,
    );
  }

  final String rawUri;

  /// Query parameters with lower-cased keys.
  final Map<String, String> params;
  final String? callingPackage;

  static String _decode(String s) {
    try {
      return Uri.decodeQueryComponent(s);
    } catch (_) {
      return s;
    }
  }

  String? _get(String k) {
    final v = params[k];
    return (v == null || v.isEmpty) ? null : v;
  }

  String? get payeeVpa => _get('pa');
  String? get payeeName => _get('pn');
  String? get amount => _get('am');
  String? get currency => _get('cu');
  String? get note => _get('tn');
  String? get txnRef => _get('tr');
  String? get txnId => _get('tid');
  String? get merchantCode => _get('mc');

  /// Developer override: `fakepay=<scenario id>` in the URI picks the answer
  /// without any tapping. Real UPI apps ignore unknown parameters.
  String? get scenarioOverride => _get('fakepay');

  /// Developer override: `fakepay_delay=<seconds>`.
  int? get delayOverride => int.tryParse(params['fakepay_delay'] ?? '');

  /// Parameters to show in the UI (without FakePay's own control parameters).
  Map<String, String> get displayParams => {
        for (final e in params.entries)
          if (e.key != 'fakepay' && e.key != 'fakepay_delay') e.key: e.value,
      };

  static final _vpa = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$');
  static final _amount = RegExp(r'^\d+(\.\d{1,2})?$');

  /// Things a strict UPI app (or the bank behind it) would likely reject.
  List<RequestWarning> validate() {
    final w = <RequestWarning>[];
    final pa = payeeVpa;
    if (pa == null) {
      w.add(const RequestWarning(
          WarningLevel.error, 'pa (payee address) is missing'));
    } else if (!_vpa.hasMatch(pa)) {
      w.add(RequestWarning(
          WarningLevel.error, 'pa "$pa" is not a valid UPI ID (name@bank)'));
    }
    if (payeeName == null) {
      w.add(const RequestWarning(
          WarningLevel.error, 'pn (payee name) is missing'));
    }
    final am = amount;
    if (am == null) {
      w.add(const RequestWarning(WarningLevel.info,
          'am (amount) is missing: user will be asked to type one'));
    } else if (!_amount.hasMatch(am)) {
      w.add(RequestWarning(WarningLevel.error,
          'am "$am" must be a plain decimal with at most 2 places'));
    } else if (double.parse(am) <= 0) {
      w.add(const RequestWarning(WarningLevel.error, 'am must be above 0'));
    }
    final cu = currency;
    if (cu == null) {
      w.add(const RequestWarning(
          WarningLevel.warning, 'cu (currency) is missing, should be INR'));
    } else if (cu != 'INR') {
      w.add(RequestWarning(
          WarningLevel.error, 'cu "$cu" is not INR; UPI only supports INR'));
    }
    if (txnRef == null) {
      w.add(const RequestWarning(WarningLevel.warning,
          'tr (transaction reference) is missing; you cannot match the response'));
    }
    if (note != null && note!.length > 80) {
      w.add(RequestWarning(WarningLevel.warning,
          'tn (note) is ${note!.length} characters; apps often cut at 50 to 80'));
    }
    if (merchantCode == null) {
      w.add(const RequestWarning(WarningLevel.info,
          'mc (merchant code) is missing; fine for person-to-person only'));
    }
    return w;
  }
}

enum WarningLevel { error, warning, info }

class RequestWarning {
  const RequestWarning(this.level, this.message);
  final WarningLevel level;
  final String message;
}
