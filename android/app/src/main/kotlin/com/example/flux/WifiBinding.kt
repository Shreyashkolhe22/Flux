package com.example.flux

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities

/**
 * Sends this app's traffic over the Wi-Fi network, even when that Wi-Fi has no
 * internet. Without this, Android may route the app over mobile data and the
 * laptop (a local address) becomes unreachable, although a browser still works.
 *
 * Returns true if bound to Wi-Fi. If there is no Wi-Fi client connection (for
 * example the phone is the hotspot) the binding is cleared so the default
 * routing is used, which reaches hotspot clients normally.
 */
object WifiBinding {
    @Suppress("DEPRECATION")
    fun bind(context: Context): Boolean {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        return try {
            val wifi = cm.allNetworks.firstOrNull { net ->
                cm.getNetworkCapabilities(net)?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
            }
            cm.bindProcessToNetwork(wifi)
            wifi != null
        } catch (e: Exception) {
            false
        }
    }
}
