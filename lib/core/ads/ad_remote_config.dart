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

  /// Meta Audience Network placement ids, tried *before* the matching AdMob
  /// format (see AdsService) -- a Meta error falls straight back to AdMob,
  /// and a missing id skips Meta entirely. Unlike the AdMob ids these are
  /// kept as-is in debug builds: Meta has no shared test placement ids, so
  /// debug uses its test mode on the real placements instead.
  ///
  /// [metaNativeBannerId] is a "Native Banner" placement (no media view),
  /// used for the small native slot; [metaNativeId] for the medium one.
  /// [metaBannerId] is a 50dp banner placement, [metaMediumRectangleId] a
  /// 300x250 one -- both fall back to the AdMob [bannerId], which serves
  /// either size.
  final String? metaNativeId;
  final String? metaNativeBannerId;
  final String? metaInterstitialId;
  final String? metaBannerId;
  final String? metaMediumRectangleId;

  /// Meta on/off switches, the counterparts of the show* flags above:
  /// [showMetaAd] for every Meta format, and one per format (the banner one
  /// covers both banner sizes). Off only skips Meta -- the format then goes
  /// straight to AdMob, which still follows its own show* flag. [showAd]
  /// stays the master switch for both networks. All default to on.
  final bool showMetaAd;
  final bool showMetaNative;
  final bool showMetaInterstitial;
  final bool showMetaBanner;

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
    this.metaNativeId,
    this.metaNativeBannerId,
    this.metaInterstitialId,
    this.metaBannerId,
    this.metaMediumRectangleId,
    this.showMetaAd = true,
    this.showMetaNative = true,
    this.showMetaInterstitial = true,
    this.showMetaBanner = true,
    this.showAdMetricsLab = false,
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
    showAdMetricsLab: false,
    // Meta placements (Monetization Manager, property 4514578412193984).
    // No Native Banner placement yet, so small native slots go straight to
    // AdMob until `metaNativeBannerId` is set.
    metaNativeId: '937049769164180_937052809163876',
    metaInterstitialId: '937049769164180_937051689163988',
    metaMediumRectangleId: '937049769164180_937053395830484',
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
      metaNativeId: stringOrNull('metaNativeId') ?? fallback.metaNativeId,
      metaNativeBannerId:
          stringOrNull('metaNativeBannerId') ?? fallback.metaNativeBannerId,
      metaInterstitialId:
          stringOrNull('metaInterstitialId') ?? fallback.metaInterstitialId,
      metaBannerId: stringOrNull('metaBannerId') ?? fallback.metaBannerId,
      metaMediumRectangleId: stringOrNull('metaMediumRectangleId') ??
          fallback.metaMediumRectangleId,
      showMetaAd: boolOr('showMetaAd', fallback.showMetaAd),
      showMetaNative: boolOr('showMetaNative', fallback.showMetaNative),
      showMetaInterstitial: boolOr(
        'showMetaInterstitial',
        fallback.showMetaInterstitial,
      ),
      showMetaBanner: boolOr('showMetaBanner', fallback.showMetaBanner),
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
        showAdMetricsLab: showAdMetricsLab,
        appOpenId: AdTestIds.appOpen,
        bannerId: AdTestIds.banner,
        nativeId: AdTestIds.native,
        interstitialId: AdTestIds.interstitial,
        rewardedId: AdTestIds.rewarded,
        rewardedInterstitialId: AdTestIds.rewardedInterstitial,
        metaNativeId: metaNativeId,
        metaNativeBannerId: metaNativeBannerId,
        metaInterstitialId: metaInterstitialId,
        metaBannerId: metaBannerId,
        metaMediumRectangleId: metaMediumRectangleId,
        showMetaAd: showMetaAd,
        showMetaNative: showMetaNative,
        showMetaInterstitial: showMetaInterstitial,
        showMetaBanner: showMetaBanner,
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
        'showAdMetricsLab': showAdMetricsLab,
        'showMetaAd': showMetaAd,
        'showMetaNative': showMetaNative,
        'showMetaInterstitial': showMetaInterstitial,
        'showMetaBanner': showMetaBanner,
        if (appOpenId != null) 'appOpenId': appOpenId,
        if (bannerId != null) 'bannerId': bannerId,
        if (nativeId != null) 'nativeId': nativeId,
        if (interstitialId != null) 'interstitialId': interstitialId,
        if (rewardedId != null) 'rewardedId': rewardedId,
        if (rewardedInterstitialId != null)
          'rewardedInterstitialId': rewardedInterstitialId,
        if (metaNativeId != null) 'metaNativeId': metaNativeId,
        if (metaNativeBannerId != null)
          'metaNativeBannerId': metaNativeBannerId,
        if (metaInterstitialId != null)
          'metaInterstitialId': metaInterstitialId,
        if (metaBannerId != null) 'metaBannerId': metaBannerId,
        if (metaMediumRectangleId != null)
          'metaMediumRectangleId': metaMediumRectangleId,
      };

  /// A format stays off if it has no configured ad unit id, regardless of
  /// its own show* flag -- otherwise the package's own lower-level fallback
  /// (unitIDAppOpen/unitIDBanner/etc. in preload_google_ads) would silently
  /// substitute a test ad unit id and load/show a real ad slot with fake
  /// (test) content instead of just not loading it. "Enabled with no id"
  /// must mean "off," never "test ad."
  AdFlag toAdFlag() => AdFlag(
        showAd: showAd,
        // Banners are loaded on demand by MetaFirstBannerAd (Meta first, then
        // this AdMob id), so the package never preloads one.
        showBanner: false,
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
  /// "no id means off" rule as [toAdFlag], for either network.
  bool get interstitialEnabled =>
      metaInterstitialPlacement != null || googleInterstitialId != null;

  bool get _metaOn => showAd && showMetaAd;

  /// The Meta placement each slot should try first, or null to skip Meta
  /// (switched off, or no id) and go straight to AdMob.
  String? get metaNativePlacement =>
      _metaOn && showMetaNative ? metaNativeId : null;
  String? get metaNativeBannerPlacement =>
      _metaOn && showMetaNative ? metaNativeBannerId : null;
  String? get metaInterstitialPlacement =>
      _metaOn && showMetaInterstitial ? metaInterstitialId : null;
  String? get metaBannerPlacement =>
      _metaOn && showMetaBanner ? metaBannerId : null;
  String? get metaMediumRectanglePlacement =>
      _metaOn && showMetaBanner ? metaMediumRectangleId : null;

  /// The AdMob fallback for each Meta-first format, or null when AdMob's own
  /// flag has it off. (Native's AdMob side is the package's preloaded ad,
  /// which checks `showNative` itself.)
  String? get googleInterstitialId =>
      showAd && showInterstitial ? interstitialId : null;
  String? get googleBannerId => showAd && showBanner ? bannerId : null;

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
