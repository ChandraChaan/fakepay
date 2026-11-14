package com.chandrachaan.fakepay

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Receives `upi://pay` intents exactly like a real UPI app would and hands them to
 * the Dart `payMain` entrypoint, which decides what to answer.
 *
 * Runs in the caller's task (standard launch mode) so `startActivityForResult`
 * results are delivered to the host app the same way real UPI apps deliver them.
 */
class PayActivity : FlutterActivity() {

    override fun getDartEntrypointFunctionName(): String = "payMain"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getRequest" -> result.success(
                        mapOf(
                            "uri" to (intent?.dataString ?: ""),
                            "callingPackage" to (callingActivity?.packageName ?: callingPackage),
                        )
                    )

                    "finish" -> {
                        val ok = call.argument<Boolean>("ok") ?: false
                        val response = call.argument<String>("response")
                        val extras = call.argument<Map<String, String>>("extras") ?: emptyMap()
                        val code = if (ok) Activity.RESULT_OK else Activity.RESULT_CANCELED
                        if (response == null && extras.isEmpty()) {
                            setResult(code)
                        } else {
                            val data = Intent()
                            if (response != null) data.putExtra("response", response)
                            extras.forEach { (k, v) -> data.putExtra(k, v) }
                            setResult(code, data)
                        }
                        result.success(null)
                        finish()
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val CHANNEL = "fakepay/pay"
    }
}
