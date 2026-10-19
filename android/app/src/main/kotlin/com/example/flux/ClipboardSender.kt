package com.example.flux

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.util.UUID

/**
 * Sends text from the widget or quick-settings tile to the paired laptop without
 * starting the Flutter app. It reads the pairing the app saved and adds the item to
 * the app history, so Recent and the automatic retry work as usual.
 */
object ClipboardSender {
    enum class Result { OK, NOT_PAIRED, BAD_KEY, UNREACHABLE, ERROR }

    // The Flutter shared_preferences plugin keeps its data in this file, keys prefixed "flutter.".
    private const val PREFS = "FlutterSharedPreferences"
    private const val KEY_PAIRING = "flutter.pairing"
    private const val KEY_HISTORY = "flutter.history"
    private const val MAX_HISTORY = 50

    fun send(context: Context, text: String): Result {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val pairing = try {
            JSONObject(prefs.getString(KEY_PAIRING, null) ?: return Result.NOT_PAIRED)
        } catch (e: Exception) {
            return Result.NOT_PAIRED
        }
        val key = pairing.optString("key")
        val port = pairing.optInt("port", 3000)
        val activeIp = pairing.optString("activeIp")
        if (key.isEmpty() || activeIp.isEmpty()) return Result.NOT_PAIRED

        val ips = linkedSetOf(activeIp)
        pairing.optJSONArray("ips")?.let { for (i in 0 until it.length()) ips.add(it.getString(i)) }

        val type = if (isLink(text)) "link" else "text"
        val id = UUID.randomUUID().toString()
        WifiBinding.bind(context)

        var result = Result.UNREACHABLE
        for (ip in ips) {
            val r = post(ip, port, key, id, type, text)
            if (r == Result.UNREACHABLE) continue // try the next known address
            result = r
            if (r == Result.OK && ip != activeIp) {
                pairing.put("activeIp", ip)
                prefs.edit().putString(KEY_PAIRING, pairing.toString()).apply()
            }
            break
        }

        addToHistory(prefs, id, type, text, result)
        return result
    }

    internal fun isLink(text: String): Boolean {
        val t = text.trim()
        if (t.any { it.isWhitespace() }) return false
        return try {
            val u = URI(t)
            (u.scheme == "http" || u.scheme == "https") && !u.host.isNullOrEmpty()
        } catch (e: Exception) {
            false
        }
    }

    private fun post(ip: String, port: Int, key: String, id: String, type: String, text: String): Result {
        var conn: HttpURLConnection? = null
        return try {
            conn = (URL("http://$ip:$port/send").openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 2500
                readTimeout = 6000
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("X-Key", key)
            }
            val body = JSONObject().put("id", id).put("type", type).put("data", text).toString()
            conn.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            when (conn.responseCode) {
                200 -> Result.OK
                401 -> Result.BAD_KEY
                else -> Result.ERROR
            }
        } catch (e: IOException) {
            Result.UNREACHABLE // refused, timed out, no route
        } catch (e: Exception) {
            Result.ERROR
        } finally {
            conn?.disconnect()
        }
    }

    /** Same JSON the Dart HistoryItem reads: newest first, capped. */
    @Synchronized
    private fun addToHistory(prefs: SharedPreferences, id: String, type: String, text: String, result: Result) {
        val item = JSONObject()
            .put("id", id)
            .put("type", type)
            .put("data", text)
            .put("label", text.replace('\n', ' '))
            .put("ts", System.currentTimeMillis())
            .put("status", if (result == Result.OK) "sent" else "failed")
            // Only "laptop unreachable" is retried by the app by itself.
            .put("auto", result == Result.UNREACHABLE)
        val old = try {
            JSONArray(prefs.getString(KEY_HISTORY, "[]"))
        } catch (e: Exception) {
            JSONArray()
        }
        val list = JSONArray().put(item)
        for (i in 0 until minOf(old.length(), MAX_HISTORY - 1)) list.put(old.get(i))
        prefs.edit().putString(KEY_HISTORY, list.toString()).apply()
    }
}
