package com.example.flux

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/** Remembers what the widget should show, so a redraw (resize, reboot) keeps the state. */
object WidgetStore {
    private const val PREFS = "flux_widget"

    fun set(context: Context, state: WidgetState) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("state", state.name)
            .putLong("ts", System.currentTimeMillis())
            .apply()
    }

    /** Result states fade back to idle after a few seconds; "sending" stays until done. */
    fun current(context: Context): WidgetState {
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val state = try {
            WidgetState.valueOf(p.getString("state", null) ?: return WidgetState.IDLE)
        } catch (e: Exception) {
            return WidgetState.IDLE
        }
        val age = System.currentTimeMillis() - p.getLong("ts", 0)
        return if (state != WidgetState.SENDING && age > 4000) WidgetState.IDLE else state
    }
}

/** Home-screen widget: one tap sends whatever is on the clipboard to the laptop. */
class FluxWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) update(context, manager, id, WidgetStore.current(context), 0)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context, manager: AppWidgetManager, appWidgetId: Int, newOptions: android.os.Bundle,
    ) {
        update(context, manager, appWidgetId, WidgetStore.current(context), 0)
    }

    companion object {
        /** Shows [state] on every placed widget. [frame] drives the spinner while sending. */
        fun updateAll(context: Context, state: WidgetState, frame: Int = 0) {
            WidgetStore.set(context, state)
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, FluxWidgetProvider::class.java))
            for (id in ids) update(context, manager, id, state, frame)
        }

        private fun update(context: Context, manager: AppWidgetManager, id: Int, state: WidgetState, frame: Int) {
            val options = manager.getAppWidgetOptions(id)
            val density = context.resources.displayMetrics.density
            // The launcher reports a min and a max size. Which one applies depends on the
            // orientation: in portrait the widget is as wide as MIN_WIDTH but as tall as
            // MAX_HEIGHT. Using the wrong pair stretches the picture.
            val portrait = context.resources.configuration.orientation !=
                android.content.res.Configuration.ORIENTATION_LANDSCAPE
            val minW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 110)
            val minH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110)
            val maxW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, minW)
            val maxH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, minH)
            val wDp = if (portrait) minW else maxW
            val hDp = if (portrait) maxH else minH

            val views = RemoteViews(context.packageName, R.layout.flux_widget)
            views.setImageViewBitmap(
                R.id.widget_image,
                WidgetRenderer.render(context, (wDp * density).toInt(), (hDp * density).toInt(), state, frame),
            )
            views.setOnClickPendingIntent(R.id.widget_root, sendIntent(context))
            manager.updateAppWidget(id, views)
        }

        fun sendIntent(context: Context): PendingIntent {
            val intent = Intent(context, SendClipboardActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION)
            return PendingIntent.getActivity(
                context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
