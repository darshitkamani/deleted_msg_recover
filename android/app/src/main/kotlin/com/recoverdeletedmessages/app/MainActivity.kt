package com.recoverdeletedmessages.app

import android.content.ComponentName
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.webkit.MimeTypeMap
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

private const val METHOD_CHANNEL = "recover/native"
private const val EVENT_CHANNEL = "recover/events"
private const val REQUEST_STATUS_FOLDER = 4201

class MainActivity : FlutterActivity() {

    private var pendingStatusResult: MethodChannel.Result? = null
    private var pendingStatusPackage: String? = null
    private val bgExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ActivityCompat.requestPermissions(
                this, arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1001
            )
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                val store = MessageStore.getInstance(applicationContext)
                try {
                    when (call.method) {
                        "isNotificationAccessGranted" -> {
                            val granted = isNotificationAccessGranted()
                            if (granted) {
                                mainHandler.postDelayed({ KeepAliveStarter.start(applicationContext) }, 2000)
                            }
                            result.success(granted)
                        }
                        "openNotificationAccessSettings" -> {
                            openNotificationAccessSettings()
                            result.success(null)
                        }
                        "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBatteryOptimizations())
                        "requestIgnoreBatteryOptimizations" -> {
                            requestIgnoreBatteryOptimizations()
                            result.success(null)
                        }
                        // Chats/messages/deleted-feed queries run several correlated
                        // subqueries per row -- fast normally, but slow enough to ANR
                        // on the main thread once a backlog of messages piles up (e.g.
                        // after being offline for a while), so these all run off-thread.
                        "getChats" -> runInBackground(result) { store.getChats() }
                        "getMessages" -> {
                            val chatKey = call.argument<String>("chatKey")
                            if (chatKey == null) {
                                result.error("missing_arg", "chatKey required", null)
                            } else {
                                runInBackground(result) { store.getMessages(chatKey) }
                            }
                        }
                        "getDeletedFeed" -> runInBackground(result) { store.getDeletedFeed() }
                        "markChatOpened" -> {
                            val chatKey = call.argument<String>("chatKey")
                            if (chatKey == null) {
                                result.error("missing_arg", "chatKey required", null)
                            } else {
                                runInBackground(result) { store.markChatOpened(chatKey); null }
                            }
                        }
                        "clearAll" -> runInBackground(result) { store.clearAll(); null }
                        "getMonitoredApps" -> result.success(MonitorPrefs.getMonitored(applicationContext).toList())
                        "setMonitoredApps" -> {
                            val apps = call.argument<List<String>>("apps") ?: emptyList()
                            MonitorPrefs.setMonitored(applicationContext, apps.toSet())
                            result.success(null)
                        }
                        "openFile" -> {
                            val path = call.argument<String>("path")
                            val mime = call.argument<String>("mime")
                            if (path == null) {
                                result.error("missing_arg", "path required", null)
                            } else {
                                result.success(openFile(path, mime))
                            }
                        }
                        "hasStatusAccess" -> {
                            val pkg = call.argument<String>("package")
                            if (pkg == null) {
                                result.error("missing_arg", "package required", null)
                            } else {
                                result.success(StatusRepository.hasAccess(applicationContext, pkg))
                            }
                        }
                        "requestStatusAccess" -> {
                            val pkg = call.argument<String>("package")
                            if (pkg == null) {
                                result.error("missing_arg", "package required", null)
                            } else {
                                requestStatusAccess(pkg, result)
                            }
                        }
                        "listStatuses" -> {
                            val pkg = call.argument<String>("package")
                            if (pkg == null) {
                                result.error("missing_arg", "package required", null)
                            } else {
                                // Walks the SAF-granted folder tree and copies new files --
                                // each SAF call is an IPC round-trip, so this must never run
                                // on the main thread (it previously caused ANRs).
                                runInBackground(result) { StatusRepository.listStatuses(applicationContext, pkg) }
                            }
                        }
                        "statusFolderHint" -> {
                            val pkg = call.argument<String>("package")
                            if (pkg == null) {
                                result.error("missing_arg", "package required", null)
                            } else {
                                result.success(StatusRepository.expectedFolderHint(pkg))
                            }
                        }
                        "openBackgroundAppSettings" -> {
                            openBackgroundAppSettings()
                            result.success(null)
                        }
                        "downloadMedia" -> {
                            val path = call.argument<String>("path")
                            val isVideo = call.argument<Boolean>("isVideo") ?: false
                            val mime = call.argument<String>("mime")
                            if (path == null) {
                                result.error("missing_arg", "path required", null)
                            } else {
                                // Copies the file into the public gallery -- can be a
                                // sizable video, so this must run off the main thread.
                                runInBackground(result) { downloadMedia(path, isVideo, mime) }
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("native_error", e.message, null)
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    EventBridge.attach(events)
                }

                override fun onCancel(arguments: Any?) {
                    EventBridge.attach(null)
                }
            })
    }

    /**
     * Runs [work] on a background thread and delivers its return value (or
     * any exception) back to [result] on the main thread, as required by the
     * MethodChannel contract. Use for anything that touches SQLite or the
     * filesystem -- the platform channel handler itself runs on the main
     * thread, so doing that work inline risks janking the UI or, with a
     * large enough backlog, an ANR.
     */
    private fun runInBackground(result: MethodChannel.Result, work: () -> Any?) {
        bgExecutor.execute {
            try {
                val value = work()
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                mainHandler.post { result.error("native_error", e.message, null) }
            }
        }
    }

    private fun openNotificationAccessSettings() {
        val myComponent = ComponentName(this, NotificationListener::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).apply {
                    putExtra(
                        Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                        myComponent.flattenToString()
                    )
                }
                startActivity(intent)
                return
            } catch (_: Exception) {
                // Some OEMs don't implement the detail screen despite the API level; fall through.
            }
        }
        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
    }

    private fun isNotificationAccessGranted(): Boolean {
        val enabledListeners = Settings.Secure.getString(
            contentResolver, "enabled_notification_listeners"
        ) ?: return false
        val myComponent = ComponentName(this, NotificationListener::class.java).flattenToString()
        return enabledListeners.contains(myComponent)
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations() {
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:$packageName")
        }
        startActivity(intent)
    }

    /**
     * Opens a recovered file with whatever app the user has for its type.
     * Prefers the mime type WhatsApp itself reported when the file was
     * captured (e.g. "audio/ogg; codecs=opus") over guessing from the file
     * extension, since captured files often have a generic ".bin" extension
     * when Android's MimeTypeMap doesn't know that mime type.
     */
    private fun openFile(path: String, knownMime: String?): Boolean {
        val file = File(path)
        if (!file.exists()) return false
        return try {
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            val mime = knownMime?.substringBefore(';')?.trim()?.takeIf { it.isNotEmpty() }
                ?: MimeTypeMap.getSingleton().getMimeTypeFromExtension(file.extension.lowercase())
                ?: "*/*"
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Saves a recovered file into the public gallery (Pictures/Movies) so it
     * survives outside this app and shows up in the user's normal gallery
     * app. From API 29 (Android 10) on this goes entirely through MediaStore
     * and needs no storage permission at all, since scoped storage lets any
     * app insert into the public collections without touching other apps'
     * files. Below API 29, MediaStore isn't available for this and a direct
     * write to public storage needs WRITE_EXTERNAL_STORAGE, which must
     * already be granted -- callers should request it first if missing.
     */
    private fun downloadMedia(sourcePath: String, isVideo: Boolean, knownMime: String?): Boolean {
        val srcFile = File(sourcePath)
        if (!srcFile.exists()) return false
        val displayName = srcFile.name
        val mime = knownMime?.substringBefore(';')?.trim()?.takeIf { it.isNotEmpty() }
            ?: MimeTypeMap.getSingleton().getMimeTypeFromExtension(srcFile.extension.lowercase())
            ?: if (isVideo) "video/mp4" else "image/jpeg"

        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val collection = if (isVideo) {
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                } else {
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                }
                val relativePath = if (isVideo) {
                    "${Environment.DIRECTORY_MOVIES}/Recover Deleted Messages"
                } else {
                    "${Environment.DIRECTORY_PICTURES}/Recover Deleted Messages"
                }
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
                    put(MediaStore.MediaColumns.MIME_TYPE, mime)
                    put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
                val uri = contentResolver.insert(collection, values) ?: return false
                contentResolver.openOutputStream(uri)?.use { out ->
                    srcFile.inputStream().use { it.copyTo(out) }
                } ?: return false
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
                true
            } else {
                if (ContextCompat.checkSelfPermission(
                        this, android.Manifest.permission.WRITE_EXTERNAL_STORAGE
                    ) != PackageManager.PERMISSION_GRANTED
                ) {
                    mainHandler.post {
                        ActivityCompat.requestPermissions(
                            this, arrayOf(android.Manifest.permission.WRITE_EXTERNAL_STORAGE), 1002
                        )
                    }
                    return false
                }
                val publicDir = Environment.getExternalStoragePublicDirectory(
                    if (isVideo) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_PICTURES
                )
                val destDir = File(publicDir, "Recover Deleted Messages").apply { mkdirs() }
                val destFile = File(destDir, displayName)
                srcFile.inputStream().use { input ->
                    FileOutputStream(destFile).use { output -> input.copyTo(output) }
                }
                MediaScannerConnection.scanFile(this, arrayOf(destFile.absolutePath), arrayOf(mime), null)
                true
            }
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Launches the system folder picker so the user can grant read access
     * to WhatsApp's own Statuses folder. This is Storage Access Framework,
     * not a broad "all files" permission -- the grant only covers whatever
     * single folder the user explicitly picks and confirms.
     */
    private fun requestStatusAccess(pkg: String, result: MethodChannel.Result) {
        pendingStatusResult = result
        pendingStatusPackage = pkg
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            try {
                val appFolder = if (pkg == "com.whatsapp.w4b") "WhatsApp Business" else "WhatsApp"
                val hintPath = "primary:Android/media/$pkg/$appFolder/Media/.Statuses"
                putExtra(
                    DocumentsContract.EXTRA_INITIAL_URI,
                    DocumentsContract.buildDocumentUri("com.android.externalstorage.documents", hintPath)
                )
            } catch (_: Exception) {
                // Hint is a convenience only; the picker still opens without it.
            }
        }
        try {
            startActivityForResult(intent, REQUEST_STATUS_FOLDER)
        } catch (_: Exception) {
            pendingStatusResult = null
            pendingStatusPackage = null
            result.success(false)
        }
    }

    override fun onResume() {
        super.onResume()
        // Nudges the system to reconnect the notification listener if it
        // was silently unbound (e.g. after the process was killed and later
        // restarted by Android without rebinding it) -- harmless no-op if
        // access isn't granted or it's already connected.
        try {
            NotificationListenerService.requestRebind(
                ComponentName(this, NotificationListener::class.java)
            )
        } catch (_: Exception) {
        }
        if (isNotificationAccessGranted()) {
            // Delayed rather than immediate: right after onResume() the main
            // thread can still be saturated finishing engine/first-frame
            // startup work (especially in a JIT debug build on a slow
            // device), and Android's startForeground() clock starts the
            // instant startForegroundService() is called -- giving the main
            // thread a moment to drain first makes the service's own
            // onStartCommand() far more likely to run promptly. A missed
            // window is now non-fatal regardless (see RecoverApplication), this
            // just reduces how often that fallback is needed.
            mainHandler.postDelayed({ KeepAliveStarter.start(applicationContext) }, 2000)
        }
    }

    /**
     * Many manufacturers (Xiaomi/MIUI, Oppo/ColorOS, Vivo, OnePlus, Huawei,
     * Samsung) layer their own background-app killer on top of stock
     * Android's battery optimization, with a separate "autostart" or
     * "protected apps" toggle stock Android has no equivalent for and no
     * API to query. These are the well-known screens for each -- tried in
     * order, falling back to this app's own App Info page if none resolve
     * (which still exists and lets the user find it manually).
     */
    private fun openBackgroundAppSettings() {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val candidates = mutableListOf<Intent>()

        when {
            manufacturer.contains("xiaomi") -> candidates.add(
                Intent().setComponent(
                    ComponentName(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.autostart.AutoStartManagementActivity"
                    )
                )
            )
            manufacturer.contains("oppo") -> {
                candidates.add(
                    Intent().setComponent(
                        ComponentName(
                            "com.coloros.safecenter",
                            "com.coloros.safecenter.permission.startup.StartupAppListActivity"
                        )
                    )
                )
                candidates.add(
                    Intent().setComponent(
                        ComponentName(
                            "com.oppo.safe",
                            "com.oppo.safe.permission.startup.StartupAppListActivity"
                        )
                    )
                )
            }
            manufacturer.contains("vivo") -> candidates.add(
                Intent().setComponent(
                    ComponentName(
                        "com.vivo.permissionmanager",
                        "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
                    )
                )
            )
            manufacturer.contains("oneplus") -> candidates.add(
                Intent().setComponent(
                    ComponentName(
                        "com.oneplus.security",
                        "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"
                    )
                )
            )
            manufacturer.contains("huawei") -> candidates.add(
                Intent().setComponent(
                    ComponentName(
                        "com.huawei.systemmanager",
                        "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
                    )
                )
            )
            manufacturer.contains("samsung") -> candidates.add(
                Intent().setComponent(
                    ComponentName(
                        "com.samsung.android.lool",
                        "com.samsung.android.sm.ui.battery.BatteryActivity"
                    )
                )
            )
        }

        for (intent in candidates) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return
            } catch (_: Exception) {
                // Not present on this device/ROM version; try the next one.
            }
        }

        try {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            )
        } catch (_: Exception) {
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_STATUS_FOLDER) return

        val result = pendingStatusResult
        val pkg = pendingStatusPackage
        pendingStatusResult = null
        pendingStatusPackage = null

        val treeUri = data?.data
        if (resultCode == RESULT_OK && treeUri != null && pkg != null) {
            try {
                contentResolver.takePersistableUriPermission(
                    treeUri, Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
                StatusRepository.saveAccess(applicationContext, pkg, treeUri)
                result?.success(true)
            } catch (_: Exception) {
                result?.success(false)
            }
        } else {
            result?.success(false)
        }
    }
}
