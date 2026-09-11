package com.recoverdeletedmessages.app

import android.content.Context

/** Which packages the notification listener should actually record. */
object MonitorPrefs {
    private const val PREFS = "recover_prefs"
    private const val KEY_MONITORED = "monitored_packages"
    val DEFAULT = setOf("com.whatsapp", "com.whatsapp.w4b")

    fun getMonitored(context: Context): Set<String> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return prefs.getStringSet(KEY_MONITORED, DEFAULT) ?: DEFAULT
    }

    fun setMonitored(context: Context, apps: Set<String>) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().putStringSet(KEY_MONITORED, apps).apply()
    }

    fun isMonitored(context: Context, pkg: String): Boolean = getMonitored(context).contains(pkg)
}
