package com.app.recover_deleted_msgs.wp_deleted_msgs

import android.content.Context
import android.graphics.drawable.GradientDrawable
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import com.facebook.ads.AdOptionsView
import com.facebook.ads.AdView
import com.facebook.ads.MediaView
import com.facebook.ads.NativeAd
import com.facebook.ads.NativeAdBase
import com.facebook.ads.NativeAdLayout
import com.facebook.ads.NativeBannerAd
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Draws a native ad that [MetaAdsBridge] already loaded, looked up by the id Dart
 * passes in the creation params. Styled with the same colors as the AdMob native
 * template (Dart sends them from preload_google_ads' active CustomNativeADStyle), so
 * the two networks look alike in the same slot. The layout fills whatever height the
 * Flutter slot gives it -- the medium template's media view takes up the slack.
 */
class MetaNativeAdViewFactory(
    private val lookup: (String) -> NativeAdBase?,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<Any, Any>()
        val ad = (params["id"] as? String)?.let(lookup)
        return MetaNativeAdPlatformView(context, ad, params)
    }
}

private class MetaNativeAdPlatformView(
    context: Context,
    ad: NativeAdBase?,
    params: Map<*, *>,
) : PlatformView {

    private val root: View = if (ad == null) {
        // Destroyed before the view was created (e.g. the slot was disposed and
        // rebuilt in the same frame) -- an empty view; Dart already moved on.
        FrameLayout(context)
    } else {
        bind(context, ad, params)
    }

    private fun bind(context: Context, ad: NativeAdBase, params: Map<*, *>): View {
        val small = ad is NativeBannerAd
        val layoutRes = if (small) R.layout.meta_native_small else R.layout.meta_native_medium
        val layout = LayoutInflater.from(context).inflate(layoutRes, null) as NativeAdLayout
        val content = layout.findViewById<View>(R.id.meta_ad_content)

        fun color(key: String, fallback: Int) = (params[key] as? Number)?.toInt() ?: fallback
        val density = context.resources.displayMetrics.density

        layout.findViewById<TextView>(R.id.meta_ad_title).apply {
            text = ad.advertiserName
            setTextColor(color("titleColor", 0xFF000000.toInt()))
        }
        layout.findViewById<TextView>(R.id.meta_ad_body).apply {
            // Native banner ads often carry no body; the social context line
            // ("Free", "4.5 ★") stands in for it.
            text = ad.adBodyText?.takeIf { it.isNotBlank() } ?: ad.adSocialContext
            setTextColor(color("bodyColor", 0xFF808080.toInt()))
        }
        layout.findViewById<TextView>(R.id.meta_ad_sponsored).apply {
            text = ad.sponsoredTranslation ?: "Sponsored"
            setTextColor(color("tagForeground", 0xFFFFFFFF.toInt()))
            background = GradientDrawable().apply {
                setColor(color("tagBackground", 0xFFF19938.toInt()))
                cornerRadius = color("tagRadius", 5) * density
            }
        }
        val cta = layout.findViewById<Button>(R.id.meta_ad_cta).apply {
            visibility = if (ad.hasCallToAction()) View.VISIBLE else View.INVISIBLE
            text = ad.adCallToAction
            setTextColor(color("buttonForeground", 0xFFFFFFFF.toInt()))
            background = GradientDrawable().apply {
                setColor(color("buttonBackground", 0xFF2196F3.toInt()))
                cornerRadius = color("buttonRadius", 5) * density
            }
        }
        layout.findViewById<LinearLayout>(R.id.meta_ad_choices)
            .addView(AdOptionsView(context, ad, layout), 0)

        val icon = layout.findViewById<MediaView>(R.id.meta_ad_icon)
        val clickable = listOf<View>(cta, icon, layout.findViewById(R.id.meta_ad_title))
        when (ad) {
            is NativeAd -> ad.registerViewForInteraction(
                content, layout.findViewById<MediaView>(R.id.meta_ad_media), icon, clickable,
            )
            is NativeBannerAd -> ad.registerViewForInteraction(content, icon, clickable)
        }
        return layout
    }

    override fun getView(): View = root

    // The ad itself is destroyed by MetaAdsBridge when Dart calls `destroy`; this
    // only lets go of the view.
    override fun dispose() {
        (root.parent as? ViewGroup)?.removeView(root)
    }
}

/** Hosts a banner [AdView] that [MetaAdsBridge] already loaded. */
class MetaBannerAdViewFactory(
    private val lookup: (String) -> AdView?,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val id = (args as? Map<*, *>)?.get("id") as? String
        val container = FrameLayout(context)
        id?.let(lookup)?.let { banner ->
            (banner.parent as? ViewGroup)?.removeView(banner)
            container.addView(
                banner,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ),
            )
        }
        return object : PlatformView {
            override fun getView(): View = container
            override fun dispose() = container.removeAllViews()
        }
    }
}
