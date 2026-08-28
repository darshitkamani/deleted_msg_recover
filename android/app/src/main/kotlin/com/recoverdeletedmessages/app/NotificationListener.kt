package com.recoverdeletedmessages.app

import android.app.Notification
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import android.webkit.MimeTypeMap
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

/** A media attachment recovered from a notification, ready to store. */
private data class ExtractedMedia(val path: String, val type: String, val mime: String)

private const val PKG_WHATSAPP = "com.whatsapp"
private const val PKG_WHATSAPP_BUSINESS = "com.whatsapp.w4b"

// Filter logcat with `adb logcat -s NotifCapture` (or `flutter logs`, which
// shows every tag) to see exactly what happens to each WhatsApp notification
// as it comes in -- which package/title it belongs to, why it was skipped
// if it was, and whether a row actually got written to the DB.
private const val TAG = "NotifCapture"

/**
 * How long to wait after a notification disappears before deciding it was
 * actually deleted. WhatsApp frequently reissues a conversation's
 * notification under a brand new key as part of totally normal behavior
 * (a media download finishing, another message arriving, the thread being
 * re-ranked) -- each reissue looks identical to a real removal from here.
 * If a fresh notification for the same chat shows up again within this
 * window, we treat the "removal" as churn, not a deletion.
 */
private const val REMOVAL_GRACE_MS = 4000L

class NotificationListener : NotificationListenerService() {

    private val handler = Handler(Looper.getMainLooper())
    // NotificationListenerService delivers every callback on the main thread.
    // A backlog of many messages (e.g. reconnecting after being killed while
    // WhatsApp kept receiving) would otherwise process entirely on that
    // thread, back-to-back -- SQLite writes and media file copies for dozens
    // of notifications in a row is exactly what freezes the UI (and can ANR)
    // right at launch. Everything that actually touches disk runs here instead.
    private val bgExecutor = Executors.newSingleThreadExecutor()

    override fun onListenerConnected() {
        super.onListenerConnected()
        // Deliberately NOT starting the keep-alive foreground service here.
        // This callback can fire in a stone-cold process the system spun up
        // purely to rebind the listener -- e.g. right after a reinstall --
        // with no Activity involved at all. Android requires startForeground()
        // within 5 seconds of startForegroundService(), a clock that starts
        // the instant it's called; on a slow device mid cold-start (dex
        // loading, ART compilation, profile installation), that budget can
        // be blown before our code gets a real turn on the CPU, which kills
        // the whole process outright (RemoteServiceException) regardless of
        // how little work we do here. MainActivity.onResume() starts this
        // service instead, which only ever runs once Flutter/the UI is
        // already up -- a process that's demonstrably warm.
        // activeNotifications is itself a synchronous Binder IPC call. With a
        // backlog of messages -- especially ones carrying embedded images in
        // their extras -- marshaling that payload can take seconds on its
        // own, so even fetching the list must happen off the main thread,
        // not just the per-notification processing.
        Log.i(TAG, "onListenerConnected")
        bgExecutor.execute {
            val notifications = try {
                activeNotifications
            } catch (e: Exception) {
                Log.w(TAG, "Could not read activeNotifications backlog: ${e.message}")
                null
            }
            Log.d(TAG, "Backlog on connect: ${notifications?.size ?: 0} active notification(s)")
            notifications?.forEach { sbn -> handlePosted(sbn) }
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName == PKG_WHATSAPP || sbn.packageName == PKG_WHATSAPP_BUSINESS) {
            Log.d(
                TAG,
                "posted pkg=${sbn.packageName} key=${sbn.key} ongoing=${sbn.isOngoing} " +
                    "title=${sbn.notification?.extras?.getCharSequence(Notification.EXTRA_TITLE)}"
            )
            dumpNotificationDetails(sbn)
        }
        bgExecutor.execute { handlePosted(sbn) }
    }

    /**
     * Dumps every field this StatusBarNotification/Notification actually
     * carries -- id/tag/postTime/channel/category/visibility/actions and
     * every key in the extras Bundle -- to logcat. Not used for capture
     * logic itself, purely so we can see everything WhatsApp is sending and
     * go looking for a signal beyond what NotificationCompat.MessagingStyle
     * already parses for us (e.g. whether a "read" state is exposed
     * anywhere, or a per-action affordance we're not otherwise seeing).
     */
    private fun dumpNotificationDetails(sbn: StatusBarNotification) {
        try {
            val n = sbn.notification ?: return
            Log.d(
                TAG,
                "  [dump] id=${sbn.id} tag=${sbn.tag} postTime=${sbn.postTime} " +
                    "isClearable=${sbn.isClearable} groupKey=${sbn.groupKey}"
            )
            Log.d(
                TAG,
                "  [dump] channelId=${n.channelId} category=${n.category} " +
                    "visibility=${n.visibility} priority=${n.priority} " +
                    "group=${n.group} sortKey=${n.sortKey} `when`=${n.`when`} " +
                    "flags=0x${Integer.toHexString(n.flags)}"
            )
            val actions = n.actions
            if (actions.isNullOrEmpty()) {
                Log.d(TAG, "  [dump] actions=none")
            } else {
                for (a in actions) {
                    val showsUi = a.extras?.getBoolean("android.support.action.showsUserInterface")
                    val hasRemoteInput = !a.remoteInputs.isNullOrEmpty()
                    Log.d(
                        TAG,
                        "  [dump] action title=\"${a.title}\" semanticAction=${a.semanticAction} " +
                            "showsUserInterface=$showsUi hasRemoteInput=$hasRemoteInput"
                    )
                }
            }
            val extras = n.extras ?: Bundle()
            if (extras.isEmpty) {
                Log.d(TAG, "  [dump] extras=empty")
            } else {
                for (key in extras.keySet().sorted()) {
                    val value = try {
                        extras.get(key)
                    } catch (e: Exception) {
                        "<unreadable: ${e.message}>"
                    }
                    // Bitmaps/Parcelable arrays print as noisy hashes/large
                    // dumps that don't tell us anything useful here -- log
                    // just their type so the interesting scalar/text extras
                    // aren't buried.
                    val shown = when (value) {
                        is CharSequence, is Number, is Boolean -> value
                        null -> "null"
                        else -> "<${value.javaClass.simpleName}>"
                    }
                    Log.d(TAG, "  [dump] extras[$key] = $shown")
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "  [dump] failed: ${e.message}")
        }
    }

    override fun onNotificationRemoved(
        sbn: StatusBarNotification,
        rankingMap: RankingMap?,
        reason: Int
    ) {
        val pkg = sbn.packageName
        if (pkg != PKG_WHATSAPP && pkg != PKG_WHATSAPP_BUSINESS) return

        Log.d(TAG, "removed pkg=$pkg key=${sbn.key} reason=${describeReason(reason)}")
        val notifKey = sbn.key
        val removedAt = System.currentTimeMillis()
        handler.postDelayed({
            bgExecutor.execute { resolveRemoval(notifKey, removedAt) }
        }, REMOVAL_GRACE_MS)
    }

    private fun resolveRemoval(notifKey: String, removedAt: Long) {
        val store = MessageStore.getInstance(applicationContext)
        val results = store.markRemoved(notifKey, removedAt)
        Log.d(TAG, "resolveRemoval key=$notifKey -> ${results.size} chat(s) affected")
        for (r in results) {
            Log.i(TAG, "Message => REMOVE chat=\"${r.chatTitle}\" text=${r.text?.take(60)}")
            EventBridge.emit(
                mapOf(
                    "type" to "removed",
                    "chatKey" to r.chatKey,
                    "chatTitle" to r.chatTitle,
                    "text" to r.text
                )
            )
        }
    }

    private fun handlePosted(sbn: StatusBarNotification) {
        val pkg = sbn.packageName
        if (pkg != PKG_WHATSAPP && pkg != PKG_WHATSAPP_BUSINESS) return
        if (!MonitorPrefs.isMonitored(applicationContext, pkg)) {
            Log.d(TAG, "skip key=${sbn.key}: $pkg is not enabled in Settings")
            return
        }

        val notification = sbn.notification
        if (notification == null) {
            Log.d(TAG, "skip key=${sbn.key}: sbn.notification was null")
            return
        }
        // Media download/upload progress notifications and group summaries
        // are not chat messages -- capturing them creates fake "chats" that
        // look deleted the instant WhatsApp clears them, which is normal.
        if (sbn.isOngoing) {
            Log.d(TAG, "skip key=${sbn.key}: ongoing (progress) notification")
            return
        }
        if (notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) {
            Log.d(TAG, "skip key=${sbn.key}: group summary notification")
            return
        }

        val extras = notification.extras ?: Bundle()

        val style = try {
            NotificationCompat.MessagingStyle.extractMessagingStyleFromNotification(notification)
        } catch (e: Exception) {
            Log.w(TAG, "skip key=${sbn.key}: failed to extract MessagingStyle: ${e.message}")
            null
        }
        // Only genuine conversation notifications use MessagingStyle. WhatsApp's
        // own system notifications (download progress, backup status, missed
        // calls) use a plain title/text format and are skipped entirely.
        if (style == null || style.messages.isEmpty()) {
            Log.d(TAG, "skip key=${sbn.key}: not a MessagingStyle conversation (system/status notification)")
            return
        }

        val isGroup = extras.getBoolean(Notification.EXTRA_IS_GROUP_CONVERSATION, false)
        val title = (extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)
            ?: extras.getCharSequence(Notification.EXTRA_TITLE))?.toString()
        if (title == null) {
            Log.d(TAG, "skip key=${sbn.key}: no conversation/notification title present")
            return
        }
        val chatKey = "$pkg|$title"
        Log.d(TAG, "handling key=${sbn.key} chat=\"$title\" group=$isGroup messages=${style.messages.size}")

        val store = MessageStore.getInstance(applicationContext)
        store.upsertChat(chatKey, pkg, title, isGroup)

        var inserted = false
        val lastMessage = style.messages.lastOrNull()
        for (msg in style.messages) {
            val text = msg.text?.toString()
            // WhatsApp shows a transient placeholder message while media is
            // still downloading; it gets replaced within a second or two and
            // would otherwise be captured and then immediately look deleted.
            if (text != null && isDownloadPlaceholder(text)) {
                Log.d(TAG, "  skip message: download/upload placeholder (\"$text\")")
                continue
            }
            val sender = msg.person?.name?.toString() ?: (if (isGroup) null else title)
            // sbn.key often embeds a base64 tag (e.g. contains '/'), which would
            // otherwise be read as a path separator when used as a filename.
            val uniqueId = safeFileId("${sbn.key}_${msg.timestamp}")
            var media = extractMessageMedia(msg, uniqueId)
            // The outer notification's big-picture extra only ever reflects the
            // newest message's image, so only try it for the last message here.
            if (media == null && msg === lastMessage) {
                media = extractPictureExtra(extras, uniqueId)
            }
            val result = store.insertMessage(
                chatKey, sbn.key, sender, text, media?.path, media?.type, media?.mime, msg.timestamp
            )
            val op = when {
                result.rowId != -1L -> "INSERT"
                result.mediaBackfilled -> "UPDATE"
                else -> "SKIP (duplicate)"
            }
            Log.d(
                TAG,
                "Message => $op chat=\"$title\" from=$sender text=${text?.take(60)}" +
                    (if (media != null) " media=${media.type}" else "")
            )
            if (result.rowId != -1L) {
                inserted = true
            } else if (result.mediaBackfilled) {
                // Nothing new was inserted, but an existing row just gained
                // media it didn't have before (e.g. a sticker/photo whose data
                // wasn't available on first capture). The chat screen needs to
                // know to reload even though this isn't a "new" message.
                EventBridge.emit(mapOf("type" to "updated", "chatKey" to chatKey, "chatTitle" to title))
            }
        }

        if (inserted) {
            store.touchChatActivity(chatKey, System.currentTimeMillis())
            Log.i(TAG, "chat=\"$title\": new message(s) inserted, emitting \"new\" event")
            EventBridge.emit(mapOf("type" to "new", "chatKey" to chatKey, "chatTitle" to title))
        } else {
            Log.d(TAG, "chat=\"$title\": nothing new inserted from this notification")
        }
    }

    /** Human-readable label for a NotificationListenerService removal reason code, for logs. */
    private fun describeReason(reason: Int): String {
        val name = when (reason) {
            NotificationListenerService.REASON_CLICK -> "CLICK, manual"
            NotificationListenerService.REASON_CANCEL -> "CANCEL, manual swipe"
            NotificationListenerService.REASON_CANCEL_ALL -> "CANCEL_ALL, manual clear-all"
            NotificationListenerService.REASON_APP_CANCEL -> "APP_CANCEL, automatic"
            NotificationListenerService.REASON_APP_CANCEL_ALL -> "APP_CANCEL_ALL, automatic"
            NotificationListenerService.REASON_GROUP_SUMMARY_CANCELED -> "GROUP_SUMMARY_CANCELED, automatic"
            NotificationListenerService.REASON_GROUP_OPTIMIZATION -> "GROUP_OPTIMIZATION, automatic"
            else -> "OTHER"
        }
        return "$reason ($name)"
    }

    private fun safeFileId(raw: String): String = raw.replace(Regex("[^A-Za-z0-9_.-]"), "_")

    private fun isDownloadPlaceholder(text: String): Boolean {
        val t = text.trim()
        return t.startsWith("Downloading") || t.startsWith("Uploading")
    }

    /**
     * WhatsApp attaches whatever it's sending -- photos, videos, voice notes,
     * audio files, stickers, GIFs, PDFs, APKs, any document type -- via the
     * MessagingStyle message's data URI. We copy it locally regardless of
     * mime type and classify it for display.
     */
    private fun extractMessageMedia(
        msg: NotificationCompat.MessagingStyle.Message,
        uniqueId: String
    ): ExtractedMedia? {
        val uri = msg.dataUri ?: return null
        val mime = msg.dataMimeType ?: return null
        val ext = extensionForMime(mime)
        val path = copyUriToInternal(uri, uniqueId, ext) ?: return null
        return ExtractedMedia(path, classifyMediaType(mime), mime)
    }

    private fun classifyMediaType(mime: String): String = when {
        mime == "image/webp" -> "sticker"
        mime == "image/gif" -> "gif"
        mime.startsWith("image/") -> "image"
        mime.startsWith("video/") -> "video"
        mime.startsWith("audio/") -> "audio"
        else -> "document"
    }

    private fun extensionForMime(mime: String): String {
        return MimeTypeMap.getSingleton().getExtensionFromMimeType(mime) ?: "bin"
    }

    private fun copyUriToInternal(uri: Uri, uniqueId: String, ext: String): String? {
        return try {
            val dir = File(applicationContext.filesDir, "recovered_media").apply { mkdirs() }
            val outFile = File(dir, "$uniqueId.$ext")
            val opened = applicationContext.contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(outFile).use { output -> input.copyTo(output) }
                true
            } ?: false
            if (opened) outFile.absolutePath else null
        } catch (e: Exception) {
            Log.w(TAG, "Could not copy media from $uri: ${e.message}")
            null
        }
    }

    @Suppress("DEPRECATION")
    private fun extractPictureExtra(extras: Bundle, uniqueId: String): ExtractedMedia? {
        val bitmap = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                extras.getParcelable(Notification.EXTRA_PICTURE, Bitmap::class.java)
            } else {
                extras.getParcelable<Bitmap>(Notification.EXTRA_PICTURE)
            }
        } catch (_: Exception) {
            null
        } ?: return null

        return try {
            val dir = File(applicationContext.filesDir, "recovered_media").apply { mkdirs() }
            val outFile = File(dir, "$uniqueId.jpg")
            FileOutputStream(outFile).use { out -> bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out) }
            ExtractedMedia(outFile.absolutePath, "image", "image/jpeg")
        } catch (_: Exception) {
            null
        }
    }
}
