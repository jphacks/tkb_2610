package com.example.frontend

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jp.yoinoko.app/pet")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "status" -> result.success(mapOf(
                            "allowed" to Settings.canDrawOverlays(this),
                            "running" to (PetOverlayService.instance != null || PetOverlayService.starting)
                        ))
                        "permission" -> {
                            startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")))
                            result.success(null)
                        }
                        "sync" -> {
                            val prefs = getSharedPreferences(PetOverlayService.PREFS, MODE_PRIVATE)
                            val json = call.arguments as? String
                            if (json == null) {
                                prefs.edit().remove(PetOverlayService.CHARACTER).apply()
                                stopService(Intent(this, PetOverlayService::class.java))
                            } else {
                                JSONObject(json) // Reject malformed data before changing the live companion.
                                prefs.edit().putString(PetOverlayService.CHARACTER, json).apply()
                                PetOverlayService.instance?.sendState()
                            }
                            result.success(null)
                        }
                        "start" -> {
                            check(Settings.canDrawOverlays(this)) { "先に「他のアプリの上に表示」を許可してください。" }
                            check(getSharedPreferences(PetOverlayService.PREFS, MODE_PRIVATE)
                                .contains(PetOverlayService.CHARACTER)) { "よいのこを迎えてからお試しください。" }
                            if (Build.VERSION.SDK_INT >= 33 &&
                                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 104)
                            }
                            PetOverlayService.starting = true
                            startForegroundService(Intent(this, PetOverlayService::class.java))
                            result.success(null)
                        }
                        "stop" -> {
                            stopService(Intent(this, PetOverlayService::class.java))
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    PetOverlayService.starting = false
                    result.error("PET_ERROR", e.message ?: "おでかけの操作に失敗しました。", null)
                }
            }
    }

    override fun onStart() {
        super.onStart()
        PetOverlayService.appVisible = true
        PetOverlayService.instance?.updateVisibility()
    }

    override fun onStop() {
        super.onStop()
        PetOverlayService.appVisible = false
        PetOverlayService.instance?.updateVisibility()
    }
}
