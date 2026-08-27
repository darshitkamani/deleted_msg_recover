package com.recoverdeletedmessages.app

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

data class RemovalResult(
    val chatKey: String,
    val chatTitle: String,
    val text: String?,
    val sender: String?,
    val isDeleted: Boolean
)

/** [editedFromText] is non-null only when this call just detected that an
 * already-stored message's text changed -- i.e. the sender edited it.
 * [mediaBackfilled] is true when media was added to an already-stored row
 * (e.g. it wasn't available on first capture but showed up on a later
 * reprocess) -- the caller needs this to know a UI refresh is owed even
 * though nothing new was actually inserted. */
data class InsertResult(val rowId: Long, val editedFromText: String?, val mediaBackfilled: Boolean = false)

/** 1.0 for identical strings, 0.0 for completely unrelated ones. */
private fun textSimilarity(a: String, b: String): Double {
    if (a == b) return 1.0
    val maxLen = maxOf(a.length, b.length)
    if (maxLen == 0) return 1.0
    return 1.0 - (levenshteinDistance(a, b).toDouble() / maxLen)
}

private fun levenshteinDistance(a: String, b: String): Int {
    val dp = Array(a.length + 1) { IntArray(b.length + 1) }
    for (i in 0..a.length) dp[i][0] = i
    for (j in 0..b.length) dp[0][j] = j
    for (i in 1..a.length) {
        for (j in 1..b.length) {
            dp[i][j] = if (a[i - 1] == b[j - 1]) {
                dp[i - 1][j - 1]
            } else {
                1 + minOf(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1])
            }
        }
    }
    return dp[a.length][b.length]
}

/**
 * Single local datastore for captured WhatsApp/WhatsApp Business notifications.
 * This is the only source of truth for message data; Flutter never touches
 * the database directly, it only calls through the MethodChannel.
 */
class MessageStore private constructor(context: Context) :
    SQLiteOpenHelper(context.applicationContext, DB_NAME, null, DB_VERSION) {

    companion object {
        private const val DB_NAME = "recover.db"
        private const val DB_VERSION = 4

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
                is_deleted INTEGER NOT NULL DEFAULT 0,
                is_edited INTEGER NOT NULL DEFAULT 0,
                edited_text TEXT
            )
            """.trimIndent()
        )
        db.execSQL("CREATE UNIQUE INDEX idx_messages_dedup ON messages(notif_key, timestamp)")
        db.execSQL("CREATE INDEX idx_messages_chat ON messages(chat_key)")
        db.execSQL("CREATE INDEX idx_messages_notif_key ON messages(notif_key)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        db.execSQL("DROP TABLE IF EXISTS messages")
        db.execSQL("DROP TABLE IF EXISTS chats")
        onCreate(db)
    }

    fun upsertChat(chatKey: String, packageName: String, title: String, isGroup: Boolean) {
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
        if (rowId != -1L) return InsertResult(rowId, null, mediaBackfilled = false)

        // A row for this (notif_key, timestamp) already exists -- this happens
        // when the same notification gets reprocessed (e.g. app restart, or
        // WhatsApp updating it in place). Two things can have changed since we
        // first saw it:
        //  - media that failed to save before now succeeds -- backfill it.
        //  - the text itself differs -- the sender edited the message. We keep
        //    the ORIGINAL text as the message's text (that's the whole point:
        //    show what it said before the change) and record the new text
        //    separately, rather than silently overwriting the evidence.
        var editedFromText: String? = null
        var mediaBackfilled = false
        db.rawQuery(
            "SELECT id, text, edited_text, media_path FROM messages WHERE chat_key = ? AND notif_key = ? AND timestamp = ?",
            arrayOf(chatKey, notifKey, timestamp.toString())
        ).use { cursor ->
            if (cursor.moveToFirst()) {
                val existingId = cursor.getLong(0)
                val existingText = cursor.getString(1)
                val existingEditedText = cursor.getString(2)
                val existingMediaPath = cursor.getString(3)
                val updateValues = ContentValues()
                var needsUpdate = false

                if (mediaPath != null && existingMediaPath == null) {
                    updateValues.put("media_path", mediaPath)
                    updateValues.put("media_type", mediaType)
                    updateValues.put("media_mime", mediaMime)
                    needsUpdate = true
                    mediaBackfilled = true
                }
                // WhatsApp keeps re-including this same historical message in
                // every subsequent notification update, still showing whatever
                // it was last edited to -- so a plain "differs from the frozen
                // original" check would re-fire on every unrelated new message
                // forever. Only a text that's neither the original NOR the
                // last edit we already recorded is an actually new edit.
                val alreadyKnown = text == existingText || (text != null && text == existingEditedText)
                // WhatsApp only reports message timestamps rounded to the
                // nearest second, not the millisecond -- two genuinely
                // different messages sent within the same second collide on
                // (notif_key, timestamp) here and would otherwise look
                // identical to a real edit. Require the texts to be
                // plausibly related (a typo fix, an added word, etc.) rather
                // than trusting every collision blindly.
                val plausibleEdit = !text.isNullOrEmpty() && !existingText.isNullOrEmpty() &&
                    textSimilarity(existingText, text) >= 0.35
                if (!alreadyKnown && plausibleEdit) {
                    updateValues.put("is_edited", 1)
                    updateValues.put("edited_text", text)
                    needsUpdate = true
                    editedFromText = existingText
                }
                if (needsUpdate) {
                    db.update("messages", updateValues, "id = ?", arrayOf(existingId.toString()))
                }
            }
        }
        return InsertResult(rowId, editedFromText, mediaBackfilled)
    }

    /**
     * Marks every not-yet-removed message belonging to [notifKey] as removed.
     * A message is flagged "deleted" (vs. just "read normally") when the chat
     * was not opened inside this app after that message arrived -- our proxy
     * for "the user never got to see it before it vanished".
     */
    fun markRemoved(notifKey: String, removedAt: Long, forceNotDeleted: Boolean = false): List<RemovalResult> {
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
            val lastOpenedAt = getLastOpenedAt(row.chatKey)
            val lastActivityAt = getLastActivityAt(row.chatKey)
            // If this chat received a fresh notification after the removal
            // event fired (during the grace-period wait), the "removal" was
            // just WhatsApp reissuing the notification under a new key, not
            // a real deletion.
            val refreshedAfterRemoval = lastActivityAt != null && lastActivityAt > removedAt
            val deleted = !forceNotDeleted && !refreshedAfterRemoval &&
                (lastOpenedAt == null || lastOpenedAt < row.ts)
            val values = ContentValues().apply {
                put("removed_at", removedAt)
                put("is_deleted", if (deleted) 1 else 0)
            }
            db.update("messages", values, "id = ?", arrayOf(row.id.toString()))
            results.add(RemovalResult(row.chatKey, row.title, row.text, row.sender, deleted))
        }
        return results
    }

    /**
     * Directly marks the message at [chatKey]/[timestamp] as edited to
     * [newText], bypassing the (notif_key, timestamp) collision path in
     * [insertMessage] -- this is for edits [WindowDiff] catches by comparing
     * the notification's message list position-by-position, which is the
     * only way to notice an edit where WhatsApp assigned the edited message
     * a brand new timestamp (so it never collides with the original row).
     * Returns the message's original text, or null if no matching row was
     * found, or the edit was already recorded (so the caller doesn't
     * re-emit the same "edited" event on every repost).
     */
    fun markEditedAt(chatKey: String, timestamp: Long, newText: String?): String? {
        val db = writableDatabase
        var originalText: String? = null
        // Deliberately not filtering on removed_at: this message can easily
        // have been soft-marked "removed" earlier by the grace-period
        // heuristic in markRemoved (WhatsApp cancels/reposts a chat's
        // notification constantly as ordinary churn) even though it's very
        // much still alive -- WindowDiff seeing it reappear with different
        // text is stronger, more recent evidence than that earlier guess.
        db.rawQuery(
            "SELECT id, text, edited_text FROM messages WHERE chat_key = ? AND timestamp = ? LIMIT 1",
            arrayOf(chatKey, timestamp.toString())
        ).use { cursor ->
            if (cursor.moveToFirst()) {
                val existingEditedText = cursor.getString(2)
                if (existingEditedText == newText) return@use
                val id = cursor.getLong(0)
                originalText = cursor.getString(1)
                val values = ContentValues().apply {
                    put("is_edited", 1)
                    put("edited_text", newText)
                    // Reverse any earlier soft-removal now that we have
                    // direct proof the message is still present.
                    putNull("removed_at")
                    put("is_deleted", 0)
                }
                db.update("messages", values, "id = ?", arrayOf(id.toString()))
            }
        }
        return originalText
    }

    /**
     * Directly marks the message at [chatKey]/[timestamp] as deleted right
     * now, bypassing the grace-period heuristic in [markRemoved]. This is
     * for deletions [WindowDiff] catches by seeing a message's slot vanish
     * from the notification's list while its neighbors on both sides stay
     * put -- an unambiguous signal on its own, unlike the whole notification
     * disappearing (which [markRemoved] still has to guess about).
     */
    fun markDeletedDirect(chatKey: String, timestamp: Long): RemovalResult? {
        val db = writableDatabase
        var result: RemovalResult? = null
        // Same reasoning as markEditedAt: not filtering on removed_at, since
        // this row may have already been soft-marked "removed" (not
        // "deleted") by ordinary notification churn -- WindowDiff seeing the
        // message's slot vanish with unchanged neighbors on both sides is a
        // stronger, more direct signal than that earlier guess, and should
        // win over it.
        db.rawQuery(
            """
            SELECT m.id, m.text, m.sender, c.title FROM messages m
            JOIN chats c ON c.chat_key = m.chat_key
            WHERE m.chat_key = ? AND m.timestamp = ? LIMIT 1
            """.trimIndent(),
            arrayOf(chatKey, timestamp.toString())
        ).use { cursor ->
            if (cursor.moveToFirst()) {
                val id = cursor.getLong(0)
                val text = cursor.getString(1)
                val sender = cursor.getString(2)
                val title = cursor.getString(3)
                val values = ContentValues().apply {
                    put("removed_at", System.currentTimeMillis())
                    put("is_deleted", 1)
                }
                db.update("messages", values, "id = ?", arrayOf(id.toString()))
                result = RemovalResult(chatKey, title, text, sender, true)
            }
        }
        return result
    }

    private fun getLastOpenedAt(chatKey: String): Long? {
        readableDatabase.rawQuery(
            "SELECT last_opened_at FROM chats WHERE chat_key = ?", arrayOf(chatKey)
        ).use { cursor ->
            if (cursor.moveToFirst() && !cursor.isNull(0)) return cursor.getLong(0)
        }
        return null
    }

    private fun getLastActivityAt(chatKey: String): Long? {
        readableDatabase.rawQuery(
            "SELECT last_activity_at FROM chats WHERE chat_key = ?", arrayOf(chatKey)
        ).use { cursor ->
            if (cursor.moveToFirst() && !cursor.isNull(0)) return cursor.getLong(0)
        }
        return null
    }

    fun touchChatActivity(chatKey: String, atMillis: Long) {
        writableDatabase.execSQL(
            "UPDATE chats SET last_activity_at = ? WHERE chat_key = ?",
            arrayOf(atMillis, chatKey)
        )
    }

    fun markChatOpened(chatKey: String) {
        writableDatabase.execSQL(
            "UPDATE chats SET last_opened_at = ? WHERE chat_key = ?",
            arrayOf(System.currentTimeMillis(), chatKey)
        )
    }

    fun getChats(): List<Map<String, Any?>> {
        val result = mutableListOf<Map<String, Any?>>()
        readableDatabase.rawQuery(
            """
            SELECT c.chat_key, c.package, c.title, c.is_group,
                   (SELECT text FROM messages m WHERE m.chat_key = c.chat_key ORDER BY timestamp DESC LIMIT 1) AS last_text,
                   (SELECT timestamp FROM messages m WHERE m.chat_key = c.chat_key ORDER BY timestamp DESC LIMIT 1) AS last_ts,
                   (SELECT COUNT(*) FROM messages m WHERE m.chat_key = c.chat_key AND m.is_deleted = 1) AS deleted_count,
                   (SELECT COUNT(*) FROM messages m WHERE m.chat_key = c.chat_key) AS total_count
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
                        "deletedCount" to cursor.getInt(6),
                        "totalCount" to cursor.getInt(7)
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
            SELECT id, sender, text, media_path, media_type, media_mime, timestamp, removed_at, is_deleted, is_edited, edited_text
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
                        "isDeleted" to (cursor.getInt(8) == 1),
                        "isEdited" to (cursor.getInt(9) == 1),
                        "editedText" to cursor.getString(10)
                    )
                )
            }
        }
        return result
    }

    fun getDeletedFeed(): List<Map<String, Any?>> {
        val result = mutableListOf<Map<String, Any?>>()
        readableDatabase.rawQuery(
            """
            SELECT m.id, m.chat_key, c.title, c.package, m.sender, m.text, m.media_path, m.media_type, m.media_mime, m.timestamp, m.removed_at
            FROM messages m JOIN chats c ON c.chat_key = m.chat_key
            WHERE m.is_deleted = 1
            ORDER BY m.removed_at DESC
            """.trimIndent(),
            null
        ).use { cursor ->
            while (cursor.moveToNext()) {
                result.add(
                    mapOf(
                        "id" to cursor.getLong(0),
                        "chatKey" to cursor.getString(1),
                        "chatTitle" to cursor.getString(2),
                        "package" to cursor.getString(3),
                        "sender" to cursor.getString(4),
                        "text" to cursor.getString(5),
                        "mediaPath" to cursor.getString(6),
                        "mediaType" to cursor.getString(7),
                        "mediaMime" to cursor.getString(8),
                        "timestamp" to cursor.getLong(9),
                        "removedAt" to (if (cursor.isNull(10)) null else cursor.getLong(10))
                    )
                )
            }
        }
        return result
    }

    fun clearAll() {
        val db = writableDatabase
        db.execSQL("DELETE FROM messages")
        db.execSQL("DELETE FROM chats")
    }
}
