package com.recoverdeletedmessages.app

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

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

/**
 * Single local datastore for captured WhatsApp/WhatsApp Business notifications.
 * This is the only source of truth for message data; Flutter never touches
 * the database directly, it only calls through the MethodChannel.
 */
class MessageStore private constructor(context: Context) :
    SQLiteOpenHelper(context.applicationContext, DB_NAME, null, DB_VERSION) {

    companion object {
        private const val DB_NAME = "recover.db"
        private const val DB_VERSION = 5

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
                removed_at INTEGER
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
        if (rowId != -1L) return InsertResult(rowId, mediaBackfilled = false)

        // A row for this (notif_key, timestamp) already exists -- this happens
        // when the same notification gets reprocessed (e.g. app restart, or
        // WhatsApp updating it in place). Media that failed to save before
        // might now succeed -- backfill it.
        var mediaBackfilled = false
        db.rawQuery(
            "SELECT id, media_path FROM messages WHERE chat_key = ? AND notif_key = ? AND timestamp = ?",
            arrayOf(chatKey, notifKey, timestamp.toString())
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
    }

    /** Marks every not-yet-removed message belonging to [notifKey] as removed. */
    fun markRemoved(notifKey: String, removedAt: Long): List<RemovalResult> {
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
                        "totalCount" to cursor.getInt(6)
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
            SELECT id, sender, text, media_path, media_type, media_mime, timestamp, removed_at
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
                        "removedAt" to (if (cursor.isNull(7)) null else cursor.getLong(7))
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
