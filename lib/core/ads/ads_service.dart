import 'package:preload_google_ads/preload_google_ads.dart';

/// Thin, idempotent wrapper around [PreloadGoogleAds.instance.initialize] --
/// callers just call [init] whenever they know it's safe to; the network
/// round trip only actually happens once per process.
///
/// Triggered as soon as [_RootRouter] mounts (see app.dart), i.e. right when
/// the splash screen first appears -- well before any ad-showing screen is
/// reached -- so the SDK and its preloaded native ad are already warm by the
/// time the user works through onboarding/app-tour and lands on HomeShell.
class AdsService {
  AdsService._();

  static final AdsService instance = AdsService._();

  Future<void>? _initFuture;

  Future<void> init() {
    return _initFuture ??= PreloadGoogleAds.instance
        .initialize(
          adConfigData: AdConfigData(
            adFlag: AdFlag(
              showAd: true,
              showBanner: true,
              showInterstitial: true,
              showNative: true,
              showOpenApp: true,
              showRewarded: true,
              showRewardedInterstitial: true,
              showSplashAd: true,
            ),
            adIDs: AdIDS(
              appOpenId: AdTestIds.appOpen,
              bannerId: AdTestIds.banner,
              nativeId: AdTestIds.native,
              interstitialId: AdTestIds.interstitial,
              rewardedId: AdTestIds.rewarded,
              rewardedInterstitialId: AdTestIds.rewardedInterstitial,
            ),
            adCounter: AdCounter(nativeCounter: 0, interstitialCounter: 3),
          ),
        )
        .then((_) {});
  }

  /// Shows the preloaded rewarded interstitial ad, then always runs [then]
  /// -- whether the ad actually played (dismissed) or there simply wasn't
  /// one ready to show (its callBack fires immediately in that case, same
  /// as the package's own showInterstitialAd). Used to gate a status
  /// download/share behind an ad view without ever blocking the action
  /// itself when no ad is available.
  void showRewardedInterThen(VoidCallback then) {
    PreloadGoogleAds.instance.showRewardedInterstitialAd(
      callBack: (ad, error) => then(),
      onReward: (ad, reward) {},
    );
  }
}
