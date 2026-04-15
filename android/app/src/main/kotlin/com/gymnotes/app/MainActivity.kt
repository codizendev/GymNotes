package com.gymnotes.app

import android.content.ContentValues
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import android.util.Base64
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import android.os.Environment

class MainActivity: FlutterActivity() {

    private val CHANNEL = "com.gymnotes.app/media_save" // isto kao u Dart-u
    private val OVERLAY_CHANNEL = "com.gymnotes.app/segment_overlay"
    private val overlayHandler = Handler(Looper.getMainLooper())
    private var overlayView: View? = null
    private var overlayTitleView: TextView? = null
    private var overlayBodyView: TextView? = null
    private var overlayHideRunnable: Runnable? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "savePdf" -> {
                    val filename = call.argument<String>("filename") ?: "workout.pdf"
                    val base64 = call.argument<String>("bytesBase64") ?: ""
                    val bytes = Base64.decode(base64, Base64.DEFAULT)
                    saveBytesToDownloads(
                        filename = filename,
                        bytes = bytes,
                        mimeType = "application/pdf",
                        result = result,
                    )
                }
                "saveFile" -> {
                    val filename = call.argument<String>("filename") ?: "export.bin"
                    val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                    val base64 = call.argument<String>("bytesBase64") ?: ""
                    val bytes = Base64.decode(base64, Base64.DEFAULT)
                    saveBytesToDownloads(
                        filename = filename,
                        bytes = bytes,
                        mimeType = mimeType,
                        result = result,
                    )
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    val title = call.argument<String>("title") ?: ""
                    val body = call.argument<String>("body") ?: ""
                    val durationMs = (call.argument<Int>("durationMs") ?: 5000).toLong()
                    val ok = showOverlay(title, body, durationMs)
                    result.success(ok)
                }
                "dismiss" -> {
                    dismissOverlay()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun saveBytesToDownloads(
        filename: String,
        bytes: ByteArray,
        mimeType: String,
        result: MethodChannel.Result,
    ) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val resolver = applicationContext.contentResolver
                val collection =
                    MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, filename)
                    put(MediaStore.Downloads.MIME_TYPE, mimeType)
                    put(MediaStore.Downloads.RELATIVE_PATH, "Download/")
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }
                val uri = resolver.insert(collection, values)
                if (uri == null) {
                    result.success(false)
                    return
                }
                resolver.openOutputStream(uri, "w")!!.use { os ->
                    os.write(bytes)
                    os.flush()
                }
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                result.success(true)
            } else {
                val downloads =
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                if (!downloads.exists()) downloads.mkdirs()
                val outFile = File(downloads, filename)
                FileOutputStream(outFile).use { it.write(bytes) }
                result.success(true)
            }
        } catch (e: Exception) {
            e.printStackTrace()
            result.success(false)
        }
    }

    private fun showOverlay(title: String, body: String, durationMs: Long): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            return false
        }

        runOnUiThread {
            val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            if (overlayView == null) {
                val container = LinearLayout(this).apply {
                    orientation = LinearLayout.VERTICAL
                    setPadding(dp(16), dp(12), dp(16), dp(12))
                    background = GradientDrawable().apply {
                        setColor(Color.parseColor("#EE1C1E22"))
                        cornerRadius = dp(12).toFloat()
                    }
                    elevation = dp(6).toFloat()
                }
                val titleView = TextView(this).apply {
                    setTextColor(Color.WHITE)
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                    typeface = Typeface.DEFAULT_BOLD
                }
                val bodyView = TextView(this).apply {
                    setTextColor(Color.parseColor("#D1D5DB"))
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                }
                container.addView(titleView)
                container.addView(bodyView)

                val wrapper = FrameLayout(this).apply {
                    setPadding(dp(12), statusBarHeight() + dp(8), dp(12), 0)
                    addView(
                        container,
                        FrameLayout.LayoutParams(
                            ViewGroup.LayoutParams.MATCH_PARENT,
                            ViewGroup.LayoutParams.WRAP_CONTENT
                        )
                    )
                }

                val type =
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                    } else {
                        WindowManager.LayoutParams.TYPE_PHONE
                    }
                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    type,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                    PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.TOP or Gravity.START
                }

                windowManager.addView(wrapper, params)
                overlayView = wrapper
                overlayTitleView = titleView
                overlayBodyView = bodyView
            }

            overlayTitleView?.text = title
            overlayBodyView?.text = body

            overlayHideRunnable?.let { overlayHandler.removeCallbacks(it) }
            overlayHideRunnable = Runnable { dismissOverlay() }
            overlayHandler.postDelayed(overlayHideRunnable!!, durationMs)
        }

        return true
    }

    private fun dismissOverlay() {
        runOnUiThread {
            overlayHideRunnable?.let { overlayHandler.removeCallbacks(it) }
            overlayHideRunnable = null
            val view = overlayView ?: return@runOnUiThread
            val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            try {
                windowManager.removeView(view)
            } catch (_: Exception) {
            }
            overlayView = null
            overlayTitleView = null
            overlayBodyView = null
        }
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    private fun statusBarHeight(): Int {
        val resId = resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (resId > 0) resources.getDimensionPixelSize(resId) else dp(24)
    }
}

