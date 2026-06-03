package com.example.voxa.ime

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.view.View
import kotlin.math.max
import kotlin.random.Random

class VoiceWaveformView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val bars = FloatArray(BAR_COUNT) { MIN_LEVEL }
    private val random = Random(System.currentTimeMillis())
    private val rect = RectF()
    private val handler = Handler(Looper.getMainLooper())
    private var active = false

    private val tick = object : Runnable {
        override fun run() {
            if (!active) {
                return
            }
            for (index in bars.indices) {
                bars[index] = MIN_LEVEL + random.nextFloat() * (1f - MIN_LEVEL)
            }
            invalidate()
            handler.postDelayed(this, FRAME_DELAY_MS)
        }
    }

    init {
        paint.color = DEFAULT_COLOR
        paint.style = Paint.Style.FILL
    }

    fun setAccentColor(color: Int) {
        paint.color = color
        invalidate()
    }

    fun setActive(isActive: Boolean) {
        if (active == isActive) {
            return
        }
        active = isActive
        handler.removeCallbacks(tick)
        if (isActive) {
            handler.post(tick)
        } else {
            for (index in bars.indices) {
                bars[index] = MIN_LEVEL
            }
            invalidate()
        }
    }

    override fun onDetachedFromWindow() {
        handler.removeCallbacks(tick)
        super.onDetachedFromWindow()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (width <= 0 || height <= 0) {
            return
        }

        val availableWidth = width.toFloat()
        val gap = availableWidth * 0.012f
        val totalGap = gap * (BAR_COUNT - 1)
        val barWidth = max(4f, (availableWidth - totalGap) / BAR_COUNT)
        val centerY = height / 2f
        val maxBarHeight = height * 0.92f

        for (index in bars.indices) {
            val normalizedHeight = maxBarHeight * bars[index]
            val left = index * (barWidth + gap)
            val top = centerY - normalizedHeight / 2f
            val bottom = centerY + normalizedHeight / 2f
            rect.set(left, top, left + barWidth, bottom)
            canvas.drawRoundRect(rect, barWidth / 2f, barWidth / 2f, paint)
        }
    }

    companion object {
        private const val BAR_COUNT = 30
        private const val FRAME_DELAY_MS = 80L
        private const val MIN_LEVEL = 0.12f
        private const val DEFAULT_COLOR = 0xFF48624B.toInt()
    }
}
