import 'package:preload_google_ads/preload_google_ads.dart';

/// Typed shape of the `ads_config` Firebase Remote Config JSON blob (see
/// [AdsService]) -- every field's fallback rule (and its type) lives here
/// in one place, instead of AdsService poking at a raw
/// `Map<String, dynamic>` inline.
class AdRemoteConfig {
  final bool showAd;
  final bool showBanner;
  final bool showInterstitial;
  final bool showNative;
  final bool showOpenApp;
  final bool showRewarded;
  final bool showRewardedInterstitial;
  final bool showSplashAd;
  final int nativeCounter;
  final int interstitialCounter;

  // Nullable, with no literal default and no test-id fallback -- a missing
  // id means that ad format simply doesn't load, see [toAdFlag]/[toAdIDS].
  final String? appOpenId;
  final String? bannerId;
  final String? nativeId;
  final String? interstitialId;
  final String? rewardedId;
  final String? rewardedInterstitialId;

  const AdRemoteConfig({
    required this.showAd,
    required this.showBanner,
    required this.showInterstitial,
    required this.showNative,
    required this.showOpenApp,
    required this.showRewarded,
    required this.showRewardedInterstitial,
    required this.showSplashAd,
    required this.nativeCounter,
    required this.interstitialCounter,
    this.appOpenId,
    this.bannerId,
    this.nativeId,
    this.interstitialId,
    this.rewardedId,
    this.rewardedInterstitialId,
  });

  /// Mirrors exactly what used to be hardcoded in AdsService before Remote
  /// Config was wired in. Used both as AdsService's own fallback whenever
  /// Remote Config can't be reached at all, and field-by-field inside
  /// [fromJson] whenever the fetched JSON is missing a key or has the
  /// wrong type -- so a bad or partial value published in the console
  /// degrades one field at a time instead of breaking ad init entirely.
  static const defaults = AdRemoteConfig(
    showAd: true,
    showBanner: false,
    showInterstitial: true,
    showNative: true,
    showOpenApp: true,
    showRewarded: false,
    showRewardedInterstitial: true,
    showSplashAd: true,
    nativeCounter: 0,
    interstitialCounter: 5,
  );

  /// Parses Remote Config's fetched JSON, falling back to [fallback]
  /// field-by-field for anything missing or the wrong type.
  factory AdRemoteConfig.fromJson(
    Map<String, dynamic> json, {
    required AdRemoteConfig fallback,
  }) {
    bool boolOr(String key, bool fallbackValue) {
      final value = json[key];
      return value is bool ? value : fallbackValue;
    }

    int intOr(String key, int fallbackValue) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return fallbackValue;
    }

    String? stringOrNull(String key) {
      final value = json[key];
      return (value is String && value.isNotEmpty) ? value : null;
    }

    return AdRemoteConfig(
      showAd: boolOr('showAd', fallback.showAd),
      showBanner: boolOr('showBanner', fallback.showBanner),
      showInterstitial: boolOr('showInterstitial', fallback.showInterstitial),
      showNative: boolOr('showNative', fallback.showNative),
      showOpenApp: boolOr('showOpenApp', fallback.showOpenApp),
      showRewarded: boolOr('showRewarded', fallback.showRewarded),
      showRewardedInterstitial: boolOr(
        'showRewardedInterstitial',
        fallback.showRewardedInterstitial,
      ),
      showSplashAd: boolOr('showSplashAd', fallback.showSplashAd),
      nativeCounter: intOr('nativeCounter', fallback.nativeCounter),
      interstitialCounter: intOr(
        'interstitialCounter',
        fallback.interstitialCounter,
      ),
      appOpenId: stringOrNull('appOpenId') ?? fallback.appOpenId,
      bannerId: stringOrNull('bannerId') ?? fallback.bannerId,
      nativeId: stringOrNull('nativeId') ?? fallback.nativeId,
      interstitialId:
          stringOrNull('interstitialId') ?? fallback.interstitialId,
      rewardedId: stringOrNull('rewardedId') ?? fallback.rewardedId,
      rewardedInterstitialId: stringOrNull('rewardedInterstitialId') ??
          fallback.rewardedInterstitialId,
    );
  }

  /// Same flags and counters, but with Google's official test ad unit ids
  /// in every slot -- used in debug builds so development never requests
  /// (or gets counted against) the real ad units. Every slot gets an id, so
  /// which formats are actually on is decided purely by the show* flags.
  AdRemoteConfig withTestIds() => AdRemoteConfig(
        showAd: showAd,
        showBanner: showBanner,
        showInterstitial: showInterstitial,
        showNative: showNative,
        showOpenApp: showOpenApp,
        showRewarded: showRewarded,
        showRewardedInterstitial: showRewardedInterstitial,
        showSplashAd: showSplashAd,
        nativeCounter: nativeCounter,
        interstitialCounter: interstitialCounter,
        appOpenId: AdTestIds.appOpen,
        bannerId: AdTestIds.banner,
        nativeId: AdTestIds.native,
        interstitialId: AdTestIds.interstitial,
        rewardedId: AdTestIds.rewarded,
        rewardedInterstitialId: AdTestIds.rewardedInterstitial,
      );

  /// Serializes back to the same shape [fromJson] reads -- used to seed
  /// Remote Config's own pre-fetch default (see AdsService) from
  /// [defaults], so that literal JSON only has to be written once.
  Map<String, dynamic> toJson() => {
        'showAd': showAd,
        'showBanner': showBanner,
        'showInterstitial': showInterstitial,
        'showNative': showNative,
        'showOpenApp': showOpenApp,
        'showRewarded': showRewarded,
        'showRewardedInterstitial': showRewardedInterstitial,
        'showSplashAd': showSplashAd,
        'nativeCounter': nativeCounter,
        'interstitialCounter': interstitialCounter,
        if (appOpenId != null) 'appOpenId': appOpenId,
        if (bannerId != null) 'bannerId': bannerId,
        if (nativeId != null) 'nativeId': nativeId,
        if (interstitialId != null) 'interstitialId': interstitialId,
        if (rewardedId != null) 'rewardedId': rewardedId,
        if (rewardedInterstitialId != null)
          'rewardedInterstitialId': rewardedInterstitialId,
      };

  /// A format stays off if it has no configured ad unit id, regardless of
  /// its own show* flag -- otherwise the package's own lower-level fallback
  /// (unitIDAppOpen/unitIDBanner/etc. in preload_google_ads) would silently
  /// substitute a test ad unit id and load/show a real ad slot with fake
  /// (test) content instead of just not loading it. "Enabled with no id"
  /// must mean "off," never "test ad."
  AdFlag toAdFlag() => AdFlag(
        showAd: showAd,
        showBanner: showBanner && bannerId != null,
        // Interstitial and rewarded interstitial use the package's on-demand
        // classes (see AdsService) so they load when needed -- turned off
        // here so the package's own loaders never preload them.
        showInterstitial: false,
        showNative: showNative && nativeId != null,
        // App open also uses the package's on-demand class (see AdsService),
        // so both of its package-side triggers stay off.
        showOpenApp: false,
        showRewarded: showRewarded && rewardedId != null,
        showRewardedInterstitial: false,
        showSplashAd: false,
      );

  /// Whether the app's own interstitial (see AdsService) should run: same
  /// "no id means off" rule as [toAdFlag].
  bool get interstitialEnabled =>
      showAd && showInterstitial && interstitialId != null;

  /// Whether an app open ad should be requested on a cold start (the old
  /// "splash" ad): same "no id means off" rule as [toAdFlag].
  bool get appOpenOnLaunchEnabled =>
      showAd && showSplashAd && appOpenId != null;

  /// Whether an app open ad should be requested every time the app returns
  /// from the background.
  bool get appOpenOnResumeEnabled =>
      showAd && showOpenApp && appOpenId != null;

  /// Whether the app's own on-demand rewarded interstitial should run.
  bool get rewardedInterstitialEnabled =>
      showAd && showRewardedInterstitial && rewardedInterstitialId != null;

  AdCounter toAdCounter() => AdCounter(
        nativeCounter: nativeCounter,
        interstitialCounter: interstitialCounter,
      );

  /// Passed through as-is, including null -- never substitutes a test id
  /// for a missing one. A null id here is harmless on its own: [toAdFlag]
  /// already turns off whichever format it belongs to, so the package
  /// never actually tries to load with it.
  AdIDS toAdIDS() => AdIDS(
        appOpenId: appOpenId,
        bannerId: bannerId,
        nativeId: nativeId,
        interstitialId: interstitialId,
        rewardedId: rewardedId,
        rewardedInterstitialId: rewardedInterstitialId,
      );
}
