package com.recoverdeletedmessages.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

private const val KEEP_ALIVE_CHANNEL_ID = "recover_keep_alive"
private const val KEEP_ALIVE_NOTIFICATION_ID = 9101

/**
 * A plain foreground service whose only job is to hold this app's process
 * at foreground priority, so Android's out-of-memory killer -- and OEM
 * battery managers that kill background apps more aggressively than stock
 * Android -- are much less likely to take it down while the phone is idle.
 * All actual message-capture logic lives in NotificationListener; this
 * service does nothing on its own besides existing.
 */
class KeepAliveService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForegroundCompat()
        return START_STICKY
    }

    private fun startForegroundCompat() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                KEEP_ALIVE_CHANNEL_ID,
                "Background listener status",
                NotificationManager.IMPORTANCE_MIN
            )
            nm.createNotificationChannel(channel)
        }
        val notification = NotificationCompat.Builder(this, KEEP_ALIVE_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setContentTitle("Watching for deleted WhatsApp messages")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                KEEP_ALIVE_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(KEEP_ALIVE_NOTIFICATION_ID, notification)
        }
    }
}

object KeepAliveStarter {
    fun start(context: Context) {
        val intent = Intent(context, KeepAliveService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        } catch (_: Exception) {
        }
    }
}
