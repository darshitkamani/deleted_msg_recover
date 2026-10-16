import 'package:preload_google_ads/preload_google_ads.dart';

import 'native_placement.dart';

/// Typed shape of the hosted ad config JSON (see
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

  /// How long the cold-start app open ad may take to arrive before it's
  /// given up on (it's then kept for the next return to the app). At least 1.
  final int appOpenTimeoutSeconds;

  /// Failed interstitial loads (both kinds: every-Nth-navigation and on
  /// opening a chat) allowed per app session before interstitials stop until
  /// the next launch. 0 = no limit.
  final int interstitialMaxFailuresPerSession;

  /// Failed native loads (retries included) allowed per app session before
  /// native ads stop until the next launch. 0 = no limit.
  final int nativeMaxFailuresPerSession;

  /// The app open ad on returning to the app only comes after at least this
  /// long in the background -- not for a quick trip to the share sheet or a
  /// settings screen.
  final int appOpenMinBackgroundSeconds;

  /// At most one app open ad per this many seconds (cold start included).
  final int appOpenCooldownSeconds;

  /// The interstitial shown when a chat tile is tapped (see
  /// AdsService.showInterstitialThen) -- on its own switch, separate from
  /// the every-Nth-navigation one ([showInterstitial]); both use
  /// [interstitialId].
  final bool showChatInterstitial;

  /// The native ad in the deleted-message popup's expanded card (shown over
  /// other apps, see DeletedOverlay.kt); uses [nativeId].
  final bool showOverlayNative;

  /// Per-screen native ad switches, by [NativePlacement.configKey]. A
  /// placement missing from the map is on -- see [showsNativeAt].
  final Map<String, bool> nativePlacements;

  /// Whether the native ad at [placement] should show (on top of the global
  /// [showNative] and [showAd], which still apply).
  bool showsNativeAt(NativePlacement placement) =>
      nativePlacements[placement.configKey] ?? true;

  /// Whether that popup opens fully expanded (message, actions, ad) straight
  /// away instead of as a small card the user taps to expand -- the switch
  /// to turn off if AdMob/Play object to it.
  final bool overlayAutoExpand;

  /// At most one auto-expanded popup per this many seconds; any more within
  /// it start as the small card. Values below 0 are treated as 0.
  final int overlayAutoExpandIntervalSeconds;

  /// Show that ad on every Nth chat opened: 1 = every tap, 2 = every 2nd,
  /// ... Values below 1 are treated as 1.
  final int chatInterstitialCounter;

  /// Shows the floating "Ad Metrics Lab" debug overlay (live load/impression/
  /// failed counters per ad format) on every screen, including release
  /// builds -- gated purely by this remote flag rather than [kDebugMode] so
  /// it can be turned on for a build already in production without a new
  /// release, e.g. to diagnose a fill-rate drop. Defaults to off.
  final bool showAdMetricsLab;

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
    required this.appOpenTimeoutSeconds,
    this.interstitialMaxFailuresPerSession = 5,
    this.nativeMaxFailuresPerSession = 3,
    required this.appOpenMinBackgroundSeconds,
    required this.appOpenCooldownSeconds,
    required this.showChatInterstitial,
    required this.chatInterstitialCounter,
    required this.showOverlayNative,
    this.nativePlacements = const {},
    required this.overlayAutoExpand,
    required this.overlayAutoExpandIntervalSeconds,
    this.appOpenId,
    this.bannerId,
    this.nativeId,
    this.interstitialId,
    this.rewardedId,
    this.rewardedInterstitialId,
    this.showAdMetricsLab = false,
  });

  /// Mirrors exactly what used to be hardcoded in AdsService before Remote
  /// Config was wired in. Used both as AdsService's own fallback whenever
  /// the config file has never been fetched, and field-by-field inside
  /// [fromJson] whenever the fetched JSON is missing a key or has the
  /// wrong type -- so a bad or partial value published in the file
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
    appOpenTimeoutSeconds: 8,
    appOpenMinBackgroundSeconds: 30,
    appOpenCooldownSeconds: 120,
    showChatInterstitial: true,
    chatInterstitialCounter: 1,
    showOverlayNative: true,
    overlayAutoExpand: true,
    overlayAutoExpandIntervalSeconds: 180,
    showAdMetricsLab: false,
  );

  /// Parses the fetched config JSON, falling back to [fallback]
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
      appOpenTimeoutSeconds: intOr(
        'appOpenTimeoutSeconds',
        fallback.appOpenTimeoutSeconds,
      ).clamp(1, 30),
      interstitialMaxFailuresPerSession: intOr(
        'interstitialMaxFailuresPerSession',
        fallback.interstitialMaxFailuresPerSession,
      ).clamp(0, 1000),
      nativeMaxFailuresPerSession: intOr(
        'nativeMaxFailuresPerSession',
        fallback.nativeMaxFailuresPerSession,
      ).clamp(0, 1000),
      appOpenMinBackgroundSeconds: intOr(
        'appOpenMinBackgroundSeconds',
        fallback.appOpenMinBackgroundSeconds,
      ).clamp(0, 86400),
      appOpenCooldownSeconds: intOr(
        'appOpenCooldownSeconds',
        fallback.appOpenCooldownSeconds,
      ).clamp(0, 86400),
      showChatInterstitial: boolOr(
        'showChatInterstitial',
        fallback.showChatInterstitial,
      ),
      chatInterstitialCounter: intOr(
        'chatInterstitialCounter',
        fallback.chatInterstitialCounter,
      ),
      showOverlayNative: boolOr(
        'showOverlayNative',
        fallback.showOverlayNative,
      ),
      nativePlacements: {
        for (final placement in NativePlacement.values)
          placement.configKey: boolOr(
            placement.configKey,
            fallback.showsNativeAt(placement),
          ),
      },
      overlayAutoExpand: boolOr(
        'overlayAutoExpand',
        fallback.overlayAutoExpand,
      ),
      overlayAutoExpandIntervalSeconds: intOr(
        'overlayAutoExpandIntervalSeconds',
        fallback.overlayAutoExpandIntervalSeconds,
      ).clamp(0, 86400),
      appOpenId: stringOrNull('appOpenId') ?? fallback.appOpenId,
      bannerId: stringOrNull('bannerId') ?? fallback.bannerId,
      nativeId: stringOrNull('nativeId') ?? fallback.nativeId,
      interstitialId: stringOrNull('interstitialId') ?? fallback.interstitialId,
      rewardedId: stringOrNull('rewardedId') ?? fallback.rewardedId,
      rewardedInterstitialId:
          stringOrNull('rewardedInterstitialId') ??
          fallback.rewardedInterstitialId,
      showAdMetricsLab: boolOr('showAdMetricsLab', fallback.showAdMetricsLab),
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
    appOpenTimeoutSeconds: appOpenTimeoutSeconds,
    interstitialMaxFailuresPerSession: interstitialMaxFailuresPerSession,
    nativeMaxFailuresPerSession: nativeMaxFailuresPerSession,
    appOpenMinBackgroundSeconds: appOpenMinBackgroundSeconds,
    appOpenCooldownSeconds: appOpenCooldownSeconds,
    showChatInterstitial: showChatInterstitial,
    chatInterstitialCounter: chatInterstitialCounter,
    showOverlayNative: showOverlayNative,
    nativePlacements: nativePlacements,
    overlayAutoExpand: overlayAutoExpand,
    overlayAutoExpandIntervalSeconds: overlayAutoExpandIntervalSeconds,
    showAdMetricsLab: showAdMetricsLab,
    appOpenId: AdTestIds.appOpen,
    bannerId: AdTestIds.banner,
    nativeId: AdTestIds.native,
    interstitialId: AdTestIds.interstitial,
    rewardedId: AdTestIds.rewarded,
    rewardedInterstitialId: AdTestIds.rewardedInterstitial,
  );

  /// Serializes back to the same shape [fromJson] reads (AdsService logs the
  /// config it settled on with this).
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
    'appOpenTimeoutSeconds': appOpenTimeoutSeconds,
    'interstitialMaxFailuresPerSession': interstitialMaxFailuresPerSession,
    'nativeMaxFailuresPerSession': nativeMaxFailuresPerSession,
    'appOpenMinBackgroundSeconds': appOpenMinBackgroundSeconds,
    'appOpenCooldownSeconds': appOpenCooldownSeconds,
    'showChatInterstitial': showChatInterstitial,
    'chatInterstitialCounter': chatInterstitialCounter,
    'showOverlayNative': showOverlayNative,
    ...nativePlacements,
    'overlayAutoExpand': overlayAutoExpand,
    'overlayAutoExpandIntervalSeconds': overlayAutoExpandIntervalSeconds,
    'showAdMetricsLab': showAdMetricsLab,
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

  /// Whether tapping a chat tile should show an interstitial: same "no id
  /// means off" rule, independent of [showInterstitial].
  bool get chatInterstitialEnabled =>
      showAd && showChatInterstitial && interstitialId != null;

  /// The popup's native ad unit, or null when it's off: same "no id means
  /// off" rule, independent of [showNative].
  String? get overlayNativeAdUnitId =>
      showAd && showOverlayNative ? nativeId : null;

  /// Whether an app open ad should be requested on a cold start (the old
  /// "splash" ad): same "no id means off" rule as [toAdFlag].
  bool get appOpenOnLaunchEnabled =>
      showAd && showSplashAd && appOpenId != null;

  /// Whether an app open ad should be requested every time the app returns
  /// from the background.
  bool get appOpenOnResumeEnabled => showAd && showOpenApp && appOpenId != null;

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
