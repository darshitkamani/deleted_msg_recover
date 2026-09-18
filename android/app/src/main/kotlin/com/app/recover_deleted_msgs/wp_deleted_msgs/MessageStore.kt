package com.app.recover_deleted_msgs.wp_deleted_msgs

import android.content.ContentValues
import android.content.Context
import android.database.SQLException
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log
import com.google.firebase.crashlytics.FirebaseCrashlytics
import java.io.File

// Covers SQLiteFullException (disk full), SQLiteDatabaseLockedException, and any other
// SQLException this store's operations can throw -- see the catches below, which log and
// degrade to a safe default instead of letting a storage/DB error propagate out of a store
// method and crash whatever called it (most importantly NotificationListener's background
// executor, where an uncaught exception kills the whole app process, not just that task).
private const val TAG = "MessageStore"

/** Logs a caught error locally and reports it to Crashlytics as a non-fatal, so a DB error
 * that's now being degraded-instead-of-crashing is still visible remotely -- otherwise it
 * would go from "crashes the app" to "invisible", not to "known about". */
private fun reportNonFatal(op: String, e: Throwable) {
    Log.e(TAG, "$op failed: ${e.message}", e)
    try {
        FirebaseCrashlytics.getInstance().recordException(e)
    } catch (_: Throwable) {
        // Crashlytics reporting itself must never become a new crash source.
    }
}

data class RemovalResult(
    val chatKey: String,
    val chatTitle: String,
    val text: String?,
    val sender: String?
)

/** [mediaBackfilled] is true when media was added to an already-stored row
 * (e.g. it wasn't available on first capture but showed up on a later
 * reprocess) -- the caller needs this to know a UI refresh is owed even
 * though nothing new was actually inserted. */
data class InsertResult(val rowId: Long, val mediaBackfilled: Boolean = false)

/** Returned after applying a [ReconcileAction.Edit] or a delete action, so the caller has
 * what it needs to emit an event without a second query. */
data class ChangeResult(
    val chatKey: String,
    val chatTitle: String,
    val previousText: String?,
    val sender: String?
)

/**
 * Single local datastore for captured WhatsApp/WhatsApp Business notifications.
 * This is the only source of truth for message data; Flutter never touches
 * the database directly, it only calls through the MethodChannel.
 */
class MessageStore private constructor(context: Context) :
    SQLiteOpenHelper(context.applicationContext, DB_NAME, null, DB_VERSION) {

    companion object {
        private const val DB_NAME = "recover.db"
        private const val DB_VERSION = 6

        const val STATUS_ACTIVE = "active"
        const val STATUS_DELETED = "deleted"

        // Messages (and their recovered media) older than this are pruned once per process --
        // neither the messages table nor recovered_media/ had any retention at all before, so
        // both grew forever across a long-lived install, and that unbounded growth is what
        // eventually turns a rare DB/storage hiccup into a crash days into an idle run -- see
        // pruneOldDataOnce. Six months is long enough that it shouldn't touch any realistic
        // "let me check what got deleted" usage, while still keeping storage bounded.
        private const val DEFAULT_RETENTION_DAYS = 180

        @Volatile
        private var instance: MessageStore? = null

        fun getInstance(context: Context): MessageStore =
            instance ?: synchronized(this) {
                instance ?: MessageStore(context).also { instance = it }
            }
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE chats (
                chat_key TEXT PRIMARY KEY,
                package TEXT NOT NULL,
                title TEXT NOT NULL,
                is_group INTEGER NOT NULL DEFAULT 0,
                last_opened_at INTEGER,
                last_activity_at INTEGER
            )
            """.trimIndent()
        )
        db.execSQL(
            """
            CREATE TABLE messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                chat_key TEXT NOT NULL,
                notif_key TEXT NOT NULL,
                sender TEXT,
                text TEXT,
                media_path TEXT,
                media_type TEXT,
                media_mime TEXT,
                timestamp INTEGER NOT NULL,
                removed_at INTEGER,
                status TEXT NOT NULL DEFAULT 'active',
                edited_at INTEGER,
                deleted_at INTEGER
            )
            """.trimIndent()
        )
        // Deliberately (chat_key, timestamp, text) rather than (chat_key, timestamp) alone --
        // two distinct messages can legitimately share a timestamp (a fast burst), and only
        // collapsing on identical text too keeps both of those rows instead of losing one.
        db.execSQL("CREATE UNIQUE INDEX idx_messages_dedup ON messages(chat_key, timestamp, text)")
        db.execSQL("CREATE INDEX idx_messages_chat ON messages(chat_key)")
        db.execSQL("CREATE INDEX idx_messages_notif_key ON messages(notif_key)")
        db.execSQL(
            """
            CREATE TABLE message_edits (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                message_id INTEGER NOT NULL,
                old_text TEXT,
                changed_at INTEGER NOT NULL
            )
            """.trimIndent()
        )
        db.execSQL("CREATE INDEX idx_message_edits_message ON message_edits(message_id)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        db.execSQL("DROP TABLE IF EXISTS message_edits")
        db.execSQL("DROP TABLE IF EXISTS messages")
        db.execSQL("DROP TABLE IF EXISTS chats")
        onCreate(db)
    }

    fun upsertChat(chatKey: String, packageName: String, title: String, isGroup: Boolean) {
        try {
            val db = writableDatabase
            val values = ContentValues().apply {
                put("chat_key", chatKey)
                put("package", packageName)
                put("title", title)
                put("is_group", if (isGroup) 1 else 0)
            }
            db.insertWithOnConflict("chats", null, values, SQLiteDatabase.CONFLICT_IGNORE)
            db.execSQL(
                "UPDATE chats SET title = ?, package = ?, is_group = ? WHERE chat_key = ?",
                arrayOf(title, packageName, if (isGroup) 1 else 0, chatKey)
            )
        } catch (e: SQLException) {
            reportNonFatal("upsertChat", e)
        }
    }

    fun insertMessage(
        chatKey: String,
        notifKey: String,
        sender: String?,
        text: String?,
        mediaPath: String?,
        mediaType: String?,
        mediaMime: String?,
        timestamp: Long
    ): InsertResult {
        try {
            val db = writableDatabase
            val values = ContentValues().apply {
                put("chat_key", chatKey)
                put("notif_key", notifKey)
                put("sender", sender)
                put("text", text)
                put("media_path", mediaPath)
                put("media_type", mediaType)
                put("media_mime", mediaMime)
                put("timestamp", timestamp)
            }
            val rowId = db.insertWithOnConflict("messages", null, values, SQLiteDatabase.CONFLICT_IGNORE)
            if (rowId != -1L) return InsertResult(rowId, mediaBackfilled = false)

            // A row for this (chat_key, timestamp, text) already exists -- this happens
            // when the same notification gets reprocessed (e.g. app restart, or
            // WhatsApp updating it in place). Media that failed to save before
            // might now succeed -- backfill it.
            var mediaBackfilled = false
            db.rawQuery(
                "SELECT id, media_path FROM messages WHERE chat_key = ? AND timestamp = ? AND text IS ?",
                arrayOf(chatKey, timestamp.toString(), text)
            ).use { cursor ->
                if (cursor.moveToFirst()) {
                    val existingId = cursor.getLong(0)
                    val existingMediaPath = cursor.getString(1)
                    if (mediaPath != null && existingMediaPath == null) {
                        val updateValues = ContentValues().apply {
                            put("media_path", mediaPath)
                            put("media_type", mediaType)
                            put("media_mime", mediaMime)
                        }
                        db.update("messages", updateValues, "id = ?", arrayOf(existingId.toString()))
                        mediaBackfilled = true
                    }
                }
            }
            return InsertResult(rowId, mediaBackfilled)
        } catch (e: SQLException) {
            reportNonFatal("insertMessage", e)
            return InsertResult(-1L, mediaBackfilled = false)
        }
    }

    /** Marks every not-yet-removed message belonging to [notifKey] as removed. */
    fun markRemoved(notifKey: String, removedAt: Long): List<RemovalResult> {
        try {
            val db = writableDatabase
            data class Row(
                val id: Long,
                val chatKey: String,
                val ts: Long,
                val text: String?,
                val sender: String?,
                val title: String
            )

            val rows = mutableListOf<Row>()
            db.rawQuery(
                """
                SELECT m.id, m.chat_key, m.timestamp, m.text, m.sender, c.title
                FROM messages m JOIN chats c ON c.chat_key = m.chat_key
                WHERE m.notif_key = ? AND m.removed_at IS NULL
                """.trimIndent(),
                arrayOf(notifKey)
            ).use { cursor ->
                while (cursor.moveToNext()) {
                    rows.add(
                        Row(
                            cursor.getLong(0),
                            cursor.getString(1),
                            cursor.getLong(2),
                            cursor.getString(3),
                            cursor.getString(4),
                            cursor.getString(5)
                        )
                    )
                }
            }

            val results = mutableListOf<RemovalResult>()
            for (row in rows) {
                val values = ContentValues().apply {
                    put("removed_at", removedAt)
                }
                db.update("messages", values, "id = ?", arrayOf(row.id.toString()))
                results.add(RemovalResult(row.chatKey, row.title, row.text, row.sender))
            }
            return results
        } catch (e: SQLException) {
            reportNonFatal("markRemoved", e)
            return emptyList()
        }
    }

    fun touchChatActivity(chatKey: String, atMillis: Long) {
        try {
            writableDatabase.execSQL(
                "UPDATE chats SET last_activity_at = ? WHERE chat_key = ?",
                arrayOf(atMillis, chatKey)
            )
        } catch (e: SQLException) {
            reportNonFatal("touchChatActivity", e)
        }
    }

    fun markChatOpened(chatKey: String) {
        try {
            writableDatabase.execSQL(
                "UPDATE chats SET last_opened_at = ? WHERE chat_key = ?",
                arrayOf(System.currentTimeMillis(), chatKey)
            )
        } catch (e: SQLException) {
            reportNonFatal("markChatOpened", e)
        }
    }

    /** Guards [mergeDuplicateGroupChats] so it only ever scans once per process,
     * not on every [getChats] call. */
    @Volatile
    private var duplicateChatsMerged = false

    fun getChats(): List<Map<String, Any?>> {
        mergeDuplicateGroupChatsOnce()
        val result = mutableListOf<Map<String, Any?>>()
        readableDatabase.rawQuery(
            """
            SELECT c.chat_key, c.package, c.title, c.is_group,
                   (SELECT text FROM messages m WHERE m.chat_key = c.chat_key ORDER BY timestamp DESC LIMIT 1) AS last_text,
                   (SELECT timestamp FROM messages m WHERE m.chat_key = c.chat_key ORDER BY timestamp DESC LIMIT 1) AS last_ts,
                   (SELECT COUNT(*) FROM messages m WHERE m.chat_key = c.chat_key) AS total_count,
                   (SELECT status FROM messages m WHERE m.chat_key = c.chat_key ORDER BY timestamp DESC LIMIT 1) AS last_status,
                   (SELECT edited_at FROM messages m WHERE m.chat_key = c.chat_key ORDER BY timestamp DESC LIMIT 1) AS last_edited_at
            FROM chats c
            ORDER BY last_ts DESC
            """.trimIndent(),
            null
        ).use { cursor ->
            while (cursor.moveToNext()) {
                result.add(
                    mapOf(
                        "chatKey" to cursor.getString(0),
                        "package" to cursor.getString(1),
                        "title" to cursor.getString(2),
                        "isGroup" to (cursor.getInt(3) == 1),
                        "lastText" to cursor.getString(4),
                        "lastTimestamp" to (if (cursor.isNull(5)) 0L else cursor.getLong(5)),
                        "totalCount" to cursor.getInt(6),
                        "lastStatus" to cursor.getString(7),
                        "lastIsEdited" to !cursor.isNull(8)
                    )
                )
            }
        }
        return result
    }

    fun getMessages(chatKey: String): List<Map<String, Any?>> {
        val result = mutableListOf<Map<String, Any?>>()
        readableDatabase.rawQuery(
            """
            SELECT id, sender, text, media_path, media_type, media_mime, timestamp, removed_at,
                   status, edited_at, deleted_at
            FROM messages WHERE chat_key = ? ORDER BY timestamp ASC
            """.trimIndent(),
            arrayOf(chatKey)
        ).use { cursor ->
            while (cursor.moveToNext()) {
                result.add(
                    mapOf(
                        "id" to cursor.getLong(0),
                        "sender" to cursor.getString(1),
                        "text" to cursor.getString(2),
                        "mediaPath" to cursor.getString(3),
                        "mediaType" to cursor.getString(4),
                        "mediaMime" to cursor.getString(5),
                        "timestamp" to cursor.getLong(6),
                        "removedAt" to (if (cursor.isNull(7)) null else cursor.getLong(7)),
                        "status" to cursor.getString(8),
                        "editedAt" to (if (cursor.isNull(9)) null else cursor.getLong(9)),
                        "deletedAt" to (if (cursor.isNull(10)) null else cursor.getLong(10)),
                        "editHistory" to getEditHistory(cursor.getLong(0))
                    )
                )
            }
        }
        return result
    }

    /**
     * Every recovered message that has attached media of one of [mediaTypes], across all
     * chats (optionally narrowed to a single [packageName]) -- backs the Recover grid's
     * per-media-type screens (Photo, Video, Voice Message, Files, Stickers & GIFs), which show
     * matches from every conversation at once rather than one chat at a time.
     */
    fun getMediaMessages(mediaTypes: List<String>, packageName: String?): List<Map<String, Any?>> {
        if (mediaTypes.isEmpty()) return emptyList()
        val result = mutableListOf<Map<String, Any?>>()
        val typePlaceholders = mediaTypes.joinToString(",") { "?" }
        val args = mutableListOf<String>()
        args.addAll(mediaTypes)
        val packageClause = if (packageName != null) "AND c.package = ?" else ""
        if (packageName != null) args.add(packageName)

        readableDatabase.rawQuery(
            """
            SELECT m.chat_key, c.title, c.package, m.sender, m.text, m.media_path, m.media_type,
                   m.media_mime, m.timestamp, m.status
            FROM messages m JOIN chats c ON c.chat_key = m.chat_key
            WHERE m.media_path IS NOT NULL AND m.media_type IN ($typePlaceholders) $packageClause
            ORDER BY m.timestamp DESC
            """.trimIndent(),
            args.toTypedArray()
        ).use { cursor ->
            while (cursor.moveToNext()) {
                result.add(
                    mapOf(
                        "chatKey" to cursor.getString(0),
                        "chatTitle" to cursor.getString(1),
                        "package" to cursor.getString(2),
                        "sender" to cursor.getString(3),
                        "text" to cursor.getString(4),
                        "mediaPath" to cursor.getString(5),
                        "mediaType" to cursor.getString(6),
                        "mediaMime" to cursor.getString(7),
                        "timestamp" to cursor.getLong(8),
                        "status" to cursor.getString(9)
                    )
                )
            }
        }
        return result
    }

    private fun getEditHistory(messageId: Long): List<Map<String, Any?>> {
        val result = mutableListOf<Map<String, Any?>>()
        readableDatabase.rawQuery(
            "SELECT old_text, changed_at FROM message_edits WHERE message_id = ? ORDER BY changed_at ASC",
            arrayOf(messageId.toString())
        ).use { cursor ->
            while (cursor.moveToNext()) {
                result.add(mapOf("text" to cursor.getString(0), "changedAt" to cursor.getLong(1)))
            }
        }
        return result
    }

    /**
     * The last [cap] not-yet-deleted messages for [chatKey], oldest first -- the same shape
     * WhatsApp's own notification window has, for [MessageReconciler] to diff against. Deleted
     * messages are excluded: once gone, WhatsApp will never show them in a window again, so
     * they must not be compared against either.
     */
    fun getWindow(chatKey: String, cap: Int): List<WindowEntry> {
        try {
            val entries = mutableListOf<WindowEntry>()
            readableDatabase.rawQuery(
                """
                SELECT id, timestamp, text, sender FROM messages
                WHERE chat_key = ? AND status != ?
                ORDER BY timestamp DESC, id DESC LIMIT ?
                """.trimIndent(),
                arrayOf(chatKey, STATUS_DELETED, cap.toString())
            ).use { cursor ->
                while (cursor.moveToNext()) {
                    entries.add(
                        WindowEntry(
                            timestamp = cursor.getLong(1),
                            text = cursor.getString(2) ?: "",
                            sender = cursor.getString(3),
                            id = cursor.getLong(0)
                        )
                    )
                }
            }
            return entries.asReversed()
        } catch (e: SQLException) {
            reportNonFatal("getWindow", e)
            return emptyList()
        }
    }

    fun getActiveMessageCount(chatKey: String): Int {
        try {
            readableDatabase.rawQuery(
                "SELECT COUNT(*) FROM messages WHERE chat_key = ? AND status != ?",
                arrayOf(chatKey, STATUS_DELETED)
            ).use { cursor ->
                return if (cursor.moveToFirst()) cursor.getInt(0) else 0
            }
        } catch (e: SQLException) {
            reportNonFatal("getActiveMessageCount", e)
            return 0
        }
    }

    /** Applies a [ReconcileAction.Edit]: archives the old text and updates the row in place. */
    fun applyEdit(rowId: Long, newText: String, editedAt: Long): ChangeResult? {
        try {
            val db = writableDatabase
            val row = findRowForChange(db, rowId) ?: return null

            db.insertWithOnConflict(
                "message_edits",
                null,
                ContentValues().apply {
                    put("message_id", rowId)
                    put("old_text", row.text)
                    put("changed_at", editedAt)
                },
                SQLiteDatabase.CONFLICT_IGNORE
            )
            db.update(
                "messages",
                ContentValues().apply {
                    put("text", newText)
                    put("edited_at", editedAt)
                },
                "id = ?",
                arrayOf(rowId.toString())
            )
            return ChangeResult(row.chatKey, row.chatTitle, row.text, row.sender)
        } catch (e: SQLException) {
            reportNonFatal("applyEdit", e)
            return null
        }
    }

    /**
     * Applies a delete action (placeholder or silent): marks the row deleted without touching
     * [text] -- the last known real text is exactly what this app exists to preserve, so it's
     * left in place rather than overwritten with a placeholder or cleared.
     */
    fun applyDelete(rowId: Long, deletedAt: Long): ChangeResult? {
        try {
            val db = writableDatabase
            val row = findRowForChange(db, rowId) ?: return null

            db.update(
                "messages",
                ContentValues().apply {
                    put("status", STATUS_DELETED)
                    put("deleted_at", deletedAt)
                },
                "id = ?",
                arrayOf(rowId.toString())
            )
            return ChangeResult(row.chatKey, row.chatTitle, row.text, row.sender)
        } catch (e: SQLException) {
            reportNonFatal("applyDelete", e)
            return null
        }
    }

    /** Fills in media for a row that matched as unchanged (Noop) but didn't have it yet --
     * mirrors the old insert-time backfill, just keyed by row id instead of a conflict. */
    fun backfillMedia(rowId: Long, mediaPath: String, mediaType: String, mediaMime: String) {
        try {
            writableDatabase.update(
                "messages",
                ContentValues().apply {
                    put("media_path", mediaPath)
                    put("media_type", mediaType)
                    put("media_mime", mediaMime)
                },
                "id = ? AND media_path IS NULL",
                arrayOf(rowId.toString())
            )
        } catch (e: SQLException) {
            reportNonFatal("backfillMedia", e)
        }
    }

    fun hasMedia(rowId: Long): Boolean {
        try {
            readableDatabase.rawQuery(
                "SELECT media_path FROM messages WHERE id = ?",
                arrayOf(rowId.toString())
            ).use { cursor ->
                return cursor.moveToFirst() && cursor.getString(0) != null
            }
        } catch (e: SQLException) {
            reportNonFatal("hasMedia", e)
            return false
        }
    }

    private data class RowForChange(
        val chatKey: String,
        val chatTitle: String,
        val text: String?,
        val sender: String?
    )

    private fun findRowForChange(db: SQLiteDatabase, rowId: Long): RowForChange? {
        db.rawQuery(
            """
            SELECT m.chat_key, c.title, m.text, m.sender
            FROM messages m JOIN chats c ON c.chat_key = m.chat_key
            WHERE m.id = ?
            """.trimIndent(),
            arrayOf(rowId.toString())
        ).use { cursor ->
            if (!cursor.moveToFirst()) return null
            return RowForChange(cursor.getString(0), cursor.getString(1), cursor.getString(2), cursor.getString(3))
        }
    }

    /** Guards [pruneOldData] so it only ever runs once per process, same pattern as
     * [duplicateChatsMerged]. */
    @Volatile
    private var oldDataPruned = false

    /**
     * Deletes messages (and their edit history, and any recovered media file they reference)
     * older than [retentionDays], so both this DB and internal storage stay bounded over a
     * long-lived install instead of growing forever. Call opportunistically -- it's cheap to
     * call and a no-op after the first successful call in a process.
     */
    fun pruneOldDataOnce(retentionDays: Int = DEFAULT_RETENTION_DAYS) {
        if (oldDataPruned) return
        synchronized(this) {
            if (oldDataPruned) return
            try {
                pruneOldData(retentionDays)
            } catch (e: SQLException) {
                reportNonFatal("pruneOldData", e)
            }
            // Marked done even on failure -- runs at most once per process either way, so a
            // DB error here shouldn't turn into a retry storm on every call site.
            oldDataPruned = true
        }
    }

    private fun pruneOldData(retentionDays: Int) {
        val cutoff = System.currentTimeMillis() - retentionDays * 24L * 60 * 60 * 1000
        val db = writableDatabase

        val mediaPaths = mutableListOf<String>()
        db.rawQuery(
            "SELECT media_path FROM messages WHERE timestamp < ? AND media_path IS NOT NULL",
            arrayOf(cutoff.toString())
        ).use { cursor ->
            while (cursor.moveToNext()) {
                cursor.getString(0)?.let { mediaPaths.add(it) }
            }
        }
        if (mediaPaths.isEmpty()) {
            db.rawQuery("SELECT COUNT(*) FROM messages WHERE timestamp < ?", arrayOf(cutoff.toString()))
                .use { cursor -> if (!(cursor.moveToFirst() && cursor.getInt(0) > 0)) return }
        }

        db.beginTransaction()
        try {
            db.execSQL(
                "DELETE FROM message_edits WHERE message_id IN (SELECT id FROM messages WHERE timestamp < ?)",
                arrayOf(cutoff.toString())
            )
            db.execSQL("DELETE FROM messages WHERE timestamp < ?", arrayOf(cutoff.toString()))
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }

        for (path in mediaPaths) {
            try {
                File(path).delete()
            } catch (e: Exception) {
                // Best-effort -- a stray file left behind isn't worth failing the prune over.
                Log.w(TAG, "pruneOldData: could not delete media file $path: ${e.message}")
            }
        }
        Log.i(
            TAG,
            "pruneOldData: removed messages older than $retentionDays day(s), " +
                "${mediaPaths.size} media file(s) deleted"
        )
    }

    private fun mergeDuplicateGroupChatsOnce() {
        if (duplicateChatsMerged) return
        synchronized(this) {
            if (duplicateChatsMerged) return
            try {
                mergeDuplicateGroupChats()
            } catch (e: SQLException) {
                reportNonFatal("mergeDuplicateGroupChats", e)
            }
            // Marked done even on failure -- this only ever runs once per process either
            // way, so a DB error here shouldn't turn into a retry storm on every getChats().
            duplicateChatsMerged = true
        }
    }

    /**
     * One-time (per process) cleanup for chat rows created before conversation
     * titles were normalized (see [NotificationListener]/[ChatTitleUtils]): a
     * group with an unread backlog used to get a brand new "chats" row per
     * distinct "(N messages)" suffix instead of updating the one real group,
     * each carrying its own overlapping slice of that group's messages. This
     * folds every such duplicate back into a single canonical row keyed on
     * the normalized title -- messages that are byte-identical across
     * duplicates (same timestamp + text, captured from overlapping
     * notification windows) collapse to one copy; anything genuinely
     * distinct is kept and merged into the same thread.
     */
    private fun mergeDuplicateGroupChats() {
        val db = writableDatabase
        data class Row(
            val chatKey: String,
            val pkg: String,
            val title: String,
            val isGroup: Boolean,
            val lastActivity: Long?,
            val lastOpened: Long?
        )

        val rows = mutableListOf<Row>()
        db.rawQuery(
            "SELECT chat_key, package, title, is_group, last_activity_at, last_opened_at FROM chats",
            null
        ).use { cursor ->
            while (cursor.moveToNext()) {
                rows.add(
                    Row(
                        cursor.getString(0),
                        cursor.getString(1),
                        cursor.getString(2),
                        cursor.getInt(3) == 1,
                        if (cursor.isNull(4)) null else cursor.getLong(4),
                        if (cursor.isNull(5)) null else cursor.getLong(5)
                    )
                )
            }
        }

        val groups = rows.groupBy { it.pkg to ChatTitleUtils.normalize(it.title) }

        db.beginTransaction()
        try {
            for ((key, group) in groups) {
                if (group.size < 2) continue
                val (pkg, normalizedTitle) = key
                val canonicalKey = "$pkg|$normalizedTitle"
                val isGroup = group.any { it.isGroup }
                val maxActivity = group.mapNotNull { it.lastActivity }.maxOrNull()
                val maxOpened = group.mapNotNull { it.lastOpened }.maxOrNull()

                if (group.none { it.chatKey == canonicalKey }) {
                    db.insertWithOnConflict(
                        "chats",
                        null,
                        ContentValues().apply {
                            put("chat_key", canonicalKey)
                            put("package", pkg)
                            put("title", normalizedTitle)
                            put("is_group", if (isGroup) 1 else 0)
                        },
                        SQLiteDatabase.CONFLICT_IGNORE
                    )
                }
                db.execSQL(
                    """
                    UPDATE chats SET title = ?, is_group = ?,
                        last_activity_at = COALESCE(?, last_activity_at),
                        last_opened_at = COALESCE(?, last_opened_at)
                    WHERE chat_key = ?
                    """.trimIndent(),
                    arrayOf<Any?>(normalizedTitle, if (isGroup) 1 else 0, maxActivity, maxOpened, canonicalKey)
                )

                for (dup in group) {
                    if (dup.chatKey == canonicalKey) continue
                    // Rows that lose the unique-index race here (chat_key,
                    // timestamp, text) already have an identical copy moved
                    // into canonicalKey -- genuine duplicates, dropped below.
                    db.execSQL(
                        "UPDATE OR IGNORE messages SET chat_key = ? WHERE chat_key = ?",
                        arrayOf(canonicalKey, dup.chatKey)
                    )
                    db.execSQL("DELETE FROM messages WHERE chat_key = ?", arrayOf(dup.chatKey))
                    db.execSQL("DELETE FROM chats WHERE chat_key = ?", arrayOf(dup.chatKey))
                }
            }
            // Edits whose message got dropped as a duplicate above are now orphaned.
            db.execSQL("DELETE FROM message_edits WHERE message_id NOT IN (SELECT id FROM messages)")
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun clearAll() {
        try {
            val db = writableDatabase
            db.execSQL("DELETE FROM message_edits")
            db.execSQL("DELETE FROM messages")
            db.execSQL("DELETE FROM chats")
        } catch (e: SQLException) {
            reportNonFatal("clearAll", e)
        }
    }
}
