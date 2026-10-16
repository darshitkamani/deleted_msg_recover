package com.app.recover_deleted_msgs.wp_deleted_msgs

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

    private const val KEY_ALERTS_ENABLED = "alerts_enabled"

    /** Whether to post a notification when a message is deleted or edited (see [AlertNotifier]). */
    fun alertsEnabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ALERTS_ENABLED, true)

    fun setAlertsEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_ALERTS_ENABLED, enabled).apply()
    }

    private const val KEY_OVERLAY_ENABLED = "overlay_enabled"
    private const val KEY_OVERLAY_AD_UNIT = "overlay_native_ad_unit"

    /**
     * Whether to show the "message deleted" popup over other apps (see [DeletedOverlay]). Also
     * needs the "Display over other apps" permission; this is only the user's own on/off choice.
     */
    fun overlayEnabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_OVERLAY_ENABLED, true)

    fun setOverlayEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_OVERLAY_ENABLED, enabled).apply()
    }

    /**
     * Native ad unit for the popup's expanded card, or null for no ad. Written by the Flutter
     * side (AdsService) from the hosted ad config, so it follows the same on/off switches and
     * debug test ids -- and is still there when the popup shows with no Flutter engine running.
     */
    private const val KEY_OVERLAY_AUTO_EXPAND = "overlay_auto_expand"
    private const val KEY_OVERLAY_AUTO_EXPAND_INTERVAL_MS = "overlay_auto_expand_interval_ms"

    /**
     * Whether the popup opens fully expanded (with its ad) straight away rather than as a small
     * card that expands on tap -- and at most how often. From the hosted config, like the ad unit.
     */
    fun overlayAutoExpand(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_OVERLAY_AUTO_EXPAND, false)

    fun overlayAutoExpandIntervalMs(context: Context): Long =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getLong(KEY_OVERLAY_AUTO_EXPAND_INTERVAL_MS, 180_000L)

    fun setOverlayAutoExpand(context: Context, enabled: Boolean, intervalMs: Long) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_OVERLAY_AUTO_EXPAND, enabled)
            .putLong(KEY_OVERLAY_AUTO_EXPAND_INTERVAL_MS, intervalMs)
            .apply()
    }

    fun overlayAdUnitId(context: Context): String? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_OVERLAY_AD_UNIT, null)

    fun setOverlayAdUnitId(context: Context, adUnitId: String?) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_OVERLAY_AD_UNIT, adUnitId).apply()
    }
}
