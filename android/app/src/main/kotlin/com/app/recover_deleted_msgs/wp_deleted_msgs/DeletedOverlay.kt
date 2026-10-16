package com.app.recover_deleted_msgs.wp_deleted_msgs

import android.annotation.SuppressLint
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import android.widget.Toast
import com.google.android.gms.ads.AdListener
import com.google.android.gms.ads.AdLoader
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdOptions
import com.google.android.gms.ads.nativead.NativeAdView

/**
 * The "message deleted / edited" popup drawn over other apps (needs "Display over other apps").
 *
 * Shown by [NotificationListener] right where a deletion or edit is detected, so like
 * [AlertNotifier] it's plain native UI that works with no Flutter engine running.
 *
 * Expanded, it's a recovered-message screen in the style of a caller-ID app's after-call screen:
 * who and when, the whole message, Copy / Open WhatsApp actions, a native ad, and "See all
 * deleted messages". The window goes full screen with the rest dimmed (tap there, or ✕, to
 * close), so the card always has room -- a wrap-content window centered on screen doesn't
 * reliably grow, which left the ad below the visible part.
 *
 * Whether it opens expanded straight away is the hosted config's call
 * ([MonitorPrefs.overlayAutoExpand]), at most once per [MonitorPrefs.overlayAutoExpandIntervalMs];
 * otherwise -- or within that interval -- it starts as a small centered card that hides itself
 * after [AUTO_HIDE_MS] (or swipe it up, or ✕), takes touches only on itself, and expands on tap.
 *
 * Everything here runs on the main thread ([main]).
 */
object DeletedOverlay {

    private const val TAG = "DeletedOverlay"
    private const val AUTO_HIDE_MS = 8_000L

    private val main = Handler(Looper.getMainLooper())

    private var windowManager: WindowManager? = null
    private var windowParams: WindowManager.LayoutParams? = null
    private var root: View? = null
    private var expanded = false
    private var nativeAd: NativeAd? = null

    /** When the popup last opened expanded by itself, for the config's minimum interval. */
    private var lastAutoExpandAt = 0L

    /** The latest message's app (for "Open WhatsApp") and text (for "Copy"). */
    private var currentPackage: String? = null
    private var currentCopyText: String? = null

    /** Deletions and edits shown in the current popup, for its "N messages ..." header. */
    private var deletedCount = 0
    private var editedCount = 0

    private val autoHide = Runnable { dismiss() }

    fun hasPermission(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)

    /** Shows (or, if already up, updates) the popup for one deleted message. */
    fun showDeleted(
        context: Context,
        packageName: String,
        chatTitle: String,
        sender: String?,
        text: String?,
        possible: Boolean
    ) {
        val app = context.applicationContext
        val single = if (possible) R.string.alert_possibly_deleted_title else R.string.alert_deleted_title
        val group = if (possible) R.string.alert_possibly_deleted_title_group else R.string.alert_deleted_title_group
        val body = text?.takeIf { it.isNotBlank() } ?: app.getString(R.string.alert_message_fallback)
        val title = title(app, single, group, chatTitle, sender)
        show(app, packageName, title, body, copyText = text?.takeIf { it.isNotBlank() }, edited = false)
    }

    /** Shows (or, if already up, updates) the popup for one edited message: before and after. */
    fun showEdited(
        context: Context,
        packageName: String,
        chatTitle: String,
        sender: String?,
        previousText: String,
        newText: String
    ) {
        val app = context.applicationContext
        val title = title(app, R.string.alert_edited_title, R.string.alert_edited_title_group, chatTitle, sender)
        val body = app.getString(R.string.alert_edited_body, previousText, newText)
        // The original is what the edit hid, so that's what Copy gives back.
        show(app, packageName, title, body, copyText = previousText, edited = true)
    }

    /** Same wording as [AlertNotifier]'s notifications. */
    private fun title(app: Context, single: Int, group: Int, chatTitle: String, sender: String?): String =
        if (sender.isNullOrBlank() || sender == chatTitle) app.getString(single, chatTitle)
        else app.getString(group, sender, chatTitle)

    private fun show(
        app: Context,
        packageName: String,
        title: String,
        body: String,
        copyText: String?,
        edited: Boolean
    ) {
        if (AppVisibility.isForeground) return
        if (!MonitorPrefs.overlayEnabled(app) || !hasPermission(app)) return
        main.post {
            try {
                currentPackage = packageName
                currentCopyText = copyText
                showOnMain(app, title, body, edited)
            } catch (e: Exception) {
                // e.g. the permission was revoked a moment ago -- the notification still went out.
                Log.w(TAG, "Couldn't show the popup", e)
                dismiss()
            }
        }
    }

    /** Removes the popup, if shown. Safe to call from any thread. */
    fun dismiss() {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            main.post { dismiss() }
            return
        }
        main.removeCallbacks(autoHide)
        nativeAd?.destroy()
        nativeAd = null
        val view = root ?: return
        root = null
        windowParams = null
        expanded = false
        deletedCount = 0
        editedCount = 0
        try {
            windowManager?.removeView(view)
        } catch (_: Exception) {
        }
    }

    private fun showOnMain(app: Context, title: String, body: String, edited: Boolean) {
        val isNew = root == null
        val view = root ?: createWindow(app)
        if (edited) editedCount++ else deletedCount++
        val count = deletedCount + editedCount
        view.findViewById<TextView>(R.id.overlay_title).text = when {
            count == 1 -> title
            editedCount == 0 -> app.getString(R.string.overlay_title_many, count)
            deletedCount == 0 -> app.getString(R.string.overlay_title_many_edited, count)
            else -> app.getString(R.string.overlay_title_many_mixed, count)
        }
        view.findViewById<TextView>(R.id.overlay_message).text =
            if (count > 1) "$title\n$body" else body
        // Red for a deletion, the accent color for an edit -- following the latest one.
        view.findViewById<ImageView>(R.id.overlay_icon).setColorFilter(
            app.getColor(if (edited) R.color.overlay_accent else R.color.overlay_deleted)
        )
        view.findViewById<TextView>(R.id.overlay_time).text =
            android.text.format.DateFormat.getTimeFormat(app).format(java.util.Date())
        view.findViewById<TextView>(R.id.overlay_copy).visibility =
            if (currentCopyText != null) View.VISIBLE else View.GONE
        view.findViewById<TextView>(R.id.overlay_open_chat_app).text =
            app.getString(R.string.overlay_open_chat_app, appLabel(app, currentPackage))

        if (isNew && autoExpandAllowed(app)) {
            lastAutoExpandAt = System.currentTimeMillis()
            expand(app)
        } else if (!expanded) {
            main.removeCallbacks(autoHide)
            main.postDelayed(autoHide, AUTO_HIDE_MS)
        }
    }

    private fun autoExpandAllowed(app: Context): Boolean =
        MonitorPrefs.overlayAutoExpand(app) &&
            System.currentTimeMillis() - lastAutoExpandAt >= MonitorPrefs.overlayAutoExpandIntervalMs(app)

    private fun appLabel(app: Context, packageName: String?): String {
        if (packageName == null) return "WhatsApp"
        return try {
            val pm = app.packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString()
        } catch (_: Exception) {
            "WhatsApp"
        }
    }

    private fun copyMessage(app: Context) {
        val text = currentCopyText ?: return
        val clipboard = app.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager ?: return
        clipboard.setPrimaryClip(ClipData.newPlainText(app.getString(R.string.alert_message_fallback), text))
        // Android 13+ shows its own "copied" confirmation.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            Toast.makeText(app, R.string.overlay_copied, Toast.LENGTH_SHORT).show()
        }
    }

    /** Opens WhatsApp (or WA Business) itself -- a notification doesn't say how to reach the chat. */
    private fun openChatApp(app: Context) {
        val pkg = currentPackage ?: return
        val intent = app.packageManager.getLaunchIntentForPackage(pkg) ?: return
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            app.startActivity(intent)
        } catch (e: Exception) {
            Log.w(TAG, "Couldn't open $pkg from the popup", e)
        }
    }

    @SuppressLint("ClickableViewAccessibility", "InflateParams")
    private fun createWindow(app: Context): View {
        val wm = app.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        windowManager = wm
        val view = LayoutInflater.from(app).inflate(R.layout.overlay_deleted, null)

        val card = view.findViewById<View>(R.id.overlay_card)
        // Tap expands; a quick upward swipe dismisses.
        var downY = 0f
        card.setOnTouchListener { v, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> downY = event.rawY
                MotionEvent.ACTION_UP -> {
                    if (downY - event.rawY > dp(app, 40)) dismiss() else v.performClick()
                }
            }
            true
        }
        card.setOnClickListener { if (!expanded) expand(app) }
        // Only reachable once expanded (collapsed, the window is just the card): the dimmed
        // area around the card closes it, like a dialog.
        view.setOnClickListener { if (expanded) dismiss() }
        view.findViewById<View>(R.id.overlay_close).setOnClickListener { dismiss() }
        view.findViewById<View>(R.id.overlay_open_app).setOnClickListener {
            openApp(app)
            dismiss()
        }
        view.findViewById<View>(R.id.overlay_copy).setOnClickListener { copyMessage(app) }
        view.findViewById<View>(R.id.overlay_open_chat_app).setOnClickListener {
            openChatApp(app)
            dismiss()
        }

        val type =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            // Never takes keyboard focus from the app underneath; touches outside go through.
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
        }
        wm.addView(view, params)
        windowParams = params
        root = view
        return view
    }

    private fun expand(app: Context) {
        val view = root ?: return
        if (expanded) return
        Log.i(TAG, "Popup expanded")
        expanded = true
        main.removeCallbacks(autoHide)
        windowParams?.let { params ->
            params.height = WindowManager.LayoutParams.MATCH_PARENT
            params.flags = params.flags or WindowManager.LayoutParams.FLAG_DIM_BEHIND
            params.dimAmount = 0.5f
            try {
                windowManager?.updateViewLayout(view, params)
            } catch (e: Exception) {
                Log.w(TAG, "Couldn't enlarge the popup window", e)
            }
        }
        // Capped so the message plus the ad still fit on a small screen.
        view.findViewById<TextView>(R.id.overlay_message).maxLines = 8
        view.findViewById<View>(R.id.overlay_hint).visibility = View.GONE
        view.findViewById<View>(R.id.overlay_expanded).visibility = View.VISIBLE
        loadAd(app)
    }

    /**
     * Debug builds only: writes where the popup's ad got to (and why it failed) in a line on
     * the card itself, so it can be diagnosed without logcat. Always logged too.
     */
    private fun adStatus(app: Context, message: String) {
        Log.i(TAG, message)
        if (app.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) return
        val line = root?.findViewById<TextView>(R.id.overlay_ad_debug) ?: return
        line.text = "[debug] $message"
        line.visibility = View.VISIBLE
    }

    private fun loadAd(app: Context) {
        val adUnitId = MonitorPrefs.overlayAdUnitId(app)
        if (adUnitId == null) {
            // Saved by AdsService (Flutter) on app start; missing until the app has been opened
            // once, or when the config switches the popup ad off.
            adStatus(app, "No ad: no ad unit saved (open the app once, or showOverlayNative is off)")
            return
        }
        val container = root?.findViewById<FrameLayout>(R.id.overlay_ad_container) ?: return
        adStatus(app, "Loading ad: $adUnitId")
        try {
            MobileAds.initialize(app) {}
            AdLoader.Builder(app, adUnitId)
                .forNativeAd { ad ->
                    // Dismissed (or collapsed) while it was loading.
                    if (root == null || !expanded) {
                        Log.i(TAG, "Popup native ad loaded after the popup closed; discarded")
                        ad.destroy()
                        return@forNativeAd
                    }
                    adStatus(app, "Ad loaded: ${ad.headline}")
                    nativeAd?.destroy()
                    nativeAd = ad
                    bindAd(app, container, ad)
                }
                .withAdListener(object : AdListener() {
                    override fun onAdFailedToLoad(error: LoadAdError) {
                        adStatus(app, "Ad failed: code ${error.code} - ${error.message}")
                    }
                })
                .withNativeAdOptions(
                    NativeAdOptions.Builder()
                        .setAdChoicesPlacement(NativeAdOptions.ADCHOICES_TOP_RIGHT)
                        .build()
                )
                .build()
                .loadAd(AdRequest.Builder().build())
        } catch (e: Exception) {
            Log.w(TAG, "Popup native ad load threw", e)
            adStatus(app, "Ad load threw: ${e.javaClass.simpleName}: ${e.message}")
        }
    }

    @SuppressLint("InflateParams")
    private fun bindAd(app: Context, container: ViewGroup, ad: NativeAd) {
        val adView = LayoutInflater.from(app).inflate(R.layout.overlay_native_ad, null) as NativeAdView
        val headline = adView.findViewById<TextView>(R.id.ad_headline)
        val body = adView.findViewById<TextView>(R.id.ad_body)
        val icon = adView.findViewById<ImageView>(R.id.ad_icon)
        val media = adView.findViewById<MediaView>(R.id.ad_media)
        val cta = adView.findViewById<TextView>(R.id.ad_call_to_action)

        headline.text = ad.headline
        adView.headlineView = headline

        body.text = ad.body
        body.visibility = if (ad.body.isNullOrBlank()) View.GONE else View.VISIBLE
        adView.bodyView = body

        val adIcon = ad.icon
        if (adIcon != null) {
            icon.setImageDrawable(adIcon.drawable)
            icon.visibility = View.VISIBLE
        } else {
            icon.visibility = View.GONE
        }
        adView.iconView = icon

        val mediaContent = ad.mediaContent
        if (mediaContent != null) {
            media.mediaContent = mediaContent
            media.visibility = View.VISIBLE
        } else {
            media.visibility = View.GONE
        }
        adView.mediaView = media

        cta.text = ad.callToAction
        cta.visibility = if (ad.callToAction.isNullOrBlank()) View.GONE else View.VISIBLE
        adView.callToActionView = cta

        adView.setNativeAd(ad)
        container.removeAllViews()
        container.addView(adView)
        container.visibility = View.VISIBLE
        container.post {
            adStatus(app, "Ad shown (${container.width}x${container.height}px)")
        }
    }

    /** Same entry as tapping a deleted-message notification: the app's Deleted tab. */
    private fun openApp(app: Context) {
        val intent = Intent(app, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(AlertNotifier.EXTRA_OPEN_TARGET, AlertNotifier.TARGET_DELETED)
        }
        try {
            app.startActivity(intent)
        } catch (e: Exception) {
            Log.w(TAG, "Couldn't open the app from the popup", e)
        }
    }

    private fun dp(context: Context, value: Int): Float =
        value * context.resources.displayMetrics.density
}
