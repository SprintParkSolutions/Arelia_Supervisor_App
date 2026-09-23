package com.example.arelia_supervisor

import android.media.RingtoneManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "arelia/notification_sound")
            .setMethodCallHandler { call, result ->
                if (call.method != "play") {
                    result.notImplemented()
                } else {
                    try {
                        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                        RingtoneManager.getRingtone(applicationContext, uri)?.play()
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("sound_unavailable", "Notification sound is unavailable", null)
                    }
                }
            }
    }
}
