package de.tttq.tailg_ble_app

import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INDUCTION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    try {
                        ContextCompat.startForegroundService(
                            this,
                            Intent(this, InductionForegroundService::class.java),
                        )
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("induction_service_start", error.message, null)
                    }
                }
                "stop" -> {
                    stopService(Intent(this, InductionForegroundService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private companion object {
        const val INDUCTION_CHANNEL = "de.tttq.tailg_ble_app/induction_service"
    }
}
