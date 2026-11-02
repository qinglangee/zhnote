package com.xmalloc.zhnote

import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.provider.Settings
import android.view.Gravity
import android.view.WindowManager

/**
 * 悬浮球的创建、移除与位置持久化。
 */
object FloatingBallManager {

    private const val PREFS_NAME = "zhnote_floating_ball"
    private const val KEY_X = "position_x"
    private const val KEY_Y = "position_y"
    private const val DEFAULT_MARGIN_DP = 16

    private var ballView: FloatingBallView? = null

    fun hasPermission(context: Context): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            Settings.canDrawOverlays(context.applicationContext)
    }

    fun show(context: Context): Boolean {
        val appContext = context.applicationContext
        if (ballView != null) {
            return true
        }
        if (!hasPermission(appContext)) {
            return false
        }

        val windowManager =
            appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val view = FloatingBallView(appContext)
        val size = view.sizePx
        val metrics = appContext.resources.displayMetrics
        val margin = (DEFAULT_MARGIN_DP * appContext.resources.displayMetrics.density).toInt()
        val prefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        val x = prefs.getInt(KEY_X, metrics.widthPixels - size - margin)
            .coerceIn(0, metrics.widthPixels - size)
        val y = prefs.getInt(KEY_Y, metrics.heightPixels / 2 - size / 2)
            .coerceIn(0, metrics.heightPixels - size)

        val params = WindowManager.LayoutParams(
            size,
            size,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            this.x = x
            this.y = y
        }

        view.onClick = { openApp(appContext) }
        view.onDragEnd = { newX, newY ->
            prefs.edit().putInt(KEY_X, newX).putInt(KEY_Y, newY).apply()
        }

        return try {
            windowManager.addView(view, params)
            ballView = view
            true
        } catch (error: Exception) {
            false
        }
    }

    fun hide() {
        val view = ballView ?: return
        val windowManager =
            view.context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        try {
            windowManager.removeView(view)
        } catch (error: Exception) {
            // 视图已被移除时忽略。
        }
        ballView = null
    }

    fun isVisible(): Boolean = ballView != null

    private fun openApp(context: Context) {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: return
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        context.startActivity(intent)
    }
}
