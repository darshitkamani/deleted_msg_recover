package com.recoverdeletedmessages.app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.documentfile.provider.DocumentFile
import java.io.File
import java.io.FileOutputStream

private const val TAG = "MediaFolderRepository"

private const val PREFS = "media_folder_prefs"

/** One WhatsApp media subfolder this app knows how to recover from, and what it recovers as.
 * Each entry in [suffixes] is matched against the *end* of a folder's name (as a trailing word,
 * not a substring) rather than requiring one exact name -- WhatsApp Business renames every
 * subfolder with a "Business" infix ("WhatsApp Video" becomes "WhatsApp Business Video"), and
 * some categories go by more than one name across WhatsApp versions/branding (documents show up
 * as "...Documents" on WhatsApp but "...Attachments" has been observed on WhatsApp Business), so
 * multiple suffixes per category is what makes this hold up across both. */
private data class MediaSubfolder(val suffixes: List<String>, val extensions: Set<String>, val mediaType: String)

/** The four Recover-grid categories that scan WhatsApp's own Media folder directly (Photo,
 * Video, Files, Stickers & GIFs) -- unlike chat-message recovery, this catches media whose
 * WhatsApp message was deleted but whose downloaded file is still sitting on disk, because
 * WhatsApp does not clean up its Media folder just because a message referencing it was deleted. */
private val KIND_SUBFOLDERS: Map<String, List<MediaSubfolder>> = mapOf(
    "photo" to listOf(
        MediaSubfolder(listOf("Images"), setOf("jpg", "jpeg", "png", "webp"), "image")
    ),
    "video" to listOf(
        MediaSubfolder(listOf("Video"), setOf("mp4", "3gp", "mkv"), "video")
    ),
    "files" to listOf(
        MediaSubfolder(
            listOf("Documents", "Attachments"),
            setOf("pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "zip", "rar", "txt", "csv", "rtf"),
            "document"
        )
    ),
    // "Stickers" as a trailing word matches "WhatsApp Stickers" / "WhatsApp Business Stickers"
    // but not "WhatsApp Business Sticker Packs" (WhatsApp's own pack-management assets, not
    // stickers a user actually sent/received) since that ends in "Packs", not "Stickers".
    "stickersGifs" to listOf(
        MediaSubfolder(listOf("Stickers"), setOf("webp"), "sticker"),
        MediaSubfolder(listOf("Animated Gifs"), setOf("gif", "mp4", "webp"), "gif")
    )
)

/**
 * Recovers media by scanning WhatsApp/WhatsApp Business's own Media folder on disk, the same
 * Storage Access Framework approach [StatusRepository] uses for statuses -- one folder grant per
 * package covers every kind here (Photo/Video/Files/Stickers & GIFs), rather than a separate
 * grant per category, since they're all subfolders of the same "Media" directory.
 */
object MediaFolderRepository {

    fun expectedFolderHint(pkg: String): String {
        val appFolder = if (pkg == "com.whatsapp.w4b") "WhatsApp Business" else "WhatsApp"
        return "Android/media/$pkg/$appFolder/Media"
    }

    fun saveAccess(context: Context, pkg: String, treeUri: Uri) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("tree_$pkg", treeUri.toString())
            .apply()
    }

    private fun getTreeUri(context: Context, pkg: String): Uri? {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString("tree_$pkg", null) ?: return null
        return Uri.parse(raw)
    }

    fun hasAccess(context: Context, pkg: String): Boolean {
        val uri = getTreeUri(context, pkg) ?: return false
        return context.contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission
        }
    }

    /**
     * Everything already saved for this (kind, package), newest first -- purely a local
     * directory listing, no SAF calls, so it stays fast regardless of how large WhatsApp's own
     * Media folder is or how slow the device's storage is. Backs the screen's first paint.
     */
    fun listMedia(context: Context, kind: String, pkg: String): List<Map<String, Any?>> {
        val subfolders = KIND_SUBFOLDERS[kind] ?: emptyList()
        val dir = File(context.filesDir, "media_recovery/$kind/$pkg").apply { mkdirs() }
        val files = dir.listFiles()?.filter { it.isFile } ?: emptyList()
        return files.sortedByDescending { it.lastModified() }.map { f ->
            val ext = f.name.substringAfterLast('.', "").lowercase()
            val mediaType = subfolders.firstOrNull { ext in it.extensions }?.mediaType ?: "document"
            mapOf(
                "path" to f.absolutePath,
                "fileName" to f.name,
                "mediaType" to mediaType,
                "lastModified" to f.lastModified()
            )
        }
    }

    /**
     * The slow half: walks the granted Media tree looking for [kind]'s subfolder(s) and copies
     * anything not already saved. Deliberately separate from [listMedia] -- this is what used to
     * block the screen's first paint on a full recursive SAF walk before returning any results at
     * all, which stalled badly on large media folders or slow storage. Callers should run this in
     * the background and re-call [listMedia] once it completes, rather than waiting on it before
     * showing anything.
     */
    fun syncMedia(context: Context, kind: String, pkg: String) {
        val subfolders = KIND_SUBFOLDERS[kind] ?: return
        val dir = File(context.filesDir, "media_recovery/$kind/$pkg").apply { mkdirs() }
        val treeUri = getTreeUri(context, pkg) ?: return
        if (!hasAccess(context, pkg)) return

        // Defensive check against granting the wrong package's folder (or a
        // shared parent covering both): if the granted tree's own path
        // doesn't even mention this package, scanning it would silently
        // recover the other app's media under this one's tab. Better to
        // treat it as not granted than cross-contaminate WhatsApp and
        // WhatsApp Business.
        val decodedTree = Uri.decode(treeUri.toString())
        if (!decodedTree.contains("/$pkg/")) {
            Log.w(TAG, "granted tree for '$pkg' doesn't mention that package ($decodedTree) -- skipping sync")
            return
        }

        // Deliberately not swallowed: a throw here (e.g. the granted tree no
        // longer resolves) needs to reach the caller and surface as a real
        // error, not silently look identical to "found nothing".
        val tree = DocumentFile.fromTreeUri(context, treeUri) ?: return

        for (subfolder in subfolders) {
            copyMatchingRecursively(context, tree, dir, subfolder, depth = 0, insideMatch = false)
        }
    }

    /**
     * Same depth-limited, name-tolerant search [StatusRepository] uses -- different pickers and
     * device folder layouts mean the exact subfolder a user grants varies, so this walks down
     * looking for a folder whose name *ends with* one of [MediaSubfolder.suffixes] as a trailing
     * word (case-insensitively) rather than requiring one fixed name -- WhatsApp Business
     * prefixes every subfolder with "Business" ("WhatsApp Business Video"), so an exact-name
     * match would silently never find anything under that package.
     *
     * [insideMatch] carries a category match down through the recursion: WhatsApp splits every
     * one of these folders into "Sent"/"Private" subfolders that hold the actual files, so a
     * folder named e.g. "WhatsApp Business Video" matching isn't enough on its own -- its child
     * folders (named "Sent"/"Private", not "...Video") need to inherit that match too, or their
     * files get silently skipped.
     */
    private fun copyMatchingRecursively(
        context: Context,
        folder: DocumentFile,
        dest: File,
        subfolder: MediaSubfolder,
        depth: Int,
        insideMatch: Boolean
    ) {
        if (depth > 5) return
        val folderName = folder.name?.trim()
        val children = try {
            folder.listFiles()
        } catch (e: Exception) {
            // Logged rather than silently dropped -- this branch of the
            // tree just contributes nothing, but if it turns out to be the
            // one branch that mattered, logcat is the only way to know.
            Log.w(TAG, "listFiles failed for '$folderName'", e)
            return
        }
        val matchesHere = insideMatch || (folderName != null && subfolder.suffixes.any { suffix ->
            folderName.endsWith(suffix, ignoreCase = true) &&
                (folderName.length == suffix.length ||
                    folderName[folderName.length - suffix.length - 1] == ' ')
        })
        Log.d(
            TAG,
            "scanning '$folderName' (${children.size} entries, matched=$matchesHere) for suffixes ${subfolder.suffixes}"
        )
        for (doc in children) {
            if (doc.isDirectory) {
                copyMatchingRecursively(context, doc, dest, subfolder, depth + 1, matchesHere)
                continue
            }
            if (!matchesHere) continue
            val name = doc.name ?: continue
            val ext = name.substringAfterLast('.', "").lowercase()
            if (ext !in subfolder.extensions) continue
            val outFile = File(dest, name)
            if (outFile.exists() && outFile.length() == doc.length()) continue
            try {
                context.contentResolver.openInputStream(doc.uri)?.use { input ->
                    FileOutputStream(outFile).use { output -> input.copyTo(output) }
                } ?: Log.w(TAG, "openInputStream returned null for '$name'")
            } catch (e: Exception) {
                Log.w(TAG, "failed copying '$name'", e)
            }
        }
    }
}
