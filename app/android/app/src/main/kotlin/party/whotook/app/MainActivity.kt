package party.whotook.app

import android.Manifest
import android.content.pm.PackageManager
import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import androidx.annotation.RequiresApi
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {

    private var eventSink: EventChannel.EventSink? = null
    private var mediaObserver: ContentObserver? = null
    private var lastScreenshotAt = 0L
    private var installReferrer: String? = null

    // API 34 callback must be unregistered with the same instance that was registered.
    private var captureCallback: Any? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        EventChannel(messenger, SCREENSHOT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    startWatching()
                }

                override fun onCancel(arguments: Any?) {
                    stopWatching()
                    eventSink = null
                }
            },
        )
        // The Dart side probes the channel before subscribing, so a platform
        // without the bridge is a quiet no-op instead of a crash.
        MethodChannel(messenger, SCREENSHOT_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "isSupported") result.success(true) else result.notImplemented()
        }
        MethodChannel(messenger, INSTALL_REFERRER_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInstallReferrer") {
                val cached = installReferrer
                if (cached != null) result.success(cached) else readInstallReferrer(result)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onStart() {
        super.onStart()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            registerCaptureCallback()
        }
    }

    override fun onStop() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            unregisterCaptureCallback()
        }
        super.onStop()
    }

    override fun onDestroy() {
        stopWatching()
        eventSink = null
        super.onDestroy()
    }

    /// Reads the Play install referrer once. The Dart side stores a consumed
    /// marker so the same install cannot join the same room again later.
    private fun readInstallReferrer(result: MethodChannel.Result) {
        val client = InstallReferrerClient.newBuilder(this).build()
        var replied = false

        fun finish(value: String?) {
            if (replied) return
            replied = true
            installReferrer = value
            try {
                client.endConnection()
            } catch (_: Exception) {
                // The connection may already be gone.
            }
            result.success(value)
        }

        try {
            client.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    if (responseCode == InstallReferrerClient.InstallReferrerResponse.OK) {
                        try {
                            finish(client.installReferrer.installReferrer)
                        } catch (_: Exception) {
                            finish(null)
                        }
                    } else {
                        finish(null)
                    }
                }

                override fun onInstallReferrerServiceDisconnected() {
                    finish(null)
                }
            })
            // A device without Play services can otherwise leave the channel
            // pending forever. The Dart side treats null as "no referrer".
            Handler(Looper.getMainLooper()).postDelayed({ finish(null) }, 4_000L)
        } catch (_: Exception) {
            finish(null)
        }
    }

    private fun startWatching() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            registerCaptureCallback()
        } else {
            startMediaObserver()
        }
    }

    private fun stopWatching() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            unregisterCaptureCallback()
        } else {
            stopMediaObserver()
        }
    }

    @RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun registerCaptureCallback() {
        if (captureCallback != null) return
        val callback = object : ScreenCaptureCallback {
            override fun onScreenCaptured() {
                emitScreenshot()
            }
        }
        try {
            registerScreenCaptureCallback(mainExecutor, callback)
            captureCallback = callback
        } catch (_: IllegalStateException) {
            // Already registered or activity not in a capturable state.
        }
    }

    @RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun unregisterCaptureCallback() {
        val callback = captureCallback as? ScreenCaptureCallback ?: return
        captureCallback = null
        try {
            unregisterScreenCaptureCallback(callback)
        } catch (_: IllegalStateException) {
            // Not registered; nothing to undo.
        }
    }

    private fun startMediaObserver() {
        if (mediaObserver != null) return
        if (!hasImageReadPermission()) return
        val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                super.onChange(selfChange, uri)
                if (uri != null && looksLikeScreenshot(uri)) emitScreenshot()
            }
        }
        try {
            contentResolver.registerContentObserver(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                true,
                observer,
            )
            mediaObserver = observer
        } catch (_: SecurityException) {
            // Permission revoked between the check and registration.
        }
    }

    private fun stopMediaObserver() {
        val observer = mediaObserver ?: return
        mediaObserver = null
        try {
            contentResolver.unregisterContentObserver(observer)
        } catch (_: IllegalArgumentException) {
            // Already unregistered.
        }
    }

    private fun hasImageReadPermission(): Boolean {
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_IMAGES
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
        return checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    }

    private fun looksLikeScreenshot(uri: Uri): Boolean {
        if (uri.authority != MediaStore.AUTHORITY) return false
        val displayName = queryDisplayName(uri)
        if (displayName != null) {
            return displayName.lowercase(Locale.ROOT).contains("screenshot")
        }
        // Path is only present on some providers; fall back to it when the query fails.
        return uri.toString().lowercase(Locale.ROOT).contains("screenshot")
    }

    private fun queryDisplayName(uri: Uri): String? {
        val projection = arrayOf(MediaStore.Images.Media.DISPLAY_NAME)
        return try {
            contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }
        } catch (_: SecurityException) {
            null
        } catch (_: IllegalArgumentException) {
            null
        }
    }

    private fun emitScreenshot() {
        val now = System.currentTimeMillis()
        // MediaStore can report the same insert twice (insert + update).
        if (now - lastScreenshotAt < DEDUPE_WINDOW_MS) return
        lastScreenshotAt = now
        eventSink?.success(now)
    }

    companion object {
        private const val SCREENSHOT_CHANNEL = "app.whotook/screenshots"
        private const val INSTALL_REFERRER_CHANNEL = "app.whotook/install_referrer"
        private const val DEDUPE_WINDOW_MS = 2_000L
    }
}
