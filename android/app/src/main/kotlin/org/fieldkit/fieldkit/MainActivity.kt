package org.fieldkit.fieldkit

import android.content.Intent
import android.app.Activity

import android.os.StatFs
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.view.Surface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity(), SensorEventListener {
    private var exportResult: MethodChannel.Result? = null
    private var exportText: String? = null
    private var headingSink: EventChannel.EventSink? = null
    private val sensors by lazy { getSystemService(SENSOR_SERVICE) as SensorManager }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.fieldkit/export")
            .setMethodCallHandler { call, result ->
                val text = call.argument<String>("text")
                if (call.method != "example" || text == null || text.length > 100000) {
                    result.error("invalid_export", "Invalid example", null)
                } else if (exportResult != null) {
                    result.error("busy", "An export is already open", null)
                } else {
                    exportResult = result
                    exportText = text
                    startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TITLE, "supplies.py")
                    }, 4701)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.fieldkit/storage")
            .setMethodCallHandler { call, result ->
                if (call.method == "availableBytes") {
                    result.success(StatFs(filesDir.absolutePath).availableBytes)
                } else {
                    result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "org.fieldkit/compass")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    headingSink = events
                    val sensor = sensors.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
                    if (sensor == null || !sensors.registerListener(this@MainActivity, sensor, SensorManager.SENSOR_DELAY_UI)) {
                        events.success(mapOf("heading" to null, "accuracy" to null))
                    }
                }
                override fun onCancel(arguments: Any?) {
                    sensors.unregisterListener(this@MainActivity)
                    headingSink = null
                }
            })
    }
    @Deprecated("Required for FlutterActivity document picker integration")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 4701) return
        try {
            val uri = data?.data
            if (resultCode == Activity.RESULT_OK && uri != null) {
                val stream = contentResolver.openOutputStream(uri, "wt")
                    ?: throw IllegalStateException("Cannot open destination")
                stream.use { it.write((exportText ?: "").toByteArray(Charsets.UTF_8)) }
                exportResult?.success(true)
            } else exportResult?.success(false)
        } catch (error: Exception) {
            exportResult?.error("export_failed", error.localizedMessage, null)
        } finally {
            exportResult = null
            exportText = null
        }
    }
    override fun onSensorChanged(event: SensorEvent) {
        if (event.accuracy <= SensorManager.SENSOR_STATUS_ACCURACY_LOW) {
            headingSink?.success(mapOf("heading" to null, "accuracy" to null, "status" to "unreliable"))
            return
        }
        val rotation = FloatArray(9)
        val adjusted = FloatArray(9)
        val orientation = FloatArray(3)
        SensorManager.getRotationMatrixFromVector(rotation, event.values)
        val axes = when (windowManager.defaultDisplay.rotation) {
            Surface.ROTATION_90 -> Pair(SensorManager.AXIS_Y, SensorManager.AXIS_MINUS_X)
            Surface.ROTATION_180 -> Pair(SensorManager.AXIS_MINUS_X, SensorManager.AXIS_MINUS_Y)
            Surface.ROTATION_270 -> Pair(SensorManager.AXIS_MINUS_Y, SensorManager.AXIS_X)
            else -> Pair(SensorManager.AXIS_X, SensorManager.AXIS_Y)
        }
        SensorManager.remapCoordinateSystem(rotation, axes.first, axes.second, adjusted)
        SensorManager.getOrientation(adjusted, orientation)
        val degrees = (Math.toDegrees(orientation[0].toDouble()) + 360.0) % 360.0
        // Android quality levels are not an angular error estimate.
        headingSink?.success(mapOf("heading" to degrees, "accuracy" to null))
    }
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    override fun onDestroy() {
        sensors.unregisterListener(this)
        headingSink = null
        super.onDestroy()
    }
}
