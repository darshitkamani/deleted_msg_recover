import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:preload_google_ads/preload_google_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/ad_loading_dialog.dart';
import 'ad_lab_settings.dart';
import 'ad_remote_config.dart';
import 'meta_ad_stats.dart';
import 'meta_ads_bridge.dart';
import 'meta_first_app_open.dart';
import 'meta_first_interstitial.dart';
import 'native_ad_sizing.dart';

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
  MetaFirstInterstitial? _interstitial;

  /// Meta interstitial placement the rewarded gate tries before the AdMob
  /// rewarded interstitial; null when Meta is off for interstitials.
  String? _rewardedMetaPlacement;

  /// How long the rewarded gate waits for a Meta interstitial before falling
  /// back to the AdMob rewarded interstitial.
  static const _rewardedMetaTimeout = Duration(seconds: 5);
  OnDemandRewardedInterstitialAd? _rewardedInterstitial;

  /// Hosted JSON holding this app's ad flags/counters/ad unit ids as a single
  /// object (see [AdRemoteConfig]) -- lets the ad mix be tuned by editing the
  /// file, without an app update. It doesn't need to repeat every key, only
  /// what's actually being changed -- [AdRemoteConfig.fromJson] fills in
  /// anything missing from [AdRemoteConfig.defaults].
  static final _adConfigUrl = Uri.parse(
    'https://buycenforceonline.us/deleted-message-ads.json',
  );

  /// SharedPreferences key for the last ad config JSON fetched successfully.
  static const _adConfigCacheKey = 'ads_config_cache';

  /// A failed native ad load is retried once, then the loader waits for the
  /// next request (another screen showing a native ad) instead of retrying
  /// on a timer indefinitely -- which is what kept native at ~150 requests
  /// for ~35 impressions.
  static const _nativeRetryLimit = 1;

  final _config = Completer<AdRemoteConfig>();

  /// The ad config [init] settled on (fetched, with test AdMob ids in debug).
  /// Completes only once [init] has run, and never starts it -- so the
  /// Meta-first ad widgets can wait on it without pulling ad loading earlier
  /// than [_RootRouter] means it to happen.
  Future<AdRemoteConfig> get config => _config.future;

  Future<void> init() {
    return _initFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    final fetched = await _fetchAdConfig();

    print("fetched ${fetched.toJson()}");
    // Debug builds keep the fetched flags and counters but never its ad
    // unit ids -- those are always Google's test ids, so development can't
    // hit the real ad units.
    final config = kDebugMode ? fetched.withTestIds() : fetched;
    // Turns the Google/Meta ad lab overlays on for a live release build
    // without an update -- unless they've been set by hand from the hidden
    // ad lab dialog (see AdLabSettings).
    AdLabSettings.instance.applyRemoteFlag(config.showAdMetricsLab);

    // Meta Audience Network is tried before AdMob for every format (see
    // MetaFirstNativeAd / MetaFirstBannerAd / MetaFirstInterstitial /
    // MetaFirstAppOpen and the rewarded gate below) until it hits its no-fill
    // limit. Debug builds use Meta's test mode, since its placement ids can't
    // be swapped for shared test ids like AdMob's.
    MetaAdsBridge.noFillLimit = config.metaNoFillLimit;
    await MetaAdsBridge.initialize(testMode: kDebugMode);
    _config.complete(config);

    await PreloadGoogleAds.instance.initialize(
      adConfigData: AdConfigData(
        adFlag: config.toAdFlag(),
        adIDs: config.toAdIDS(),
        adCounter: config.toAdCounter(),
        nativeRetryLimit: _nativeRetryLimit,
        nativeADLayout: _nativeAdLayout(),
      ),
    );

    if (config.interstitialEnabled) {
      _interstitial = MetaFirstInterstitial(
        metaPlacementId: config.metaInterstitialPlacement,
        googleAdUnitId: config.googleInterstitialId,
        interval: config.interstitialCounter,
      );
    }
    if (config.rewardedInterstitialEnabled) {
      _rewardedMetaPlacement = config.metaInterstitialPlacement;
      final googleId = config.rewardedInterstitialId;
      if (googleId != null) {
        _rewardedInterstitial = OnDemandRewardedInterstitialAd(
          adUnitId: googleId,
        );
      }
    }
    if (config.appOpenOnLaunchEnabled || config.appOpenOnResumeEnabled) {
      final appOpen = MetaFirstAppOpen(
        metaPlacementId: config.metaInterstitialPlacement,
        googleAdUnitId: config.appOpenId,
      );
      // Every return from the background, requested at that moment.
      if (config.appOpenOnResumeEnabled) appOpen.startListening();
      // Once for this cold start. Not awaited: nothing waits on the ad, and
      // it's simply skipped if it doesn't arrive in time.
      if (config.appOpenOnLaunchEnabled) {
        appOpen.loadAndShow(timeout: const Duration(seconds: 6));
      }
    }
  }

  /// Sizes the native ad slots to fit the ad drawn in them -- the package's fixed caps clip the
  /// bottom (the install button) on wider phones and leave a gap on others; see
  /// [NativeAdHeights].
  ///
  /// Must run before the first native ad slot is built, i.e. from `main()`, NOT from [init]:
  /// a slot reads its height once, when it is created, and the home screen shows without
  /// waiting for [init] (which fetches the ad config first). A slot created in that
  /// window would keep the package's default height for good. Until [init] hands the package
  /// its own config, the package falls back to a shared default style -- this sizes that one.
  static void applyNativeAdSizing() {
    _fitNativeSlots(NativeADStyle.instance.customStyle);
  }

  /// The layout [init] passes the package. Sized the same way, so the two never disagree.
  /// Everything else about it (border, padding, margin, colors) is left to the package's own
  /// defaults, which [NativeADLayout] fills in for anything not passed.
  NativeADLayout _nativeAdLayout() {
    final style = CustomNativeADStyle();
    _fitNativeSlots(style);
    return NativeADLayout(customNativeADStyle: style);
  }

  static void _fitNativeSlots(CustomNativeADStyle style) {
    final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
    final smallestWidthDp = view == null
        ? 360.0
        : view.physicalSize.shortestSide / view.devicePixelRatio;
    final heights = NativeAdHeights.forSmallestWidthDp(smallestWidthDp);

    // The style's constructor ignores any constraints it's handed and always uses the
    // package's fixed ones, so they have to be assigned afterwards. Width limits are kept.
    // Min and max are set together: the package's own minimum (210 / 57) would otherwise
    // exceed a maximum that now fits the content exactly.
    style.mediumBoxConstrain = style.mediumBoxConstrain.copyWith(
      minHeight: heights.medium,
      maxHeight: heights.medium,
    );
    style.smallBoxConstrain = style.smallBoxConstrain.copyWith(
      minHeight: heights.small,
      maxHeight: heights.small,
    );
  }

  /// Fetches this app's ad config from [_adConfigUrl], parsed into an
  /// [AdRemoteConfig].
  ///
  /// Every launch asks the server, so an edit to the file is picked up on the
  /// very next launch. A fetch that fails (no network, timeout, bad response,
  /// invalid JSON) is not the end of the road: the last config fetched
  /// successfully is kept on the device and used instead. Only if there is
  /// nothing at all -- a brand-new install that never managed a fetch -- does
  /// it fall back to [AdRemoteConfig.defaults] entirely, and field-by-field
  /// via [AdRemoteConfig.fromJson] otherwise. Ad behavior must never depend on
  /// the server actually being reachable.
  Future<AdRemoteConfig> _fetchAdConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var raw = await _downloadAdConfig();
      if (raw != null) {
        await prefs.setString(_adConfigCacheKey, raw);
      } else {
        raw = prefs.getString(_adConfigCacheKey);
      }
      if (raw == null) return AdRemoteConfig.defaults;
      return AdRemoteConfig.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
        fallback: AdRemoteConfig.defaults,
      );
    } catch (_) {
      return AdRemoteConfig.defaults;
    }
  }

  /// The config file's body, or null if it couldn't be fetched or isn't a
  /// JSON object (so a broken upload never replaces the last good copy).
  Future<String?> _downloadAdConfig() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(_adConfigUrl);
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != HttpStatus.ok) return null;
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 10));
      if (jsonDecode(body) is! Map<String, dynamic>) return null;
      return body;
    } catch (e) {
      debugPrint('Ad config fetch failed: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Reports one screen navigation / tab change to the interstitial, which
  /// loads one step before it's due and shows on every
  /// `interstitialCounter`th one (see [OnDemandInterstitialAd]). A no-op
  /// until [init] has completed.
  void showInterstitialOnNavigation() => _interstitial?.onNavigation();

  /// Shows an ad right now, then runs [then] once it's dismissed: a Meta
  /// interstitial first, the AdMob rewarded interstitial if Meta has nothing.
  /// Nothing is preloaded, so the user waits behind a loading dialog (see
  /// [showAdLoadingDialog]) while it loads; if both are off, fail or take too
  /// long, [then] just runs straight away -- used to gate a status
  /// download/share behind an ad view without ever blocking the action itself.
  Future<void> showRewardedInterThen(
    BuildContext context,
    AdLoadingAction action,
    VoidCallback then,
  ) async {
    final metaPlacement = _rewardedMetaPlacement;
    final loader = _rewardedInterstitial;
    if (metaPlacement == null && loader == null) {
      then();
      return;
    }

    final navigator = Navigator.of(context, rootNavigator: true);
    showAdLoadingDialog(context, action: action);

    if (metaPlacement != null) {
      final id = await MetaAdsBridge.loadInterstitialWithin(
        metaPlacement,
        _rewardedMetaTimeout,
      );
      if (id != null) {
        navigator.pop();
        await MetaAdsBridge.showInterstitial(id);
        then();
        return;
      }
      if (loader != null) {
        MetaAdStats.instance[MetaAdFormat.interstitial].fallbacks.value++;
      }
    }

    final ad = await loader?.load();
    navigator.pop();

    if (ad != null) await loader!.show(ad);
    then();
  }
}
