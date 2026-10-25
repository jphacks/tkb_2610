package com.example.frontend

import android.app.*
import android.content.*
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.graphics.PixelFormat
import android.os.*
import android.provider.Settings
import android.view.*
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt

/** User-started companion overlay. No boot receiver and no automatic restart. */
class PetOverlayService : Service() {
    companion object {
        const val ACTION_STOP = "jp.yoinoko.app.STOP_PET"
        const val PREFS = "yoinoko_pet"
        const val CHARACTER = "character"
        private const val CHANNEL_ID = "yoinoko_companion"
        private const val NOTIFICATION_ID = 104
        var instance: PetOverlayService? = null
            private set
        var appVisible = false
        var starting = false
    }

    private lateinit var windows: WindowManager
    private var engine: FlutterEngine? = null
    private var view: FlutterView? = null
    private var channel: MethodChannel? = null
    private var params: WindowManager.LayoutParams? = null
    private var maxX = 0f
    private var maxY = 0f
    private var shown = false
    private var registered = false
    private var ready = false
    private val density get() = resources.displayMetrics.density
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) = updateVisibility()
    }

    override fun onBind(intent: Intent?) = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        starting = false
        windows = getSystemService(WindowManager::class.java)
        val notifications = getSystemService(NotificationManager::class.java)
        notifications.createNotificationChannel(NotificationChannel(
            CHANNEL_ID, "よいのこのおでかけ", NotificationManager.IMPORTANCE_LOW
        ).apply { description = "ホーム画面にいるよいのこの表示と終了" })
        val open = PendingIntent.getActivity(this, 1,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val stop = PendingIntent.getService(this, 2,
            Intent(this, PetOverlayService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_pet_notification)
            .setContentTitle("よいのこがおでかけ中")
            .setContentText("タップでアプリへ戻れます。終了すると画面からいなくなります。")
            .setContentIntent(open).setOngoing(true)
            .addAction(Notification.Action.Builder(null, "おでかけを終了", stop).build())
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(receiver, filter, RECEIVER_NOT_EXPORTED)
        else @Suppress("DEPRECATION") registerReceiver(receiver, filter)
        registered = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP || !Settings.canDrawOverlays(this) || character() == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            if (engine == null) createOverlay()
            updateVisibility()
            sendState()
        } catch (e: RuntimeException) {
            android.util.Log.e("YoinokoPet", "Unable to show companion", e)
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun character(): String? = getSharedPreferences(PREFS, MODE_PRIVATE).getString(CHARACTER, null)

    private fun createOverlay() {
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)
        val flutter = FlutterEngine(this)
        engine = flutter
        channel = MethodChannel(flutter.dartExecutor.binaryMessenger, "jp.yoinoko.app/overlay")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "ready" -> { ready = true; result.success(state()) }
                "move" -> {
                    val x = call.argument<Number>("x")?.toFloat()
                    val y = call.argument<Number>("y")?.toFloat()
                    val layout = params
                    if (x != null && y != null && x.isFinite() && y.isFinite() && layout != null) {
                        layout.x = (x.coerceIn(0f, maxX) * density).roundToInt()
                        layout.y = (y.coerceIn(0f, maxY) * density).roundToInt()
                        if (shown) view?.let { windows.updateViewLayout(it, layout) }
                    }
                    result.success(null)
                }
                "stop" -> { result.success(null); stopSelf() }
                "open" -> {
                    startActivity(Intent(this, MainActivity::class.java)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        val texture = FlutterTextureView(this).apply { isOpaque = false }
        view = FlutterView(this, texture).apply {
            setBackgroundColor(android.graphics.Color.TRANSPARENT)
            attachToFlutterEngine(flutter)
        }
        params = WindowManager.LayoutParams(
            (192 * density).roundToInt(), (232 * density).roundToInt(),
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.LEFT
            title = "よいのこ"
        }
        updateBounds(initial = true)
        flutter.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "petOverlayMain")
        )
    }

    @Suppress("DEPRECATION")
    private fun updateBounds(initial: Boolean = false) {
        val layout = params ?: return
        val metrics = resources.displayMetrics
        val size = if (Build.VERSION.SDK_INT >= 30) {
            val windowMetrics = windows.currentWindowMetrics
            val bounds = windowMetrics.bounds
            val insets = windowMetrics.windowInsets.getInsetsIgnoringVisibility(
                WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
            android.graphics.Point(bounds.width() - insets.left - insets.right,
                bounds.height() - insets.top - insets.bottom)
        } else {
            val insets = view?.rootWindowInsets
            android.graphics.Point(
                metrics.widthPixels - (insets?.systemWindowInsetLeft ?: 0) - (insets?.systemWindowInsetRight ?: 0),
                metrics.heightPixels - (insets?.systemWindowInsetTop ?: (24 * density).roundToInt()) -
                    (insets?.systemWindowInsetBottom ?: (48 * density).roundToInt()))
        }
        // WindowManager positions this window inside the system-bar insets.
        maxX = ((size.x - layout.width) / density).coerceAtLeast(0f)
        maxY = ((size.y - layout.height) / density).coerceAtLeast(0f)
        layout.x = if (initial) (maxX * density / 2).roundToInt()
            else layout.x.coerceIn(0, (maxX * density).roundToInt())
        layout.y = if (initial) (maxY * density * .65f).roundToInt()
            else layout.y.coerceIn(0, (maxY * density).roundToInt())
        if (shown) view?.let { windows.updateViewLayout(it, layout) }
    }

    private fun state(): Map<String, Any?> = mapOf(
        "character" to character(), "maxX" to maxX, "maxY" to maxY,
        "x" to ((params?.x ?: 0) / density), "y" to ((params?.y ?: 0) / density),
        "visible" to shown
    )

    fun sendState() {
        if (ready && character() != null) channel?.invokeMethod("state", state())
    }

    fun updateVisibility() {
        val unlocked = !getSystemService(KeyguardManager::class.java).isKeyguardLocked
        val interactive = getSystemService(PowerManager::class.java).isInteractive
        val show = !appVisible && unlocked && interactive && Settings.canDrawOverlays(this)
        val flutterView = view ?: return
        if (show == shown) return
        shown = show
        if (show) {
            windows.addView(flutterView, params)
            engine?.lifecycleChannel?.appIsResumed()
        } else {
            windows.removeView(flutterView)
            engine?.lifecycleChannel?.appIsPaused()
        }
        if (ready) channel?.invokeMethod("visibility", shown)
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        updateBounds()
        sendState()
    }

    override fun onDestroy() {
        instance = null
        if (registered) unregisterReceiver(receiver)
        channel?.setMethodCallHandler(null)
        if (shown) view?.let { windows.removeView(it) }
        view?.detachFromFlutterEngine()
        engine?.lifecycleChannel?.appIsDetached()
        engine?.destroy()
        engine = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
