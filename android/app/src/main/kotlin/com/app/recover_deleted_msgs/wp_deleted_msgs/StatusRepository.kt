package com.app.recover_deleted_msgs.wp_deleted_msgs

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import java.io.File
import java.io.FileOutputStream

private const val PREFS = "status_prefs"
private val MEDIA_EXTENSIONS = setOf("jpg", "jpeg", "png", "webp", "mp4", "gif", "3gp")

/**
 * WhatsApp/WhatsApp Business keep currently-active statuses in a folder
 * under their own app-private external media directory (deleted by
 * WhatsApp itself ~24h after posting). Reading another app's folder there
 * requires the user to grant it once via the system folder picker (Storage
 * Access Framework) -- there's no broad "all files" permission involved.
 * Once granted, we copy anything new into our own storage so it survives
 * past WhatsApp's own 24h expiry.
 */
object StatusRepository {

    fun expectedFolderHint(pkg: String): String {
        val appFolder = if (pkg == "com.whatsapp.w4b") "WhatsApp Business" else "WhatsApp"
        return "Android/media/$pkg/$appFolder/Media/.Statuses"
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

    fun revokeAccess(context: Context, pkg: String) {
        val uri = getTreeUri(context, pkg)
        if (uri != null) {
            try {
                context.contentResolver.releasePersistableUriPermission(
                    uri, Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            } catch (_: Exception) {
            }
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .remove("tree_$pkg")
            .apply()
    }

    /**
     * Copies any status media not already saved from the granted folder
     * into our own storage, then returns everything saved so far for this
     * package, newest first.
     */
    fun listStatuses(context: Context, pkg: String): List<Map<String, Any?>> {
        val dir = File(context.filesDir, "statuses/$pkg").apply { mkdirs() }
        val treeUri = getTreeUri(context, pkg)

        if (treeUri != null && hasAccess(context, pkg)) {
            val tree = try {
                DocumentFile.fromTreeUri(context, treeUri)
            } catch (_: Exception) {
                null
            }
            if (tree != null) copyMediaRecursively(context, tree, dir, depth = 0)
        }

        val files = dir.listFiles()?.filter { it.isFile } ?: emptyList()
        return files.sortedByDescending { it.lastModified() }.map { f ->
            val ext = f.name.substringAfterLast('.', "").lowercase()
            mapOf(
                "path" to f.absolutePath,
                "isVideo" to (ext == "mp4" || ext == "3gp"),
                "lastModified" to f.lastModified()
            )
        }
    }

    /**
     * Different device file pickers behave inconsistently around the hidden
     * ".Statuses" folder -- some hide dotfolders by default, so depending on
     * the picker a user may end up granting the exact ".Statuses" folder, or
     * a parent of it ("Media", or the app's whole folder) one level up.
     * Searching a few levels down instead of assuming an exact leaf folder
     * was granted is what makes this work consistently across devices.
     */
    private fun copyMediaRecursively(context: Context, folder: DocumentFile, dest: File, depth: Int) {
        if (depth > 4) return
        val children = try {
            folder.listFiles()
        } catch (_: Exception) {
            return
        }
        for (doc in children) {
            if (doc.isDirectory) {
                copyMediaRecursively(context, doc, dest, depth + 1)
                continue
            }
            val name = doc.name ?: continue
            val ext = name.substringAfterLast('.', "").lowercase()
            if (ext !in MEDIA_EXTENSIONS) continue
            val outFile = File(dest, name)
            if (outFile.exists() && outFile.length() == doc.length()) continue
            try {
                context.contentResolver.openInputStream(doc.uri)?.use { input ->
                    FileOutputStream(outFile).use { output -> input.copyTo(output) }
                }
            } catch (_: Exception) {
            }
        }
    }
}
