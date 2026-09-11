package com.app.recover_deleted_msgs.wp_deleted_msgs

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Passes live capture/deletion events from the NotificationListener service
 * to the Flutter EventChannel, when the app is in the foreground.
 * Both run in the same process, so a plain in-memory sink reference is enough.
 */
object EventBridge {
    private var sink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun attach(newSink: EventChannel.EventSink?) {
        sink = newSink
    }

    fun emit(event: Map<String, Any?>) {
        val current = sink ?: return
        mainHandler.post {
            try {
                current.success(event)
            } catch (_: Exception) {
            }
        }
    }
}
