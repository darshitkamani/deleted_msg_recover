package com.app.recover_deleted_msgs.wp_deleted_msgs

import android.app.KeyguardManager
import android.app.Notification
import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import android.webkit.MimeTypeMap
import androidx.core.app.NotificationCompat
import com.google.firebase.crashlytics.FirebaseCrashlytics
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ConcurrentHashMap
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
private const val CAPTURE_TTL_MS = 60_000L

/** Logs a caught error locally and reports it to Crashlytics as a non-fatal, so an error
 * that's now being degraded-instead-of-crashing is still visible remotely -- otherwise it
 * would go from "crashes the app" to "invisible", not to "known about". */
private fun reportNonFatal(op: String, t: Throwable) {
    Log.e(TAG, "$op: ${t.message}", t)
    try {
        FirebaseCrashlytics.getInstance().recordException(t)
    } catch (_: Throwable) {
        // Crashlytics reporting itself must never become a new crash source.
    }
}

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
        // activeNotifications is itself a synchronous Binder IPC call. With a
        // backlog of messages -- especially ones carrying embedded images in
        // their extras -- marshaling that payload can take seconds on its
        // own, so even fetching the list must happen off the main thread,
        // not just the per-notification processing.
        Log.i(TAG, "onListenerConnected")
        bgExecutor.execute {
            // Runs at most once per process -- see MessageStore.pruneOldDataOnce. Reconnects
            // happen periodically over a long-lived, unattended install (OS rebinding the
            // service, reboots, etc.), which is exactly the cadence this needs.
            MessageStore.getInstance(applicationContext).pruneOldDataOnce()

            val notifications = try {
                activeNotifications
            } catch (e: Exception) {
                Log.w(TAG, "Could not read activeNotifications backlog: ${e.message}")
                null
            }
            Log.d(TAG, "Backlog on connect: ${notifications?.size ?: 0} active notification(s)")
            notifications?.forEach { sbn -> safeHandlePosted(sbn) }
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
        bgExecutor.execute { safeHandlePosted(sbn) }
    }

    /**
     * Runs [handlePosted] with a top-level Throwable guard. This service shares the app's
     * process (it isn't isolated via android:process), and every call here runs on
     * [bgExecutor] -- a single-thread Executor invoked via execute(), not submit() -- so an
     * uncaught exception or Error (an OutOfMemoryError, say, from decoding a huge embedded
     * notification image) anywhere in this pipeline would otherwise kill the entire app
     * process, not just this one notification. Over days of unattended background use, a
     * single rare edge case (an odd notification shape, a storage hiccup) doing that
     * repeatedly is exactly what produces the "app keeps stopping" dialog days later, with
     * nothing else in the app ever having actually been open to see it happen.
     */
    private fun safeHandlePosted(sbn: StatusBarNotification) {
        try {
            handlePosted(sbn)
        } catch (t: Throwable) {
            reportNonFatal("handlePosted crashed for key=${sbn.key}, recovering", t)
        }
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
        val isAppCancel = reason == NotificationListenerService.REASON_APP_CANCEL
        // Sampled now, not after the grace period below: what matters is whether the user
        // could have been reading it in WhatsApp at the moment it was cancelled.
        val couldBeReadingHere = couldBeReadingOnThisPhone()
        handler.postDelayed({
            bgExecutor.execute {
                try {
                    resolveRemoval(notifKey, removedAt, isAppCancel, couldBeReadingHere)
                } catch (t: Throwable) {
                    reportNonFatal("resolveRemoval crashed for key=$notifKey, recovering", t)
                }
            }
        }, REMOVAL_GRACE_MS)
    }

    /**
     * True when the screen is on and unlocked with this app off screen -- i.e. WhatsApp itself
     * might have been open. Anything we can't determine counts as "could be", so an unknown
     * never turns into a deletion.
     */
    private fun couldBeReadingOnThisPhone(): Boolean {
        val screenOn = (getSystemService(Context.POWER_SERVICE) as? PowerManager)?.isInteractive ?: true
        val locked = (getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager)?.isKeyguardLocked ?: false
        return screenOn && !locked && !AppVisibility.isForeground
    }

    /**
     * When each newly inserted row was first captured, so a removal can tell a message that was
     * in the cancelled notification from one that arrived after it. Kept in memory on purpose --
     * the window that matters is [REMOVAL_GRACE_MS], and a row missing from here (e.g. after a
     * process restart) is treated as having been in the notification, the conservative reading.
     */
    private val recentCaptures = ConcurrentHashMap<Long, Long>()

    private fun noteCapture(rowId: Long) {
        val now = System.currentTimeMillis()
        recentCaptures[rowId] = now
        recentCaptures.values.removeAll { now - it > CAPTURE_TTL_MS }
    }

    /** The WhatsApp notifications currently showing, or null when the system won't say. */
    private fun activeWhatsAppNotifications(): List<StatusBarNotification>? = try {
        (activeNotifications ?: emptyArray()).filter {
            it.packageName == PKG_WHATSAPP || it.packageName == PKG_WHATSAPP_BUSINESS
        }
    } catch (e: Exception) {
        Log.w(TAG, "Could not check active notifications: ${e.message}")
        null
    }

    /**
     * Key of the active notification that still shows this exact message, or null if none does.
     * Non-null means WhatsApp re-issued it -- under the same key or a new one -- rather than
     * removing it. A notification that can't be read counts as showing it, so an unknown is
     * never turned into a deletion.
     */
    private fun keyStillShowing(r: RemovalResult, active: List<StatusBarNotification>): String? =
        active.firstOrNull { sbn ->
            runCatching {
                NotificationCompat.MessagingStyle
                    .extractMessagingStyleFromNotification(sbn.notification)
                    ?.messages.orEmpty()
                    .any { it.timestamp == r.timestamp && it.text?.toString() == r.text }
            }.getOrDefault(true)
        }?.key

    private fun resolveRemoval(
        notifKey: String,
        removedAt: Long,
        isAppCancel: Boolean,
        couldBeReadingHere: Boolean
    ) {
        // Can't see what's on screen, so can't tell a removal from a re-post. Leave the rows
        // alone -- a later cancel of the same key will still find them.
        val active = activeWhatsAppNotifications()
        if (active == null) {
            Log.d(TAG, "resolveRemoval key=$notifKey: active notifications unreadable, skipping")
            return
        }
        val store = MessageStore.getInstance(applicationContext)
        val results = store.markRemoved(notifKey, removedAt)
        Log.d(TAG, "resolveRemoval key=$notifKey -> ${results.size} chat(s) affected")

        // WhatsApp often cancels and immediately re-posts a conversation, frequently under the
        // very same key, so the key alone can't say whether a message went away. Each message
        // is judged by whether it is still on screen (the re-post was already reconciled during
        // REMOVAL_GRACE_MS) and by whether it was even in the cancelled notification.
        val decision = RemovalClassifier.resolve(
            results = results,
            isAppCancel = isAppCancel,
            couldBeReadingOnThisPhone = couldBeReadingHere,
            capturedAfterCancel = { (recentCaptures[it.id] ?: Long.MIN_VALUE) > removedAt }, // a tie counts as "was there"
            shownIn = { keyStillShowing(it, active) }
        )

        // Still on screen: not removed, so undo the mark rather than reporting it.
        for ((r, liveKey) in decision.stillActive) store.markStillActive(r.id, liveKey)

        for (r in decision.gone) {
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

        // A chat's only unread message being deleted never reaches the reconciler: WhatsApp has
        // nothing left to re-post, so it just cancels the notification. See RemovalClassifier.
        val deleted = decision.deletion
        if (deleted != null) {
            applyDeletion(
                store, deleted.chatKey, deleted.chatTitle,
                WindowEntry(deleted.timestamp, deleted.text ?: "", deleted.sender, deleted.id),
                "CANCELLED"
            )
        } else {
            Log.d(
                TAG,
                "resolveRemoval key=$notifKey: not treated as deleted " +
                    "(appCancel=$isAppCancel couldBeReadingHere=$couldBeReadingHere " +
                    "rows=${results.size} stillShown=${decision.stillActive.size})"
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
        val rawTitle = (extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)
            ?: extras.getCharSequence(Notification.EXTRA_TITLE))?.toString()
        if (rawTitle == null) {
            Log.d(TAG, "skip key=${sbn.key}: no conversation/notification title present")
            return
        }
        // A group with an unread backlog gets its conversation title rewritten
        // to e.g. "TechOnTouch x WB (12 messages)" -- the count changes on
        // every notification, so keying (and displaying) on the raw title
        // split what's really one group across a new "chat" row per count.
        // Stripping it back to the plain group name keeps them all mapped to
        // the same chatKey.
        val title = ChatTitleUtils.normalize(rawTitle)
        val chatKey = "$pkg|$title"
        Log.d(TAG, "handling key=${sbn.key} chat=\"$title\" group=$isGroup messages=${style.messages.size}")

        val store = MessageStore.getInstance(applicationContext)
        store.upsertChat(chatKey, pkg, title, isGroup)

        // Placeholders are dropped before reconciliation, not after -- a message that's still
        // "Downloading..." isn't part of the real conversation window WhatsApp will keep
        // presenting, so it must not occupy a matching slot for the real content that replaces it.
        val lastMessage = style.messages.lastOrNull()
        val incoming = style.messages.mapNotNull { msg ->
            val text = msg.text?.toString()
            if (text != null && isDownloadPlaceholder(text)) {
                Log.d(TAG, "  skip message: download/upload placeholder (\"$text\")")
                null
            } else {
                msg to WindowEntry(
                    timestamp = msg.timestamp,
                    text = text ?: "",
                    sender = msg.person?.name?.toString() ?: (if (isGroup) null else title)
                )
            }
        }
        if (incoming.isEmpty()) {
            Log.d(TAG, "chat=\"$title\": nothing left to reconcile after filtering placeholders")
            return
        }

        val stored = store.getWindow(chatKey, MessageReconciler.DEFAULT_WINDOW_CAP)
        val actions = MessageReconciler.reconcile(
            stored = stored,
            incoming = incoming.map { it.second }
        )

        var inserted = false
        var edited = false
        var deleted = false

        // actions[0 until incoming.size] line up 1:1 with `incoming`, in order -- see the
        // contract documented on MessageReconciler.reconcile. Anything past that is a
        // DeletedSilently action for a stored entry with no incoming counterpart at all.
        for (i in incoming.indices) {
            val (msg, entry) = incoming[i]
            when (val action = actions[i]) {
                is ReconcileAction.Insert -> {
                    // sbn.key often embeds a base64 tag (e.g. contains '/'), which would
                    // otherwise be read as a path separator when used as a filename.
                    val uniqueId = safeFileId("${sbn.key}_${msg.timestamp}")
                    var media = extractMessageMedia(msg, uniqueId)
                    if (media == null && msg === lastMessage) {
                        media = extractPictureExtra(extras, uniqueId)
                    }
                    val result = store.insertMessage(
                        chatKey, sbn.key, entry.sender, entry.text, media?.path, media?.type, media?.mime, entry.timestamp
                    )
                    Log.d(
                        TAG,
                        "Message => INSERT chat=\"$title\" from=${entry.sender} text=${entry.text.take(60)}" +
                            (if (media != null) " media=${media.type}" else "")
                    )
                    if (result.rowId != -1L) {
                        inserted = true
                        noteCapture(result.rowId)
                    }
                }

                is ReconcileAction.Edit -> {
                    val rowId = action.previous.id
                    if (rowId == null) {
                        Log.w(TAG, "  edit action with no row id, dropping: ${action.previous}")
                        continue
                    }
                    store.applyEdit(rowId, action.updated.text, System.currentTimeMillis())
                    store.markStillActive(rowId, sbn.key)
                    Log.i(
                        TAG,
                        "Message => EDIT chat=\"$title\" \"${action.previous.text.take(40)}\" -> \"${action.updated.text.take(40)}\""
                    )
                    edited = true
                    EventBridge.emit(
                        mapOf(
                            "type" to "edited",
                            "chatKey" to chatKey,
                            "chatTitle" to title,
                            "previousText" to action.previous.text,
                            "newText" to action.updated.text
                        )
                    )
                }

                is ReconcileAction.DeletedWithPlaceholder -> {
                    applyDeletion(store, chatKey, title, action.previous, "PLACEHOLDER")
                    deleted = true
                }

                is ReconcileAction.Noop -> {
                    // Text is unchanged, but media may not have been available on first capture
                    // (e.g. a sticker mid-download) and could be ready now.
                    val rowId = action.entry.id ?: continue
                    store.markStillActive(rowId, sbn.key)
                    if (store.hasMedia(rowId)) continue
                    val uniqueId = safeFileId("${sbn.key}_${msg.timestamp}")
                    var media = extractMessageMedia(msg, uniqueId)
                    if (media == null && msg === lastMessage) {
                        media = extractPictureExtra(extras, uniqueId)
                    }
                    if (media != null) {
                        store.backfillMedia(rowId, media.path, media.type, media.mime)
                        Log.d(TAG, "Message => UPDATE (media backfill) chat=\"$title\"")
                        EventBridge.emit(mapOf("type" to "updated", "chatKey" to chatKey, "chatTitle" to title))
                    }
                }

                is ReconcileAction.DeletedSilently -> {
                    // Never produced for an incoming entry -- see the loop below.
                }
            }
        }

        for (i in incoming.size until actions.size) {
            val action = actions[i] as? ReconcileAction.DeletedSilently ?: continue
            applyDeletion(store, chatKey, title, action.previous, "SILENT")
            deleted = true
        }

        if (inserted || edited) {
            store.touchChatActivity(chatKey, System.currentTimeMillis())
        }
        if (inserted) {
            Log.i(TAG, "chat=\"$title\": new message(s) inserted, emitting \"new\" event")
            EventBridge.emit(mapOf("type" to "new", "chatKey" to chatKey, "chatTitle" to title))
        }
        if (!inserted && !edited && !deleted) {
            Log.d(TAG, "chat=\"$title\": nothing new inserted from this notification")
        }
    }

    private fun applyDeletion(store: MessageStore, chatKey: String, title: String, previous: WindowEntry, source: String) {
        val rowId = previous.id
        if (rowId == null) {
            Log.w(TAG, "  delete action with no row id, dropping: $previous")
            return
        }
        store.applyDelete(rowId, System.currentTimeMillis())
        Log.i(TAG, "Message => DELETE ($source) chat=\"$title\" text=${previous.text.take(60)}")
        EventBridge.emit(
            mapOf(
                "type" to "deleted",
                "chatKey" to chatKey,
                "chatTitle" to title,
                "recoveredText" to previous.text,
                "sender" to previous.sender
            )
        )
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
        // Catches Throwable, not just Exception, on both steps below: an embedded
        // EXTRA_PICTURE bitmap is uncompressed and can be large enough (a high-res photo from
        // some manufacturers' notification payloads) to throw OutOfMemoryError while decoding
        // or compressing -- an Error, not an Exception, so it needs its own explicit guard
        // here rather than relying on the caller only catching Exception.
        val bitmap = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                extras.getParcelable(Notification.EXTRA_PICTURE, Bitmap::class.java)
            } else {
                extras.getParcelable<Bitmap>(Notification.EXTRA_PICTURE)
            }
        } catch (t: Throwable) {
            reportNonFatal("extractPictureExtra: could not decode EXTRA_PICTURE", t)
            null
        } ?: return null

        return try {
            val dir = File(applicationContext.filesDir, "recovered_media").apply { mkdirs() }
            val outFile = File(dir, "$uniqueId.jpg")
            FileOutputStream(outFile).use { out -> bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out) }
            ExtractedMedia(outFile.absolutePath, "image", "image/jpeg")
        } catch (t: Throwable) {
            reportNonFatal("extractPictureExtra: could not compress/save bitmap", t)
            null
        }
    }
}
