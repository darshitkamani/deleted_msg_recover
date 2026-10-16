import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:preload_google_ads/preload_google_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/ad_loading_dialog.dart';
import '../native_bridge.dart';
import 'ad_lab_settings.dart';
import 'ad_remote_config.dart';
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
  OnDemandInterstitialAd? _interstitial;
  OnDemandRewardedInterstitialAd? _rewardedInterstitial;

  /// Ad unit for the interstitial shown on opening a chat (see
  /// [showInterstitialThen]); null until [init], or if it's switched off
  /// (`showChatInterstitial` in the config).
  String? _chatInterstitialId;

  /// Shows that ad on every this-many'th chat opened
  /// (`chatInterstitialCounter` in the config), counted in
  /// [_chatOpensSinceAd].
  int _chatInterstitialEvery = 1;
  int _chatOpensSinceAd = 0;

  /// Guards [showInterstitialThen] against a second tap while one is already
  /// loading or showing.
  bool _chatInterstitialBusy = false;

  /// How long opening a chat waits for its interstitial before just opening.
  static const _chatInterstitialTimeout = Duration(seconds: 6);

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

  /// Failed native loads allowed per app session (retries included) before
  /// the package stops native ads until the next cold start -- see
  /// [AdConfigData.nativeMaxFailuresPerSession].
  static const _nativeMaxFailuresPerSession = 3;

  Future<void> init() {
    return _initFuture ??= _initialize();
  }

  /// How long [init] waits for a fresh config download when there's a copy
  /// saved from an earlier launch to fall back on. Longer than that and the
  /// saved copy is used (the download still finishes and is saved for next
  /// time), so a slow network doesn't push the cold-start app open ad past
  /// its window.
  static const _freshConfigWait = Duration(seconds: 2);

  /// The app open ad shown on returning to the app -- see [_onAppState].
  OnDemandAppOpenAd? _appOpen;
  StreamSubscription<AppState>? _appStateSub;
  DateTime? _backgroundedAt;
  DateTime? _lastAppOpenAt;
  int _appOpenMinBackground = 0;
  int _appOpenCooldown = 0;

  Future<void> _initialize() async {
    final fetched = await _fetchAdConfig();

    print("fetched ${fetched.toJson()}");
    // Debug builds keep the fetched flags and counters but never its ad
    // unit ids -- those are always Google's test ids, so development can't
    // hit the real ad units.
    final config = kDebugMode ? fetched.withTestIds() : fetched;
    // Turns the ad lab overlays on for a live release build
    // without an update -- unless they've been set by hand from the hidden
    // ad lab dialog (see AdLabSettings).
    AdLabSettings.instance.applyRemoteFlag(config.showAdMetricsLab);
    // Handed to the native deleted-message popup, which shows without
    // Flutter running and so can't ask for it then.
    debugPrint('Overlay ad unit: ${config.overlayNativeAdUnitId}');
    unawaited(
      NativeBridge.setOverlayConfig(
        adUnitId: config.overlayNativeAdUnitId,
        autoExpand: config.overlayAutoExpand,
        autoExpandIntervalSeconds: config.overlayAutoExpandIntervalSeconds,
      ).catchError((Object e) => debugPrint('Overlay config: $e')),
    );

    // The cold-start app open ad is requested first -- before the SDK set-up
    // below and before any native ad -- because it's the one racing a
    // timeout: the first ad request of a fresh process is the slowest (the
    // SDK loads its code module then). Not awaited: nothing waits on the
    // ad; if it misses the timeout it's kept and shown on the next resume.
    final OnDemandAppOpenAd? appOpen =
        config.appOpenOnLaunchEnabled || config.appOpenOnResumeEnabled
        ? OnDemandAppOpenAd(adUnitId: config.appOpenId!)
        : null;
    if (appOpen != null && config.appOpenOnLaunchEnabled) {
      unawaited(
        appOpen.loadAndShow(
          timeout: Duration(seconds: config.appOpenTimeoutSeconds),
        ),
      );
    }

    await PreloadGoogleAds.instance.initialize(
      adConfigData: AdConfigData(
        adFlag: config.toAdFlag(),
        adIDs: config.toAdIDS(),
        adCounter: config.toAdCounter(),
        nativeRetryLimit: _nativeRetryLimit,
        enableNativeFailureLimit: true,
        nativeMaxFailuresPerSession: _nativeMaxFailuresPerSession,
        nativeADLayout: _nativeAdLayout(),
      ),
    );

    if (config.chatInterstitialEnabled) {
      _chatInterstitialId = config.interstitialId;
      _chatInterstitialEvery = config.chatInterstitialCounter < 1
          ? 1
          : config.chatInterstitialCounter;
    }
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
    // Returns from the background, requested at that moment -- but not on
    // every one (see [_onAppState]). Not the package's own startListening(),
    // which requests one on every single return, even after a few seconds
    // in the share sheet or a settings screen.
    if (appOpen != null && config.appOpenOnResumeEnabled) {
      _appOpen = appOpen;
      _appOpenMinBackground = config.appOpenMinBackgroundSeconds;
      _appOpenCooldown = config.appOpenCooldownSeconds;
      // The cold-start ad counts toward the cooldown too.
      if (config.appOpenOnLaunchEnabled) _lastAppOpenAt = DateTime.now();
      AppStateEventNotifier.startListening();
      _appStateSub ??= AppStateEventNotifier.appStateStream.listen(
        _onAppState,
      );
    }
  }

  /// Shows the app open ad on returning to the app, only when the user was
  /// actually away -- at least `appOpenMinBackgroundSeconds` in the
  /// background (so popping out to the share sheet, a permission screen or
  /// WhatsApp and straight back doesn't count) -- and at most once per
  /// `appOpenCooldownSeconds`, counting the cold-start one. A request in
  /// flight is never doubled up: [OnDemandAppOpenAd.loadAndShow] ignores
  /// calls while busy, and reuses an ad that arrived too late last time.
  void _onAppState(AppState state) {
    final now = DateTime.now();
    if (state == AppState.background) {
      _backgroundedAt = now;
      return;
    }
    final appOpen = _appOpen;
    final leftAt = _backgroundedAt;
    _backgroundedAt = null;
    if (appOpen == null || leftAt == null) return;
    if (now.difference(leftAt).inSeconds < _appOpenMinBackground) return;
    final last = _lastAppOpenAt;
    if (last != null && now.difference(last).inSeconds < _appOpenCooldown) {
      return;
    }
    if (appOpen.isBusy) return;
    _lastAppOpenAt = now;
    appOpen.loadAndShow();
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
  /// Every launch asks the server, and an edit to the file is normally
  /// picked up on the very next launch. But with a copy saved from an
  /// earlier launch, the download only gets [_freshConfigWait]: slower than
  /// that and the saved copy is used for this launch, while the download
  /// carries on and saves itself for the next one. A brand-new install, with
  /// nothing saved, waits for the download in full. A fetch that fails (no
  /// network, timeout, bad response, invalid JSON) never replaces the saved
  /// copy; only with nothing at all does it fall back to
  /// [AdRemoteConfig.defaults] entirely, and field-by-field via
  /// [AdRemoteConfig.fromJson] otherwise. Ad behavior must never depend on
  /// the server actually being reachable.
  Future<AdRemoteConfig> _fetchAdConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_adConfigCacheKey);
      final download = _downloadAdConfig().then((raw) async {
        if (raw != null) await prefs.setString(_adConfigCacheKey, raw);
        return raw;
      });
      final String? raw;
      if (saved == null) {
        raw = await download;
      } else {
        raw =
            await download.timeout(_freshConfigWait, onTimeout: () => null) ??
            saved;
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
      // Non-breaking spaces (U+00A0), which copying JSON out of a web page
      // or chat tends to leave as indentation, aren't valid JSON whitespace.
      final body = (await response
              .transform(utf8.decoder)
              .join()
              .timeout(const Duration(seconds: 10)))
          .replaceAll(' ', ' ');
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

  /// Shows the rewarded interstitial right now, then runs [then] once it's
  /// dismissed. Nothing is preloaded, so the user waits behind a loading
  /// dialog (see [showAdLoadingDialog]) while it loads; if the format is off,
  /// fails or takes too long, [then] just runs straight away -- used to gate a
  /// status download/share behind an ad view without ever blocking the action
  /// itself.
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

  /// Shows an interstitial right now, then runs [then] once it's dismissed --
  /// used on every chat tile tap, with [then] opening the chat; the ad only
  /// comes on every `chatInterstitialCounter`th tap, the others just open.
  /// Requested on the spot behind a loading dialog; if it's switched off, or
  /// the ad fails or takes longer than [_chatInterstitialTimeout], [then]
  /// runs straight away, so the chat always opens.
  ///
  /// A shown ad also restarts the every-Nth-navigation interstitial's count
  /// ([showInterstitialOnNavigation]), so the two don't land back to back.
  Future<void> showInterstitialThen(
    BuildContext context,
    VoidCallback then,
  ) async {
    final adUnitId = _chatInterstitialId;
    if (adUnitId == null) {
      then();
      return;
    }
    if (_chatInterstitialBusy) return;
    _chatOpensSinceAd++;
    if (_chatOpensSinceAd < _chatInterstitialEvery) {
      then();
      return;
    }
    _chatInterstitialBusy = true;
    try {
      final navigator = Navigator.of(context, rootNavigator: true);
      showAdLoadingDialog(context, action: AdLoadingAction.openChat);
      final ad = await _loadInterstitial(adUnitId);
      navigator.pop();

      if (ad != null) {
        await _showInterstitial(ad);
        _chatOpensSinceAd = 0;
        _interstitial?.reset();
      }
    } finally {
      _chatInterstitialBusy = false;
    }
    then();
  }

  /// Loads one interstitial, or null if it fails or misses the timeout (an
  /// ad arriving after that is discarded). Counted in the Ad Metrics Lab's
  /// interstitial row like the navigation one.
  Future<InterstitialAd?> _loadInterstitial(String adUnitId) {
    final completer = Completer<InterstitialAd?>();
    final timer = Timer(_chatInterstitialTimeout, () {
      if (!completer.isCompleted) completer.complete(null);
    });
    final stats = AdStats.instance;
    stats.interReq.value++;
    try {
      InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            stats.recordLoadSource(ad);
            stats.interLoad.value++;
            if (completer.isCompleted) {
              ad.dispose();
              return;
            }
            timer.cancel();
            completer.complete(ad);
          },
          onAdFailedToLoad: (error) {
            stats.interFailed.value++;
            debugPrint('Chat interstitial failed to load: $error');
            timer.cancel();
            if (!completer.isCompleted) completer.complete(null);
          },
        ),
      );
    } catch (e) {
      debugPrint('Chat interstitial load threw: $e');
      timer.cancel();
      if (!completer.isCompleted) completer.complete(null);
    }
    return completer.future;
  }

  /// Shows [ad] and completes once it's dismissed (or fails to show).
  Future<void> _showInterstitial(InterstitialAd ad) {
    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdImpression: (_) => AdStats.instance.interImp.value++,
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Chat interstitial failed to show: $error');
        ad.dispose();
        if (!done.isCompleted) done.complete();
      },
    );
    ad.setImmersiveMode(true);
    ad.show();
    return done.future;
  }
}
