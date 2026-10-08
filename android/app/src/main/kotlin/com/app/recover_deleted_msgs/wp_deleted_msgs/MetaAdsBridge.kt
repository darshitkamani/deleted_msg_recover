package com.app.recover_deleted_msgs.wp_deleted_msgs

import android.app.Activity
import android.util.Log
import com.facebook.ads.Ad
import com.facebook.ads.AdError
import com.facebook.ads.AdListener
import com.facebook.ads.AdSettings
import com.facebook.ads.AdSize
import com.facebook.ads.AdView
import com.facebook.ads.AudienceNetworkAds
import com.facebook.ads.InterstitialAd
import com.facebook.ads.InterstitialAdListener
import com.facebook.ads.NativeAd
import com.facebook.ads.NativeAdBase
import com.facebook.ads.NativeAdListener
import com.facebook.ads.NativeBannerAd
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

private const val TAG = "MetaAds"
private const val META_CHANNEL = "recover/meta_ads"
const val META_NATIVE_VIEW_TYPE = "recover/meta_native"
const val META_BANNER_VIEW_TYPE = "recover/meta_banner"
private const val TEST_AD_TYPE = "IMG_16_9_APP_INSTALL"

/**
 * Meta Audience Network, driven from Dart (lib/core/ads/meta_ads_bridge.dart).
 *
 * Every load call answers only once the ad has actually loaded -- with an id the
 * Dart side hands back to show/destroy it (or to a platform view, for native and
 * banner) -- or with an error, which is Dart's cue to fall back to AdMob for that
 * slot. Loaded ads are held here until Dart calls `destroy`, so their lifetime
 * follows the Flutter widget/controller that asked for them, not the platform view.
 *
 * Created per activity (see MainActivity) so ads get an Activity context, which
 * Meta needs for click-through and the interstitial's own activity.
 */
class MetaAdsBridge(private val activity: Activity, flutterEngine: FlutterEngine) {

    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, META_CHANNEL)
    private val nativeAds = HashMap<String, NativeAdBase>()
    private val bannerAds = HashMap<String, AdView>()
    private val interstitials = HashMap<String, InterstitialAd>()
    private var nextId = 0
    private var testMode = false

    init {
        channel.setMethodCallHandler(::onMethodCall)
        val registry = flutterEngine.platformViewsController.registry
        registry.registerViewFactory(META_NATIVE_VIEW_TYPE, MetaNativeAdViewFactory(::nativeAd))
        registry.registerViewFactory(META_BANNER_VIEW_TYPE, MetaBannerAdViewFactory(::bannerAd))
    }

    fun nativeAd(id: String): NativeAdBase? = nativeAds[id]

    fun bannerAd(id: String): AdView? = bannerAds[id]

    private fun newId(prefix: String) = "$prefix-${nextId++}"

    /** Impressions and clicks, for the Meta Ad Lab overlay (lib/core/ads/meta_ad_lab.dart).
     * [format] matches the Dart MetaAdFormat enum's names. */
    private fun report(format: String, event: String) {
        channel.invokeMethod("adEvent", mapOf("format" to format, "event" to event))
    }

    /** In test mode every placement id gets Meta's `TEST_AD_TYPE#` prefix, which makes
     * it serve a test creative (a 16:9 image app-install ad, valid for banner, medium
     * rectangle, interstitial and native) on the real placement. Test mode is only
     * ever on in debug builds (AdsService), so release can never ship the prefix. */
    private fun placement(id: String) =
        if (testMode && !id.contains('#')) "$TEST_AD_TYPE#$id" else id

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "initialize" -> initialize(call.argument<Boolean>("testMode") == true, result)
                "loadNative" -> loadNative(
                    call.argument<String>("placementId")!!,
                    call.argument<Boolean>("small") == true,
                    result,
                )
                "loadBanner" -> loadBanner(
                    call.argument<String>("placementId")!!,
                    call.argument<Boolean>("mediumRectangle") == true,
                    result,
                )
                "loadInterstitial" -> loadInterstitial(call.argument<String>("placementId")!!, result)
                "showInterstitial" -> result.success(showInterstitial(call.argument<String>("id")!!))
                "destroy" -> {
                    destroy(call.argument<String>("id")!!)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.e(TAG, "${call.method} failed", e)
            result.error("META_ADS", e.message, null)
        }
    }

    /** Test mode serves Meta's test creatives on the real placement ids -- Meta has
     * no shared test placement ids the way AdMob has test ad unit ids. */
    private fun initialize(testMode: Boolean, result: MethodChannel.Result) {
        this.testMode = testMode
        AdSettings.setTestMode(testMode)
        // Integration mistakes come back through onError -- and so fall back to
        // AdMob -- instead of crashing debug builds.
        AdSettings.setIntegrationErrorMode(AdSettings.IntegrationErrorMode.INTEGRATION_ERROR_CALLBACK_MODE)
        if (AudienceNetworkAds.isInitialized(activity)) {
            result.success(true)
            return
        }
        AudienceNetworkAds.buildInitSettings(activity.applicationContext)
            .withInitListener { initResult ->
                if (!initResult.isSuccess) Log.w(TAG, "init failed: ${initResult.message}")
                activity.runOnUiThread { result.success(initResult.isSuccess) }
            }
            .initialize()
    }

    /** Medium slots use a NativeAd (needs a MediaView); small slots a NativeBannerAd,
     * Meta's format for layouts with no media -- each is its own placement type. */
    private fun loadNative(placementId: String, small: Boolean, result: MethodChannel.Result) {
        val ad: NativeAdBase = if (small) {
            NativeBannerAd(activity, placement(placementId))
        } else {
            NativeAd(activity, placement(placementId))
        }
        val id = newId("native")
        val format = if (small) "nativeBanner" else "native"
        val listener = object : NativeAdListener {
            override fun onAdLoaded(loaded: Ad) {
                nativeAds[id] = ad
                result.success(id)
            }

            override fun onError(failed: Ad?, error: AdError) {
                Log.w(TAG, "native load failed (${error.errorCode}): ${error.errorMessage}")
                ad.destroy()
                result.error("LOAD_FAILED", error.errorMessage, error.errorCode)
            }

            override fun onMediaDownloaded(ad: Ad) {}
            override fun onAdClicked(ad: Ad) = report(format, "click")
            override fun onLoggingImpression(ad: Ad) = report(format, "impression")
        }
        when (ad) {
            is NativeAd -> ad.loadAd(ad.buildLoadAdConfig().withAdListener(listener).build())
            is NativeBannerAd -> ad.loadAd(ad.buildLoadAdConfig().withAdListener(listener).build())
        }
    }

    /** [mediumRectangle] requests a 300x250 (RECTANGLE_HEIGHT_250) ad, otherwise a
     * 50dp-tall banner -- it must match the placement's type in Monetization Manager. */
    private fun loadBanner(placementId: String, mediumRectangle: Boolean, result: MethodChannel.Result) {
        val size = if (mediumRectangle) AdSize.RECTANGLE_HEIGHT_250 else AdSize.BANNER_HEIGHT_50
        val ad = AdView(activity, placement(placementId), size)
        val id = newId("banner")
        val format = if (mediumRectangle) "mediumRectangle" else "banner"
        val listener = object : AdListener {
            override fun onAdLoaded(loaded: Ad) {
                bannerAds[id] = ad
                result.success(id)
            }

            override fun onError(failed: Ad?, error: AdError) {
                Log.w(TAG, "banner load failed (${error.errorCode}): ${error.errorMessage}")
                ad.destroy()
                result.error("LOAD_FAILED", error.errorMessage, error.errorCode)
            }

            override fun onAdClicked(ad: Ad) = report(format, "click")
            override fun onLoggingImpression(ad: Ad) = report(format, "impression")
        }
        ad.loadAd(ad.buildLoadAdConfig().withAdListener(listener).build())
    }

    private fun loadInterstitial(placementId: String, result: MethodChannel.Result) {
        val ad = InterstitialAd(activity, placement(placementId))
        val id = newId("interstitial")
        // The listener outlives the load: it also reports the dismissal of a
        // later show, which is how Dart learns the ad is off screen.
        var answered = false
        val listener = object : InterstitialAdListener {
            override fun onAdLoaded(loaded: Ad) {
                interstitials[id] = ad
                answered = true
                result.success(id)
            }

            override fun onError(failed: Ad?, error: AdError) {
                Log.w(TAG, "interstitial failed (${error.errorCode}): ${error.errorMessage}")
                if (!answered) {
                    answered = true
                    ad.destroy()
                    result.error("LOAD_FAILED", error.errorMessage, error.errorCode)
                } else {
                    // Failed while showing: treat it like a dismissal so Dart unblocks.
                    onInterstitialDismissed(ad)
                }
            }

            override fun onInterstitialDisplayed(ad: Ad) {}

            override fun onInterstitialDismissed(dismissed: Ad) {
                destroy(id)
                channel.invokeMethod("interstitialDismissed", mapOf("id" to id))
            }

            override fun onAdClicked(ad: Ad) = report("interstitial", "click")
            override fun onLoggingImpression(ad: Ad) = report("interstitial", "impression")
        }
        ad.loadAd(ad.buildLoadAdConfig().withAdListener(listener).build())
    }

    /** False when the ad is gone or expired (Meta invalidates loaded ads after about
     * an hour); Dart then treats it as never shown. */
    private fun showInterstitial(id: String): Boolean {
        val ad = interstitials[id] ?: return false
        if (!ad.isAdLoaded || ad.isAdInvalidated) {
            destroy(id)
            return false
        }
        return ad.show()
    }

    private fun destroy(id: String) {
        nativeAds.remove(id)?.destroy()
        bannerAds.remove(id)?.destroy()
        interstitials.remove(id)?.destroy()
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        nativeAds.values.forEach { it.destroy() }
        bannerAds.values.forEach { it.destroy() }
        interstitials.values.forEach { it.destroy() }
        nativeAds.clear()
        bannerAds.clear()
        interstitials.clear()
    }
}
