import 'package:flutter/services.dart';

import 'scenarios.dart';
import 'upi_request.dart';

/// Talks to the native PayActivity that received the `upi://pay` intent.
class PayChannel {
  static const _channel = MethodChannel('fakepay/pay');

  static Future<UpiRequest> getRequest() async {
    final m = await _channel.invokeMapMethod<String, dynamic>('getRequest');
    return UpiRequest.parse(
      (m?['uri'] as String?) ?? '',
      callingPackage: m?['callingPackage'] as String?,
    );
  }

  /// Sends the result to the caller and closes the screen.
  static Future<void> finish(UpiOutcome outcome) =>
      _channel.invokeMethod<void>('finish', {
        'ok': outcome.ok,
        'response': outcome.response,
        'extras': outcome.extras,
      });
}
