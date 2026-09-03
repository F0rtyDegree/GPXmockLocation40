package by.fortydegree.gpxmocklocation40

import android.content.Context
import android.location.Location
import android.location.LocationManager
import android.os.Bundle
import android.os.SystemClock
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.gpx_mock_location/mock_location"
    private var locationManager: LocationManager? = null
    // Возвращаем "gps", т.к. это работало ранее
    private val MOCK_PROVIDER = "gps"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager

        // Добавляем тестового провайдера
        try {
            locationManager?.addTestProvider(
                MOCK_PROVIDER,
                false,  // requiresNetwork
                true,   // requiresSatellite
                false,  // requiresCell
                false,  // hasMonetaryCost
                true,   // supportsAltitude
                true,   // supportsSpeed
                true,   // supportsBearing
                1,      // powerRequirement
                2       // accuracy
            )
            locationManager?.setTestProviderEnabled(MOCK_PROVIDER, true)
            Log.i("MainActivity", "Test provider '$MOCK_PROVIDER' added and enabled.")
        } catch (e: SecurityException) {
            Log.e("MainActivity", "SecurityException: Is this app selected as mock location app?", e)
        } catch (e: Exception) {
            Log.e("MainActivity", "Unexpected error adding test provider", e)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setMockLocation") {
                try {
                    val lat = call.argument<Double>("lat") ?: 0.0
                    val lon = call.argument<Double>("lon") ?: 0.0
                    val speed = call.argument<Double>("speed") ?: 0.0
                    val altitude = call.argument<Double>("altitude") ?: 0.0
                    val bearing = call.argument<Double>("bearing") ?: 0.0
                    val satellites = call.argument<Int>("satellites") ?: 0

                    Log.d("MainActivity", "setMockLocation: lat=$lat, lon=$lon, speed=$speed, alt=$altitude, bearing=$bearing, sats=$satellites")

                    // Проверяем, что провайдер включён
                    if (locationManager?.isProviderEnabled(MOCK_PROVIDER) != true) {
                        // Попробуем включить заново
                        try {
                            locationManager?.setTestProviderEnabled(MOCK_PROVIDER, true)
                            Log.w("MainActivity", "Provider was disabled, re-enabled.")
                        } catch (e: Exception) {
                            Log.e("MainActivity", "Failed to enable provider", e)
                        }
                    }

                    val mockLocation = Location(MOCK_PROVIDER).apply {
                        latitude = lat
                        longitude = lon
                        this.speed = speed.toFloat()
                        this.altitude = altitude
                        this.bearing = bearing.toFloat()
                        this.accuracy = 3.0f
                        this.verticalAccuracyMeters = 5.0f
                        this.speedAccuracyMetersPerSecond = 0.5f
                        this.bearingAccuracyDegrees = 5.0f
                        this.time = System.currentTimeMillis()
                        this.elapsedRealtimeNanos = SystemClock.elapsedRealtimeNanos()

                        val extras = Bundle()
                        extras.putInt("satellites", satellites)
                        this.extras = extras
                    }

                    locationManager?.setTestProviderLocation(MOCK_PROVIDER, mockLocation)
                    Log.d("MainActivity", "Mock location set successfully.")
                    result.success(null)
                } catch (e: Exception) {
                    Log.e("MainActivity", "Error setting mock location", e)
                    result.error("MOCK_LOCATION_ERROR", "Failed to set mock location: ${e.message}", e.toString())
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Не удаляем провайдер, чтобы не нарушить работу
        // try {
        //     locationManager?.removeTestProvider(MOCK_PROVIDER)
        // } catch (e: Exception) { }
    }
}