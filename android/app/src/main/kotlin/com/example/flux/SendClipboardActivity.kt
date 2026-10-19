package com.example.flux

import android.app.Activity
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.widget.Toast

/**
 * Opened by the widget and the quick-settings tile. It has no screen: Android only
 * lets an app read the clipboard while it is on screen with focus, so this
 * see-through activity reads it, sends it, updates the widget and closes.
 */
class SendClipboardActivity : Activity() {
    private val main = Handler(Looper.getMainLooper())
    private var handled = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        overridePendingTransition(0, 0)
    }

    // The clipboard can only be read once the window has focus.
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (!hasFocus || handled) return
        handled = true
        run()
    }

    private fun run() {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = clipboard.primaryClip
        if (clip == null || clip.itemCount == 0) {
            finishWith(WidgetState.EMPTY, "Clipboard is empty")
            return
        }
        if (!clip.description.hasMimeType("text/*")) {
            finishWith(WidgetState.TEXT_ONLY, "Only text and links can be sent from here")
            return
        }
        val text = clip.getItemAt(0).coerceToText(this).toString().trim()
        if (text.isEmpty()) {
            finishWith(WidgetState.EMPTY, "Clipboard is empty")
            return
        }
        sendText(text)
    }

    private fun sendText(text: String) {
        val app = applicationContext

        // Spin the widget ring while the request runs.
        var frame = 0
        val ticker = object : Runnable {
            override fun run() {
                FluxWidgetProvider.updateAll(app, WidgetState.SENDING, frame++)
                main.postDelayed(this, 110)
            }
        }
        main.post(ticker)

        Thread {
            val result = ClipboardSender.send(app, text)
            main.post {
                main.removeCallbacks(ticker)
                when (result) {
                    ClipboardSender.Result.OK -> finishWith(WidgetState.SENT, null)
                    ClipboardSender.Result.NOT_PAIRED ->
                        finishWith(WidgetState.NOT_PAIRED, "Pair a laptop in Flux first")
                    ClipboardSender.Result.BAD_KEY ->
                        finishWith(WidgetState.FAILED, "Laptop key changed. Scan the QR in Flux again.")
                    ClipboardSender.Result.UNREACHABLE ->
                        finishWith(WidgetState.FAILED, "Laptop not reachable. Flux will retry when you open it.")
                    ClipboardSender.Result.ERROR ->
                        finishWith(WidgetState.FAILED, "Couldn't send. Try again.")
                }
            }
        }.start()
    }

    private fun finishWith(state: WidgetState, message: String?) {
        val app = applicationContext
        FluxWidgetProvider.updateAll(app, state)
        if (message != null) Toast.makeText(app, message, Toast.LENGTH_LONG).show()
        // Back to the idle look after a moment (the process outlives this activity).
        Handler(Looper.getMainLooper()).postDelayed({ FluxWidgetProvider.updateAll(app, WidgetState.IDLE) }, 3500)
        finish()
        overridePendingTransition(0, 0)
    }
}
