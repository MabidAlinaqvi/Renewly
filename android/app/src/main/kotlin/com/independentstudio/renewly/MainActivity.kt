package com.independentstudio.renewly

import android.content.Context
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "renewly/country")
            .setMethodCallHandler { call, result ->
                if (call.method == "countries") result.success(countries()) else result.notImplemented()
            }
    }

    /**
     * Where the phone is now (mobile network) and where its SIM is from. Neither
     * needs a permission, unlike GPS. Empty when there is no SIM or signal.
     */
    private fun countries(): Map<String, String> {
        val telephony = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        return mapOf(
            "network" to (telephony?.networkCountryIso ?: ""),
            "sim" to (telephony?.simCountryIso ?: ""),
        )
    }
}
