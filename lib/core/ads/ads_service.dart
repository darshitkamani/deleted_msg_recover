import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:preload_google_ads/preload_google_ads.dart';

import 'ad_remote_config.dart';

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

  /// True once [PreloadGoogleAds.initialize] has finished with the fetched
  /// config. Until then the package is still on its built-in defaults --
  /// Google's *test* ad unit ids, every format enabled, interstitial counter
  /// 0 -- so anything that reaches an ad call before this flips would load a
  /// test ad and keep it queued even after the real ids arrive.
  bool _ready = false;

  /// Firebase Remote Config key holding this app's ad flags/counters/ad
  /// unit ids as a single JSON object (see [AdRemoteConfig]) -- lets the ad
  /// mix be tuned from the Firebase console without an app update. A
  /// published override doesn't need to repeat every key, only what's
  /// actually being changed -- [AdRemoteConfig.fromJson] fills in anything
  /// missing from [AdRemoteConfig.defaults].
  static const _remoteConfigKey = 'ads_config';

  Future<void> init() {
    return _initFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    final config = await _fetchAdConfig();

    await PreloadGoogleAds.instance.initialize(
      adConfigData: AdConfigData(
        adFlag: config.toAdFlag(),
        adIDs: config.toAdIDS(),
        adCounter: config.toAdCounter(),
      ),
    );
    _ready = true;
  }

  /// Fetches this app's ad config from Firebase Remote Config, parsed into
  /// an [AdRemoteConfig]. Falls back to [AdRemoteConfig.defaults] entirely
  /// if the fetch fails outright (no network, Remote Config down, etc.),
  /// and field-by-field via [AdRemoteConfig.fromJson] otherwise -- ad
  /// behavior must never depend on Remote Config actually being reachable.
  Future<AdRemoteConfig> _fetchAdConfig() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          // Ad behavior isn't something that needs to change minute to
          // minute -- this just keeps a misconfigured or chatty console
          // change from re-fetching (and racing app startup) constantly.
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await remoteConfig.setDefaults({
        _remoteConfigKey: jsonEncode(AdRemoteConfig.defaults.toJson()),
      });
      await remoteConfig.fetchAndActivate();

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

  /// Reports one screen navigation / tab change to the interstitial counter,
  /// showing the ad when the counter says it's due. A no-op until [init] has
  /// completed -- the app's very first route push (fired while Remote Config
  /// is still being fetched) would otherwise make the package load an
  /// interstitial with its default *test* ad unit id; see [_ready].
  void showInterstitialOnNavigation() {
    if (!_ready) return;
    PreloadGoogleAds.instance.showInterstitialAd(callBack: (ad, error) {});
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
