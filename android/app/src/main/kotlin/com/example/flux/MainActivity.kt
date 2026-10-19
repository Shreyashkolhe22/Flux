package com.example.flux

import android.app.StatusBarManager
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.graphics.drawable.Icon
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flux/network")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "bindWifi" -> result.success(WifiBinding.bind(this))
                    "pinWidget" -> result.success(pinWidget())
                    "addTile" -> result.success(addTile())
                    else -> result.notImplemented()
                }
            }
    }

    /** Asks the launcher to add the widget. Returns "requested" or "unsupported". */
    private fun pinWidget(): String {
        val manager = AppWidgetManager.getInstance(this)
        if (!manager.isRequestPinAppWidgetSupported) return "unsupported"
        manager.requestPinAppWidget(ComponentName(this, FluxWidgetProvider::class.java), null, null)
        return "requested"
    }

    /** Android 13+ can ask the user to add the tile; older versions add it by hand. */
    private fun addTile(): String {
        if (Build.VERSION.SDK_INT < 33) return "manual"
        val statusBar = getSystemService(StatusBarManager::class.java)
        statusBar.requestAddTileService(
            ComponentName(this, SendClipboardTileService::class.java),
            "Send clipboard",
            Icon.createWithResource(this, R.drawable.ic_tile),
            mainExecutor,
        ) { }
        return "requested"
    }
}
