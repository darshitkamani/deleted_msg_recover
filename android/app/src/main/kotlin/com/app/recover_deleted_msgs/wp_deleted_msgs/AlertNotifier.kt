package com.app.recover_deleted_msgs.wp_deleted_msgs

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Posts this app's own "a message was deleted / edited" notifications.
 *
 * Runs from [NotificationListener], which keeps working with no Flutter engine alive, so these
 * are plain native notifications rather than anything driven from Dart. Skipped while this
 * app's UI is on screen -- the Deleted tab refreshes live then, and a heads-up on top of it is
 * just noise.
 */
object AlertNotifier {

    private const val CHANNEL_ID = "message_alerts"
    private const val GROUP_KEY = "message_alerts"

    /** Intent extra telling [MainActivity] which screen a tapped alert should open. */
    const val EXTRA_OPEN_TARGET = "open_target"
    const val TARGET_DELETED = "deleted"

    /** [possible]: a possible deletion (MessageStore.SOURCE_POSSIBLE), worded as "may have". */
    fun notifyDeleted(
        context: Context,
        rowId: Long,
        chatTitle: String,
        sender: String?,
        text: String?,
        possible: Boolean = false
    ) {
        val body = text?.takeIf { it.isNotBlank() } ?: context.getString(R.string.alert_message_fallback)
        val single = if (possible) R.string.alert_possibly_deleted_title else R.string.alert_deleted_title
        val group = if (possible) R.string.alert_possibly_deleted_title_group else R.string.alert_deleted_title_group
        post(
            context,
            id = notificationId(rowId, edited = false),
            title = title(context, single, group, chatTitle, sender),
            body = body,
            bigText = body
        )
    }

    fun notifyEdited(
        context: Context,
        rowId: Long,
        chatTitle: String,
        sender: String?,
        previousText: String,
        newText: String
    ) {
        post(
            context,
            id = notificationId(rowId, edited = true),
            title = title(context, R.string.alert_edited_title, R.string.alert_edited_title_group, chatTitle, sender),
            body = newText,
            bigText = context.getString(R.string.alert_edited_body, previousText, newText)
        )
    }

    /**
     * "Alice deleted a message" for a 1:1 chat, where the stored sender is the chat title itself
     * (or missing); "Raj deleted a message in Family" when a group member did it.
     */
    private fun title(context: Context, single: Int, group: Int, chatTitle: String, sender: String?): String =
        if (sender.isNullOrBlank() || sender == chatTitle) context.getString(single, chatTitle)
        else context.getString(group, sender, chatTitle)

    private fun post(context: Context, id: Int, title: String, body: String, bigText: String) {
        if (AppVisibility.isForeground) return
        if (!MonitorPrefs.alertsEnabled(context)) return
        val manager = NotificationManagerCompat.from(context)
        // Covers both a denied POST_NOTIFICATIONS (Android 13+) and the user muting the app.
        if (!manager.areNotificationsEnabled()) return
        ensureChannel(context)

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_message_alert)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            // Message text can be private; show only the title on a secure lock screen.
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setGroup(GROUP_KEY)
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)
            .setContentIntent(openDeletedFeed(context, id))
            .build()
        try {
            manager.notify(id, notification)
        } catch (e: SecurityException) {
            // Permission revoked between the check above and here; nothing to do.
        }
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.alert_channel_name),
                NotificationManager.IMPORTANCE_HIGH
            ).apply { description = context.getString(R.string.alert_channel_description) }
        )
    }

    private fun openDeletedFeed(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_OPEN_TARGET, TARGET_DELETED)
        }
        return PendingIntent.getActivity(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /** One slot per message and kind, so a repeat for the same message replaces, not stacks. */
    private fun notificationId(rowId: Long, edited: Boolean): Int =
        (rowId * 2 + if (edited) 1 else 0).toInt()
}
