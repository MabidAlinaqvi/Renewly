package com.independentstudio.renewly

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Geocoder
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private var pendingLocation: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "renewly/country")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "countries" -> result.success(countries())
                    "locationCountry" -> locationCountry(result)
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Where the phone is now (mobile network) and where its SIM is from. Neither
     * needs a permission. Empty when there is no SIM or signal.
     */
    private fun countries(): Map<String, String> {
        val telephony = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        return mapOf(
            "network" to (telephony?.networkCountryIso ?: ""),
            "sim" to (telephony?.simCountryIso ?: ""),
        )
    }

    /** Country code from approximate location, asking permission first; null if unavailable. */
    private fun locationCountry(result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
            lookUpCountry(result)
            return
        }
        pendingLocation?.success(null)
        pendingLocation = result
        requestPermissions(arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION), LOCATION_REQUEST)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != LOCATION_REQUEST) return
        val result = pendingLocation ?: return
        pendingLocation = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) lookUpCountry(result) else result.success(null)
    }

    private fun lookUpCountry(result: MethodChannel.Result) {
        val manager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val known = try {
            listOf(LocationManager.NETWORK_PROVIDER, LocationManager.PASSIVE_PROVIDER, LocationManager.GPS_PROVIDER)
                .mapNotNull { manager.getLastKnownLocation(it) }
                .maxByOrNull { it.time }
        } catch (_: SecurityException) {
            null
        }
        if (known != null || Build.VERSION.SDK_INT < Build.VERSION_CODES.R ||
            !manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        ) {
            geocode(known, result)
            return
        }
        // No recent fix: ask the network provider (Wi-Fi/cell based) for one.
        try {
            manager.getCurrentLocation(LocationManager.NETWORK_PROVIDER, null, mainExecutor) { geocode(it, result) }
        } catch (_: SecurityException) {
            result.success(null)
        }
    }

    /** Turns coordinates into a country code off the main thread. */
    private fun geocode(location: Location?, result: MethodChannel.Result) {
        if (location == null || !Geocoder.isPresent()) {
            result.success(null)
            return
        }
        val main = Handler(Looper.getMainLooper())
        Thread {
            val country = try {
                @Suppress("DEPRECATION")
                Geocoder(this, Locale.US).getFromLocation(location.latitude, location.longitude, 1)
                    ?.firstOrNull()?.countryCode
            } catch (_: Exception) {
                null
            }
            main.post { result.success(country) }
        }.start()
    }

    private companion object {
        const val LOCATION_REQUEST = 7
    }
}
