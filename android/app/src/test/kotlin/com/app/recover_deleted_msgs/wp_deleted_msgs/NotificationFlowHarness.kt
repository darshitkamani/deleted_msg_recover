package com.app.recover_deleted_msgs.wp_deleted_msgs

import android.app.Application
import android.app.KeyguardManager
import android.app.Notification
import android.content.Context
import android.os.PowerManager
import android.os.Process
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.EventChannel
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import org.robolectric.Robolectric
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.shadows.ShadowLooper
import java.util.concurrent.ExecutorService
import java.util.concurrent.TimeUnit

/**
 * Stands in for the system's list of live notifications: a real NotificationListenerService only
 * gets one once it's bound to the OS, which never happens under test.
 */
@Implements(NotificationListenerService::class)
class ShadowActiveNotifications {
    companion object {
        @JvmStatic
        var active: List<StatusBarNotification> = emptyList()
    }

    @Implementation
    fun getActiveNotifications(): Array<StatusBarNotification> = active.toTypedArray()
}

/** One row of the messages table as the app would later show it. */
data class StoredMessage(
    val text: String,
    val status: String,
    val removedAt: Long?,
    val notifKey: String
) {
    val isDeleted get() = status == MessageStore.STATUS_DELETED
}

/**
 * Drives the REAL [NotificationListener] and the REAL [MessageStore] (real SQLite) the way
 * Android does: WhatsApp posts and cancels MessagingStyle notifications, the listener's 4s
 * grace timer fires, and the system's active-notification list changes underneath it. Only the
 * OS notification list is fake ([ShadowActiveNotifications]).
 */
class NotificationFlowHarness {

    private val app: Application = RuntimeEnvironment.getApplication()
    private val service: NotificationListener =
        Robolectric.buildService(NotificationListener::class.java).create().get()
    private val bgExecutor: ExecutorService =
        NotificationListener::class.java.getDeclaredField("bgExecutor")
            .apply { isAccessible = true }
            .get(service) as ExecutorService

    private val live = linkedMapOf<String, StatusBarNotification>()
    private val sender = Person.Builder().setName("Alice").build()

    /** Everything the listener told the Flutter side, in order (what the UI would have heard). */
    val events = mutableListOf<Map<String, Any?>>()

    init {
        ShadowActiveNotifications.active = emptyList()
        AppVisibility.isForeground = false
        screenOff()
        MonitorPrefs.setMonitored(app, MonitorPrefs.DEFAULT)
        EventBridge.attach(object : EventChannel.EventSink {
            override fun success(event: Any?) {
                @Suppress("UNCHECKED_CAST")
                events += event as Map<String, Any?>
            }
            override fun error(code: String?, message: String?, details: Any?) {}
            override fun endOfStream() {}
        })
    }

    fun eventsOfType(type: String) = events.filter { it["type"] == type }

    /** Forgets every message and notification, for runs that repeat many scripts. */
    fun reset() {
        live.clear()
        syncActive()
        events.clear()
        MessageStore.getInstance(app).writableDatabase.execSQL("DELETE FROM messages")
    }

    /** Phone locked with the screen off: the user can't be reading in WhatsApp here. */
    fun screenOff() {
        shadowOf(app.getSystemService(Context.POWER_SERVICE) as PowerManager).turnScreenOn(false)
        shadowOf(app.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).setKeyguardLocked(true)
    }

    /** Screen on and unlocked with another app in front: WhatsApp itself could be open. */
    fun screenOnUnlocked() {
        shadowOf(app.getSystemService(Context.POWER_SERVICE) as PowerManager).turnScreenOn(true)
        shadowOf(app.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).setKeyguardLocked(false)
    }

    /**
     * WhatsApp posts (or updates) the conversation notification [id] holding [messages].
     * The same [id] means the same notification key, as WhatsApp usually re-uses it.
     */
    fun post(id: Int, messages: List<Msg>, chat: String = "Alice"): String {
        val style = NotificationCompat.MessagingStyle(Person.Builder().setName("Me").build())
        messages.forEach { style.addMessage(it.text, it.timestamp, sender) }
        val notification = NotificationCompat.Builder(app, "chan")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(chat)
            .setStyle(style)
            .build()
        val sbn = statusBarNotification(id, notification)
        live[sbn.key] = sbn
        syncActive()
        service.onNotificationPosted(sbn)
        settle()
        tick()
        return sbn.key
    }

    /** The notification [key] goes away for [reason] (WhatsApp cancelling, a swipe, ...). */
    fun cancel(key: String, reason: Int = NotificationListenerService.REASON_APP_CANCEL) {
        val sbn = live.remove(key) ?: error("no live notification $key")
        syncActive()
        service.onNotificationRemoved(sbn, null, reason)
        tick()
    }

    /** Lets [millis] of wall time pass: fires the listener's grace-period timer if due. */
    fun advance(millis: Long) {
        ShadowLooper.idleMainLooper(millis, TimeUnit.MILLISECONDS)
        settle()
    }

    fun messages(): List<StoredMessage> {
        val out = mutableListOf<StoredMessage>()
        MessageStore.getInstance(app).readableDatabase.rawQuery(
            "SELECT text, status, removed_at, notif_key FROM messages ORDER BY timestamp, id", null
        ).use { c ->
            while (c.moveToNext()) {
                out += StoredMessage(
                    c.getString(0), c.getString(1),
                    if (c.isNull(2)) null else c.getLong(2), c.getString(3)
                )
            }
        }
        return out
    }

    fun message(text: String): StoredMessage =
        messages().singleOrNull { it.text == text } ?: error("expected exactly one \"$text\" in ${messages()}")

    /** Waits for the listener's background thread to finish everything queued so far. */
    private fun settle() {
        bgExecutor.submit {}.get(10, TimeUnit.SECONDS)
        ShadowLooper.idleMainLooper() // delivers queued EventBridge events
    }

    /** Keeps successive events a few real milliseconds apart, as they are on a real phone. */
    private fun tick() = Thread.sleep(3)

    private fun syncActive() {
        ShadowActiveNotifications.active = live.values.toList()
    }

    private fun statusBarNotification(id: Int, notification: Notification): StatusBarNotification {
        val ctor = StatusBarNotification::class.java.declaredConstructors.first {
            it.parameterCount == 10 && it.parameterTypes[6] == Notification::class.java
        }
        return ctor.newInstance(
            "com.whatsapp", "com.whatsapp", id, null, 1000, 1, notification,
            Process.myUserHandle(), null, System.currentTimeMillis()
        ) as StatusBarNotification
    }

    data class Msg(val text: String, val timestamp: Long)

    companion object {
        /** MessageStore is a process-wide singleton; each test needs a fresh database. */
        fun resetStore() {
            val field = MessageStore::class.java.getDeclaredField("instance").apply { isAccessible = true }
            (field.get(null) as? MessageStore)?.close()
            field.set(null, null)
        }
    }
}
