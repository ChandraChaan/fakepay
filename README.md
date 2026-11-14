# FakePay

**A UPI app that moves no money.** Install it on a test phone or emulator, and when your app fires a `upi://pay` intent, FakePay answers with whatever result you choose: success, pending, failure codes, a cancelled flow, or a deliberately broken response.

Test every payment path in your Android or Flutter app without real money, a real bank account or a flaky payment app.

- No internet permission. Nothing leaves the device.
- Registers for `upi://pay` exactly like GPay or PhonePe, so your existing intent code works unchanged.
- 14 scenarios, including the ugly ones real apps produce.
- Checks your request (`pa`, `pn`, `am`, `cu`, `tr`) and tells you what a strict UPI app would reject.
- Logs the exact link your app sent and exactly what came back.

## Why it exists

UPI has no sandbox for the intent flow. You can't make a real app return `U16` or `Z9` on demand, can't see what happens when a response has no `txnRef`, and can't test a timeout without waiting for one. Bugs in that code only show up in production, with real money. FakePay makes each of those cases one tap.

## Install

Grab the APK from [Releases](../../releases) (or `flutter build apk --release`), install it on a test device or emulator, and open it once. That's all: it is now in the UPI chooser.

## Scenarios

| Group | Scenario | What your app receives |
|---|---|---|
| Success | Success | `Status=SUCCESS&responseCode=00` + `txnId`, `txnRef`, `ApprovalRefNo` |
| | Submitted (pending) | `Status=SUBMITTED` |
| Failure | Debit failed | `Status=FAILURE&responseCode=U30` |
| | Insufficient funds | `Status=FAILURE&responseCode=Z9` |
| | Wrong UPI PIN | `Status=FAILURE&responseCode=ZM` |
| | Risk threshold exceeded | `Status=FAILURE&responseCode=U16` |
| | User cancelled | `RESULT_CANCELED`, no data |
| Edge cases | Lowercase keys | `status=success&txnid=…` |
| | Different `txnRef` | success, but the reference does not match your request |
| | No `txnRef` | success without a reference |
| | Extras only | `Status`, `txnId`… as separate extras, no `response` string |
| | `RESULT_OK`, no data | the result `Intent` is `null` |
| | Empty `response` | `response=""` |
| | Malformed `response` | not `key=value` pairs |

Add a delay of 3, 10 or 30 seconds, or "Never" to leave the screen open until you press back. That is how you test timeouts and the user abandoning the flow. "Random" picks any scenario each time.

The response codes are the ones in NPCI's public list. Banks and apps differ, so treat the exact strings as realistic examples, not a spec.

## Control it from code or CI

Add `fakepay=<scenario id>` (and optionally `fakepay_delay=<seconds>`) to the UPI link in debug builds. It overrides the app setting, so tests need no tapping. Real UPI apps ignore unknown parameters.

```dart
final link = 'upi://pay?pa=shop@upi&pn=Test%20Shop&am=10.00&cu=INR&tr=$orderId'
    '${kDebugMode ? '&fakepay=failure_funds&fakepay_delay=2' : ''}';
```

Scenario ids: `success`, `pending`, `failure_u30`, `failure_funds`, `failure_mpin`, `failure_risk`, `cancelled`, `success_lowercase`, `success_wrong_ref`, `success_no_ref`, `extras_only`, `no_data`, `empty_response`, `malformed`, `random`.

From the command line (to check what FakePay shows for a link):

```bash
adb shell 'am start -n com.chandrachaan.fakepay/.PayActivity -a android.intent.action.VIEW -d "upi://pay?pa=shop@upi&pn=Test%20Shop&am=10.00&cu=INR&tr=T1&fakepay=success"'
```

Results only reach a caller that used `startActivityForResult`, so run this from your app or test, not from `adb`.

## Using it with your app

Your app needs the usual UPI setup; FakePay changes nothing here.

```xml
<!-- AndroidManifest.xml, Android 11+ so the app can see UPI apps -->
<queries>
  <intent>
    <action android:name="android.intent.action.VIEW"/>
    <data android:scheme="upi" android:host="pay"/>
  </intent>
</queries>
```

Then launch the intent however you do today (the `upi_pay` plugin, `url_launcher`, or your own `startActivityForResult`). Pick FakePay in the chooser, or set it as the answer under "When a payment request arrives" so there is no chooser tap.

## The request check

FakePay lints every request it receives:

- `pa` missing, or not a valid `name@bank`
- `pn` missing
- `am` not a plain decimal with at most 2 places, or `0`
- `cu` missing or not `INR`
- `tr` missing (you will not be able to match the response)
- `tn` over 80 characters

A strict UPI app rejects several of these. Catching them here is cheaper than in production.

## How it works

`PayActivity` (Kotlin) handles the `upi://pay` intent and runs a Flutter screen. The screen decides the answer and sends it back over a method channel; the activity calls `setResult` with a `response` string extra, the same contract real UPI apps use. Settings and history are stored on the device only.

```
lib/src/upi_request.dart   lenient parser + request lint
lib/src/scenarios.dart     every answer FakePay can give
lib/src/ui/                home screen, payment screen
android/.../PayActivity.kt receives the intent, returns the result
```

Run the tests with `flutter test`.

## Limits

- Android only. iOS has no `upi://` result flow to mimic.
- It mimics the intent flow, not UPI Collect, mandates or deep links from other apps.
- It does not talk to any bank, so it can never prove that your server-side verification works. Verify the payment on your server, never from the intent result alone.

## Licence

MIT. See [LICENSE](LICENSE).
