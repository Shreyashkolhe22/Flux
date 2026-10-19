package com.example.flux

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

enum class WidgetState(val label: String, val error: Boolean = false) {
    IDLE("CLIPBOARD"),
    SENDING("SENDING"),
    SENT("SENT"),
    FAILED("FAILED", true),
    EMPTY("EMPTY", true),
    TEXT_ONLY("TEXT ONLY", true),
    NOT_PAIRED("NOT PAIRED", true),
}

/**
 * Draws the home-screen widget: black rounded square, dotted ring, the red send
 * button and a dot-matrix label. Everything is drawn here, so it scales to any size.
 */
object WidgetRenderer {
    private const val BG = 0xFF0F0F0F.toInt()
    private val RED = Color.parseColor("#D71921")

    @Suppress("UNUSED_PARAMETER")
    fun render(context: Context, width: Int, height: Int, state: WidgetState, frame: Int): Bitmap {
        val w = width.coerceIn(120, 900)
        val h = height.coerceIn(120, 900)
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val u = min(w, h).toFloat() // unit: the shorter side

        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = BG }
        c.drawRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), u * 0.2f, u * 0.2f, fill)

        val white = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
        val grey = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#8E8E8E") }
        val red = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = RED }

        // FLUX. wordmark, top left
        val markCell = u * 0.017f
        DotFont.draw(c, "FLUX.", u * 0.1f, u * 0.09f, markCell, white, red)

        // ring + centre
        val cx = w / 2f
        val cy = h * 0.5f + u * 0.02f
        val radius = u * 0.26f
        drawRing(c, cx, cy, radius, state, frame, white, grey, red)
        drawCentre(c, cx, cy, u, state, red)

        // label, bottom centre
        val label = state.label
        val cols = DotFont.columns(label).coerceAtLeast(1)
        val cell = min(u * 0.016f, w * 0.7f / cols)
        val textW = cols * cell
        DotFont.draw(c, label, cx - textW / 2f, h - u * 0.1f - 7 * cell, cell, if (state.error) red else white)
        return bmp
    }

    private fun drawRing(
        c: Canvas, cx: Float, cy: Float, r: Float, state: WidgetState, frame: Int,
        white: Paint, grey: Paint, red: Paint,
    ) {
        val dots = 32
        val dotR = r * 0.065f
        val rot = if (state == WidgetState.SENDING) frame * (2 * PI.toFloat() / 24f) else 0f
        val redArc = when (state) {
            WidgetState.SENDING -> 5
            WidgetState.SENT -> 7
            else -> 0
        }
        for (i in 0 until dots) {
            val a = rot + i * 2 * PI.toFloat() / dots
            val head = redArc > 0 && i >= dots - redArc
            val p = when {
                head -> red
                state.error -> Paint(red).apply { alpha = 120 }
                state == WidgetState.SENDING -> Paint(white).apply { alpha = (40 + 150f * i / dots).toInt() }
                state == WidgetState.IDLE -> grey
                else -> white
            }
            c.drawCircle(cx + cos(a) * r, cy + sin(a) * r, if (head) dotR * 1.25f else dotR, p)
        }
    }

    private fun drawCentre(c: Canvas, cx: Float, cy: Float, u: Float, state: WidgetState, red: Paint) {
        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
            strokeWidth = u * 0.03f
        }
        when (state) {
            WidgetState.IDLE, WidgetState.SENDING -> {
                // the red send button with its arrow, like the one in the app
                c.drawCircle(cx, cy, u * 0.14f, red)
                stroke.color = Color.WHITE
                val s = u * 0.06f
                c.drawLine(cx - s, cy, cx + s, cy, stroke)
                c.drawLine(cx + s * 0.15f, cy - s * 0.9f, cx + s, cy, stroke)
                c.drawLine(cx + s * 0.15f, cy + s * 0.9f, cx + s, cy, stroke)
            }
            WidgetState.SENT -> {
                stroke.color = RED
                stroke.strokeWidth = u * 0.045f
                val s = u * 0.09f
                c.drawLine(cx - s, cy + s * 0.05f, cx - s * 0.25f, cy + s * 0.75f, stroke)
                c.drawLine(cx - s * 0.25f, cy + s * 0.75f, cx + s, cy - s * 0.7f, stroke)
            }
            else -> {
                // "!" for every problem state
                stroke.color = RED
                stroke.strokeWidth = u * 0.05f
                c.drawLine(cx, cy - u * 0.1f, cx, cy + u * 0.03f, stroke)
                c.drawCircle(cx, cy + u * 0.095f, u * 0.03f, red)
            }
        }
    }
}
