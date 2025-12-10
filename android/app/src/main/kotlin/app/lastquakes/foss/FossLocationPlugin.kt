package app.lastquakes.foss

import android.content.Context
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class FossLocationPlugin(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "app.lastquakes.foss/location"
        private const val TIMEOUT_MS = 10000L
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "getCurrentLocation") {
            getCurrentLocation(result)
        } else {
            result.notImplemented()
        }
    }

    private fun getCurrentLocation(result: MethodChannel.Result) {
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val safeResult = SafeResult(result)
        
        try {
            // 1. Try to get Last Known Location
            var bestLocation: Location? = null
            try {
                if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                    bestLocation = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                }
                
                val netLocation = if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                    locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
                } else null

                if (netLocation != null) {
                    if (bestLocation == null || netLocation.time > bestLocation.time) {
                        bestLocation = netLocation
                    }
                }
            } catch (e: SecurityException) {
                safeResult.error("PERMISSION_ERROR", "Location permission denied", null)
                return
            }

            // If fresh (< 2 mins), return immediately
            if (bestLocation != null && (System.currentTimeMillis() - bestLocation.time) < 120000) {
                safeResult.success(locationToMap(bestLocation))
                return
            }

            // 2. Request Active Update
            val handler = Handler(Looper.getMainLooper())
            
            val listener = object : LocationListener {
                override fun onLocationChanged(location: Location) {
                    locationManager.removeUpdates(this)
                    safeResult.success(locationToMap(location))
                }
                override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
                override fun onProviderEnabled(provider: String) {}
                override fun onProviderDisabled(provider: String) {}
            }

            // Register updates (GPS preferred, then Network)
            var started = false
            try {
                if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                    locationManager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 0L, 0f, listener, Looper.getMainLooper())
                    started = true
                } else if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                    locationManager.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 0L, 0f, listener, Looper.getMainLooper())
                    started = true
                }
            } catch (e: SecurityException) {
                 safeResult.error("PERMISSION_ERROR", "Location permission denied", null)
                 return
            }

            if (!started) {
                // No providers enabled
                if (bestLocation != null) {
                    safeResult.success(locationToMap(bestLocation!!))
                } else {
                    safeResult.success(null)
                }
                return
            }

            // Timeout
            handler.postDelayed({
                locationManager.removeUpdates(listener)
                if (bestLocation != null) {
                    safeResult.success(locationToMap(bestLocation!!))
                } else {
                    safeResult.success(null)
                }
            }, TIMEOUT_MS)

        } catch (e: Exception) {
            safeResult.error("LOCATION_ERROR", e.message, null)
        }
    }

    private fun locationToMap(location: Location): Map<String, Any> {
        return mapOf(
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "accuracy" to location.accuracy.toDouble(),
            "altitude" to location.altitude,
            "speed" to location.speed.toDouble(),
            "heading" to location.bearing.toDouble(),
            "timestamp" to location.time
        )
    }

    private class SafeResult(private val result: MethodChannel.Result) {
        private val isCalled = AtomicBoolean(false)
        fun success(value: Any?) {
            if (isCalled.compareAndSet(false, true)) {
                result.success(value)
            }
        }
        fun error(code: String, msg: String?, details: Any?) {
             if (isCalled.compareAndSet(false, true)) {
                result.error(code, msg, details)
            }
        }
    }
}
