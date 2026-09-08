import 'dart:async';

import 'package:preload_google_ads/preload_google_ads.dart';

/// Thin wrapper around [PreloadGoogleAds] carrying this app's ad
/// configuration -- mirrors the setup used in the SmartLoan EMI Calculator
/// reference project, with test ad unit IDs (swap in real ones before
/// release) and no remote config, since this app has no Firebase project.
///
/// Only [NativeADType.small] is ever requested (see [nativeAd]), so the
/// package's native-ad loader -- which keeps at most one preloaded instance
/// per size -- ends up preloading exactly one native ad for the whole app
/// instead of one per size (small + medium).
class AdsService {
  AdsService._();

  static final AdsService instance = AdsService._();

  Timer? _appOpenRetryTimer;

  Future<void> init() async {
    await PreloadGoogleAds.instance.initialize(
      adConfigData: AdConfigData(
        adFlag: AdFlag(
          showAd: true,
          showNative: true,
          showBanner: true,
          showInterstitial: true,
          showRewardedInterstitial: true,
          showOpenApp: true,
          showRewarded: false,
        ),
        adCounter: AdCounter(
          nativeCounter: 0,
          // Every 2nd call actually shows an interstitial, so switching
          // tabs doesn't throw one up on every single tap.
          interstitialCounter: 2,
          rewardedInterstitialCounter: 0,
        ),
        nativeADLayout: NativeADLayout(
          adLayout: AdLayout.nativeLayout,
          customNativeADStyle: CustomNativeADStyle(buttonBackground: const Color(0xFF009688)),
        ),
      ),
    );
    debugPrint('[Ads] SDK initialized');
    // The native ad is only ever requested later, by NativeAdSlot's own
    // widget. Fetching it here means it's already had a head start on the
    // network request by the time anything tries to display it, instead of
    // only starting that request at the moment it's first shown.
    PreloadGoogleAds.instance.reloadNativeAd(nativeADType: NativeADType.small);
  }

  /// The app's single preloaded native ad slot.
  Widget nativeAd() => PreloadGoogleAds.instance.showNativeAd(nativeADType: NativeADType.small);

  Widget bannerAd() {
    debugPrint('[Ads] banner: requested');
    return PreloadGoogleAds.instance.showBannerAd();
  }

  /// Repeatedly attempts to show the app-open ad, with backoff, since a cold
  /// start's SDK init plus the ad's own network request together often take
  /// longer than any single short delay would account for -- a call this
  /// package makes while the ad is still loading just silently no-ops
  /// (kicking off the load, but not showing anything), and nothing else
  /// would ever call it again.
  ///
  /// Call [stopAppOpenRetry] as soon as a pause/resume cycle is observed
  /// (see HomeShell's WidgetsBindingObserver) -- that's the ad's own
  /// full-screen activity taking over and coming back, so retrying further
  /// would risk popping up a second one on top of the user actually using
  /// the app.
  void showAppOpenAdWhenReady() {
    _appOpenRetryTimer?.cancel();
    const delays = [
      Duration(seconds: 3),
      Duration(seconds: 4),
      Duration(seconds: 5),
      Duration(seconds: 6),
    ];
    var attempt = 0;
    void attemptShow() {
      debugPrint('[Ads] appOpen: attempt ${attempt + 1}');
      PreloadGoogleAds.instance.showOpenApp();
      if (attempt >= delays.length) {
        debugPrint('[Ads] appOpen: giving up after ${attempt + 1} attempts');
        return;
      }
      final delay = delays[attempt];
      attempt++;
      _appOpenRetryTimer = Timer(delay, attemptShow);
    }

    attemptShow();
  }

  void stopAppOpenRetry() {
    _appOpenRetryTimer?.cancel();
    _appOpenRetryTimer = null;
  }

  void showInterstitial(void Function(InterstitialAd? ad, AdError? error) onDone) {
    PreloadGoogleAds.instance.showInterstitialAd(
      callBack: (ad, error) {
        debugPrint('[Ads] interstitial: dismissed=${ad != null} error=$error');
        onDone(ad, error);
      },
    );
  }

  void showRewardedInterstitial({
    required void Function(RewardedInterstitialAd? ad, AdError? error) onDone,
    required void Function(AdWithoutView ad, RewardItem reward) onReward,
  }) {
    PreloadGoogleAds.instance.showRewardedInterstitialAd(callBack: onDone, onReward: onReward);
  }

  /// Shows the rewarded interstitial ad (if one happens to be ready) and
  /// then always runs [action] -- whether or not an ad actually played,
  /// since a share/download the user asked for shouldn't be permanently
  /// blocked by however the ad request happened to go this time.
  void gateWithRewardedInterstitial(VoidCallback action) {
    showRewardedInterstitial(
      onDone: (ad, error) {
        debugPrint('[Ads] rewardedInterstitial: shown=${ad != null} error=$error');
        action();
      },
      onReward: (_, _) => debugPrint('[Ads] rewardedInterstitial: reward earned'),
    );
  }
}
