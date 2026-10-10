package ir.rahi.rahi

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.GnssStatus
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.max

class MainActivity : FlutterActivity() {
    private lateinit var locationManager: LocationManager
    private val mainHandler = Handler(Looper.getMainLooper())

    private var gnssRegistered = false
    private var totalSatellites = 0
    private var satellitesUsedInFix = 0
    private var averageCn0DbHz = 0.0
    private var usedConstellations: Map<String, Int> = emptyMap()

    private var pendingResult: MethodChannel.Result? = null
    private var pendingListener: LocationListener? = null
    private var pendingTimeout: Runnable? = null
    private var bestLocation: Location? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        locationManager =
            getSystemService(Context.LOCATION_SERVICE) as LocationManager

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "rahi/gnss",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getGnssSnapshot" -> {
                    ensureGnssStatus()
                    result.success(snapshotMap())
                }
                "acquireGpsFix" -> acquireGpsFix(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private val gnssCallback = object : GnssStatus.Callback() {
        override fun onSatelliteStatusChanged(status: GnssStatus) {
            totalSatellites = status.satelliteCount

            var used = 0
            var cn0Sum = 0.0
            val counts = mutableMapOf<String, Int>()

            for (index in 0 until status.satelliteCount) {
                if (!status.usedInFix(index)) continue

                used += 1
                cn0Sum += status.getCn0DbHz(index).toDouble()

                val constellation =
                    constellationName(status.getConstellationType(index))
                counts[constellation] = (counts[constellation] ?: 0) + 1
            }

            satellitesUsedInFix = used
            averageCn0DbHz = if (used > 0) cn0Sum / used else 0.0
            usedConstellations = counts.toMap()
        }
    }

    private fun ensureGnssStatus() {
        if (gnssRegistered || Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return
        }
        if (!hasFineLocationPermission()) return

        try {
            gnssRegistered =
                locationManager.registerGnssStatusCallback(
                    gnssCallback,
                    mainHandler,
                )
        } catch (_: SecurityException) {
            gnssRegistered = false
        }
    }

    private fun acquireGpsFix(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        if (!hasFineLocationPermission()) {
            result.error(
                "fine_location_required",
                "ACCESS_FINE_LOCATION is required for GNSS acquisition.",
                null,
            )
            return
        }

        if (!locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            result.success(
                snapshotMap().toMutableMap().apply {
                    put("available", false)
                    put("reason", "gps_provider_disabled")
                },
            )
            return
        }

        if (pendingResult != null) {
            result.error(
                "gnss_busy",
                "A GNSS acquisition is already running.",
                null,
            )
            return
        }

        ensureGnssStatus()

        val timeoutMs =
            (call.argument<Number>("timeoutMs")?.toLong() ?: 20_000L)
                .coerceIn(5_000L, 30_000L)

        pendingResult = result
        bestLocation = null

        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                val currentBest = bestLocation
                if (currentBest == null ||
                    location.accuracy < currentBest.accuracy ||
                    location.time > currentBest.time + 3_000L
                ) {
                    bestLocation = location
                }

                if (location.hasAccuracy() &&
                    location.accuracy <= 25f &&
                    satellitesUsedInFix >= 4
                ) {
                    finishGpsFix()
                }
            }

            override fun onProviderEnabled(provider: String) = Unit

            override fun onProviderDisabled(provider: String) = Unit

            @Deprecated("Deprecated in Android")
            override fun onStatusChanged(
                provider: String?,
                status: Int,
                extras: Bundle?,
            ) = Unit
        }

        pendingListener = listener

        try {
            locationManager.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                500L,
                0f,
                listener,
                Looper.getMainLooper(),
            )
        } catch (error: SecurityException) {
            clearPendingLocationRequest()
            result.error(
                "gnss_permission",
                error.message,
                null,
            )
            return
        }

        val timeout = Runnable { finishGpsFix() }
        pendingTimeout = timeout
        mainHandler.postDelayed(timeout, timeoutMs)
    }

    private fun finishGpsFix() {
        val result = pendingResult ?: return
        val location = bestLocation

        clearPendingLocationRequest()

        if (location == null) {
            result.success(
                snapshotMap().toMutableMap().apply {
                    put("available", false)
                    put("reason", "no_gps_fix")
                },
            )
            return
        }

        result.success(locationMap(location))
    }

    private fun clearPendingLocationRequest() {
        pendingTimeout?.let(mainHandler::removeCallbacks)
        pendingTimeout = null

        pendingListener?.let {
            try {
                locationManager.removeUpdates(it)
            } catch (_: SecurityException) {
                // Permission may have changed while the request was active.
            }
        }

        pendingListener = null
        pendingResult = null
        bestLocation = null
    }

    private fun snapshotMap(): Map<String, Any> {
        return mapOf(
            "totalSatellites" to totalSatellites,
            "satellitesUsedInFix" to satellitesUsedInFix,
            "averageCn0DbHz" to averageCn0DbHz,
            "constellations" to usedConstellations,
            "gpsProviderEnabled" to
                locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER),
            "networkProviderEnabled" to
                locationManager.isProviderEnabled(
                    LocationManager.NETWORK_PROVIDER,
                ),
        )
    }

    private fun locationMap(location: Location): Map<String, Any> {
        return snapshotMap().toMutableMap().apply {
            put("available", true)
            put("latitude", location.latitude)
            put("longitude", location.longitude)
            put("accuracy", location.accuracy.toDouble())
            put("timestampMillis", location.time)
            put("speed", if (location.hasSpeed()) location.speed.toDouble() else 0.0)
            put(
                "bearing",
                if (location.hasBearing()) location.bearing.toDouble() else 0.0,
            )
            put("mocked", isMockLocation(location))
        }
    }

    private fun hasFineLocationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun isMockLocation(location: Location): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            location.isMock
        } else {
            @Suppress("DEPRECATION")
            location.isFromMockProvider
        }
    }

    private fun constellationName(type: Int): String {
        return when (type) {
            GnssStatus.CONSTELLATION_GPS -> "GPS"
            GnssStatus.CONSTELLATION_GLONASS -> "GLONASS"
            GnssStatus.CONSTELLATION_GALILEO -> "GALILEO"
            GnssStatus.CONSTELLATION_BEIDOU -> "BEIDOU"
            GnssStatus.CONSTELLATION_QZSS -> "QZSS"
            GnssStatus.CONSTELLATION_SBAS -> "SBAS"
            GnssStatus.CONSTELLATION_IRNSS -> "IRNSS"
            else -> "UNKNOWN"
        }
    }

    override fun onDestroy() {
        clearPendingLocationRequest()

        if (gnssRegistered && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            locationManager.unregisterGnssStatusCallback(gnssCallback)
            gnssRegistered = false
        }

        super.onDestroy()
    }
}
