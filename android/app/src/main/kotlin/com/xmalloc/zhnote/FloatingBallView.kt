package com.xmalloc.zhnote

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import kotlin.math.abs

/**
 * 悬浮球视图：绘制圆形球体与三条白色横线，支持拖动与点击。
 */
class FloatingBallView(context: Context) : View(context) {

    var onClick: (() -> Unit)? = null
    var onDragEnd: ((Int, Int) -> Unit)? = null

    private val density = resources.displayMetrics.density
    var sizePx: Int = (64 * density).toInt()
        private set

    /** 更新悬浮球大小（DP，5 - 96）。 */
    fun updateSize(sizeDp: Int) {
        val clamped = sizeDp.coerceIn(5, 96)
        val newSize = (clamped * density).toInt().coerceAtLeast(4)
        if (newSize == sizePx) {
            return
        }
        sizePx = newSize
        requestLayout()
    }

    private val ballPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(63, 81, 181)
        style = Paint.Style.FILL
    }
    private val barPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
    }
    private val barRect = RectF()

    private var dragging = false
    private var moved = false
    private var downRawX = 0f
    private var downRawY = 0f
    private var startX = 0
    private var startY = 0

    init {
        isClickable = true
        setLayerType(LAYER_TYPE_SOFTWARE, null)
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        setMeasuredDimension(sizePx, sizePx)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val centerX = width / 2f
        val centerY = height / 2f
        val radius = centerX - 2 * density

        ballPaint.setShadowLayer(5 * density, 0f, 2 * density, 0x55000000.toInt())
        canvas.drawCircle(centerX, centerY, radius, ballPaint)
        ballPaint.clearShadowLayer()

        val halfWidth = sizePx * 0.20f
        val barHeight = sizePx * 0.08f
        val spacing = sizePx * 0.14f
        for (index in -1..1) {
            val top = centerY + index * spacing - barHeight / 2
            barRect.set(centerX - halfWidth, top, centerX + halfWidth, top + barHeight)
            canvas.drawRoundRect(barRect, barHeight / 2, barHeight / 2, barPaint)
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        val params = layoutParams as? WindowManager.LayoutParams ?: return false
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                dragging = true
                moved = false
                downRawX = event.rawX
                downRawY = event.rawY
                startX = params.x
                startY = params.y
            }

            MotionEvent.ACTION_MOVE -> {
                if (!dragging) {
                    return false
                }
                val dx = event.rawX - downRawX
                val dy = event.rawY - downRawY
                if (abs(dx) > 6 * density || abs(dy) > 6 * density) {
                    moved = true
                }
                params.x = startX + dx.toInt()
                params.y = startY + dy.toInt()
                clampToScreen(params)
                val windowManager =
                    context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                windowManager.updateViewLayout(this, params)
            }

            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (dragging) {
                    if (!moved && event.action == MotionEvent.ACTION_UP) {
                        onClick?.invoke()
                    } else if (moved) {
                        onDragEnd?.invoke(params.x, params.y)
                    }
                }
                dragging = false
            }
        }
        return true
    }

    private fun clampToScreen(params: WindowManager.LayoutParams) {
        val metrics = resources.displayMetrics
        params.x = params.x.coerceIn(0, metrics.widthPixels - sizePx)
        params.y = params.y.coerceIn(0, metrics.heightPixels - sizePx)
    }
}
