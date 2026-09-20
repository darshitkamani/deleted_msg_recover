import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:preload_google_ads/preload_google_ads.dart';

import '../../widgets/ad_loading_dialog.dart';
import 'ad_remote_config.dart';

/// Thin, idempotent wrapper around [PreloadGoogleAds.instance.initialize] --
/// callers just call [init] whenever they know it's safe to; the network
/// round trip only actually happens once per process.
///
/// Triggered by [_RootRouter] (see app.dart): during the splash for a user
/// whose onboarding/app tour is already done, or once the app tour page is
/// shown for a user whose setup is still pending -- either way well before any
/// ad-showing screen is reached, so the SDK and its preloaded native ad are
/// already warm by the time the user lands on HomeShell.
class AdsService {
  AdsService._();

  static final AdsService instance = AdsService._();

  Future<void>? _initFuture;

  /// The interstitial, rewarded interstitial and app open ad, all from the
  /// package's on-demand classes (loaded when needed, not preloaded). Null until [init]
  /// has finished with the fetched config -- and for good if that format is
  /// switched off -- which also makes anything reaching an ad call earlier a
  /// no-op instead of using the package's built-in defaults (Google's *test*
  /// ad unit ids, everything enabled), which would otherwise load a test ad.
  OnDemandInterstitialAd? _interstitial;
  OnDemandRewardedInterstitialAd? _rewardedInterstitial;

  /// Firebase Remote Config key holding this app's ad flags/counters/ad
  /// unit ids as a single JSON object (see [AdRemoteConfig]) -- lets the ad
  /// mix be tuned from the Firebase console without an app update. A
  /// published override doesn't need to repeat every key, only what's
  /// actually being changed -- [AdRemoteConfig.fromJson] fills in anything
  /// missing from [AdRemoteConfig.defaults].
  static const _remoteConfigKey = 'ads_config';

  /// A failed native ad load is retried once, then the loader waits for the
  /// next request (another screen showing a native ad) instead of retrying
  /// on a timer indefinitely -- which is what kept native at ~150 requests
  /// for ~35 impressions.
  static const _nativeRetryLimit = 1;

  Future<void> init() {
    return _initFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    final fetched = await _fetchAdConfig();

    print("fetched ${fetched.toJson()}");
    // Debug builds keep Remote Config's flags and counters but never its ad
    // unit ids -- those are always Google's test ids, so development can't
    // hit the real ad units.
    final config = kDebugMode ? fetched.withTestIds() : fetched;

    await PreloadGoogleAds.instance.initialize(
      adConfigData: AdConfigData(
        adFlag: config.toAdFlag(),
        adIDs: config.toAdIDS(),
        adCounter: config.toAdCounter(),
        nativeRetryLimit: _nativeRetryLimit,
      ),
    );

    if (config.interstitialEnabled) {
      _interstitial = OnDemandInterstitialAd(
        adUnitId: config.interstitialId!,
        interval: config.interstitialCounter,
      );
    }
    if (config.rewardedInterstitialEnabled) {
      _rewardedInterstitial = OnDemandRewardedInterstitialAd(
        adUnitId: config.rewardedInterstitialId!,
      );
    }
    if (config.appOpenOnLaunchEnabled || config.appOpenOnResumeEnabled) {
      final appOpen = OnDemandAppOpenAd(adUnitId: config.appOpenId!);
      // Every return from the background, requested at that moment.
      if (config.appOpenOnResumeEnabled) appOpen.startListening();
      // Once for this cold start. Not awaited: nothing waits on the ad, and
      // it's simply skipped if it doesn't arrive in time.
      if (config.appOpenOnLaunchEnabled) {
        appOpen.loadAndShow(timeout: const Duration(seconds: 6));
      }
    }
  }

  /// Fetches this app's ad config from Firebase Remote Config, parsed into
  /// an [AdRemoteConfig].
  ///
  /// A fetch that fails or is throttled (no network, timeout, Firebase's own
  /// per-device fetch limit -- more likely now that every launch fetches, see
  /// below) is not the end of the road: Remote Config still holds whatever
  /// was last fetched and activated, and that is what's read afterwards. Only
  /// if there is nothing at all -- a brand-new install that never managed a
  /// fetch -- does it fall back to [AdRemoteConfig.defaults] entirely, and
  /// field-by-field via [AdRemoteConfig.fromJson] otherwise. Ad behavior must
  /// never depend on Remote Config actually being reachable.
  Future<AdRemoteConfig> _fetchAdConfig() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          // No fetch throttle: every launch asks the server, so a value just
          // published in the console is picked up on the very next launch.
          // AdsService.init() runs once per launch, so this is one fetch per
          // app start, not a loop.
          minimumFetchInterval: Duration.zero,
        ),
      );
      await remoteConfig.setDefaults({
        _remoteConfigKey: jsonEncode(AdRemoteConfig.defaults.toJson()),
      });
      try {
        await remoteConfig.fetchAndActivate();
      } catch (_) {
        // Keep going with the last activated values, see above.
      }

      final raw = remoteConfig.getString(_remoteConfigKey);
      if (raw.isEmpty) return AdRemoteConfig.defaults;
      return AdRemoteConfig.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
        fallback: AdRemoteConfig.defaults,
      );
    } catch (_) {
      return AdRemoteConfig.defaults;
    }
  }

  /// Reports one screen navigation / tab change to the interstitial, which
  /// loads one step before it's due and shows on every
  /// `interstitialCounter`th one (see [OnDemandInterstitialAd]). A no-op
  /// until [init] has completed.
  void showInterstitialOnNavigation() => _interstitial?.onNavigation();

  /// Requests a rewarded interstitial right now, shows it, then runs [then]
  /// once it's dismissed. Nothing is preloaded, so the user waits behind a
  /// loading dialog (see [showAdLoadingDialog]) while it loads; if it's off,
  /// fails or takes too long, [then] just runs straight away -- used to gate
  /// a status download/share behind an ad view without ever blocking the
  /// action itself.
  Future<void> showRewardedInterThen(
    BuildContext context,
    AdLoadingAction action,
    VoidCallback then,
  ) async {
    final loader = _rewardedInterstitial;
    if (loader == null) {
      then();
      return;
    }

    final navigator = Navigator.of(context, rootNavigator: true);
    showAdLoadingDialog(context, action: action);
    final ad = await loader.load();
    navigator.pop();

    if (ad != null) await loader.show(ad);
    then();
  }
}
