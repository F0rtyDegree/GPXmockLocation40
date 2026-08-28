
package by.fortydegree.gpxmocklocation40

import android.content.Context
import android.location.Location
import android.location.LocationManager
import android.os.SystemClock
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.gpx_mock_location/mock_location"
    private var locationManager: LocationManager? = null
    private val MOCK_PROVIDER = "gps"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager

        // Настройка тестового провайдера
        try {
            locationManager?.addTestProvider(
                MOCK_PROVIDER,
                false,
                false,
                false,
                false,
                true,
                true,
                true,
                0,
                5
            )
            locationManager?.setTestProviderEnabled(MOCK_PROVIDER, true)
        } catch (e: SecurityException) {
            // Это исключение возникнет, если в настройках разработчика не выбрано это приложение
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "setMockLocation") {
                try {
                    val lat = call.argument<Double>("lat")!!
                    val lon = call.argument<Double>("lon")!!
                    val speed = call.argument<Double>("speed")!!

                    val mockLocation = Location(MOCK_PROVIDER).apply {
                        latitude = lat
                        longitude = lon
                        altitude = 0.0
                        this.speed = speed.toFloat() // скорость в м/с
                        accuracy = 1.0f
                        time = System.currentTimeMillis()
                        elapsedRealtimeNanos = SystemClock.elapsedRealtimeNanos()
                    }

                    locationManager?.setTestProviderLocation(MOCK_PROVIDER, mockLocation)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("MOCK_LOCATION_ERROR", "Failed to set mock location", e.toString())
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            locationManager?.removeTestProvider(MOCK_PROVIDER)
        } catch (e: Exception) {
            // Игнорируем
        }
    }
}
