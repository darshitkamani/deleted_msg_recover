import 'dart:async';

import 'package:preload_google_ads/preload_google_ads.dart';

import 'meta_ad_stats.dart';
import 'meta_ads_bridge.dart';

/// The navigation interstitial: same counting as the package's
/// [OnDemandInterstitialAd] (loads one navigation before it's due, shows on
/// every [interval]th one), but each load asks Meta first and only requests
/// AdMob if Meta errors -- either way at most one ad is held at a time.
class MetaFirstInterstitial {
  MetaFirstInterstitial({
    required this.metaPlacementId,
    required this.googleAdUnitId,
    required this.interval,
  });

  final String? metaPlacementId;
  final String? googleAdUnitId;

  /// Show on every [interval]th navigation; 1 or less loads on the first
  /// navigation and shows on the next.
  final int interval;

  /// How long a loaded-but-unshown ad is kept. Meta invalidates its ads after
  /// about an hour; AdMob's limit is 4 hours.
  static const _metaMaxAge = Duration(minutes: 55);
  static const _googleMaxAge = Duration(hours: 3);

  int _navigations = 0;
  bool _loading = false;
  bool _showing = false;

  String? _metaAdId;
  InterstitialAd? _googleAd;
  DateTime? _loadedAt;

  /// Reports one screen navigation / tab change.
  void onNavigation() {
    if (_showing) return;
    _navigations++;
    if (_navigations < interval - 1) return;

    if (_navigations >= interval && _isReady) {
      _show();
    } else {
      _load();
    }
  }

  bool get _isReady {
    final loadedAt = _loadedAt;
    if (loadedAt == null) return false;
    final maxAge = _metaAdId != null ? _metaMaxAge : _googleMaxAge;
    if (DateTime.now().difference(loadedAt) > maxAge) {
      _drop();
      return false;
    }
    return true;
  }

  void _drop() {
    final metaId = _metaAdId;
    if (metaId != null) MetaAdsBridge.destroy(metaId);
    _googleAd?.dispose();
    _metaAdId = null;
    _googleAd = null;
    _loadedAt = null;
  }

  Future<void> _load() async {
    if (_loading || _isReady) return;
    _loading = true;
    try {
      final metaId = metaPlacementId;
      if (metaId != null) {
        final id = await MetaAdsBridge.loadInterstitial(metaId);
        if (id != null) {
          _metaAdId = id;
          _loadedAt = DateTime.now();
          return;
        }
        MetaAdStats.instance[MetaAdFormat.interstitial].fallbacks.value++;
      }
      final googleId = googleAdUnitId;
      if (googleId != null) {
        final ad = await _loadGoogle(googleId);
        if (ad != null) {
          _googleAd = ad;
          _loadedAt = DateTime.now();
        }
      }
    } finally {
      _loading = false;
    }
  }

  Future<InterstitialAd?> _loadGoogle(String adUnitId) {
    final completer = Completer<InterstitialAd?>();
    try {
      InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            ad.setImmersiveMode(true);
            completer.complete(ad);
          },
          onAdFailedToLoad: (error) {
            debugPrint('AdMob interstitial failed to load: $error');
            completer.complete(null);
          },
        ),
      );
    } catch (e) {
      debugPrint('AdMob interstitial load threw: $e');
      if (!completer.isCompleted) completer.complete(null);
    }
    return completer.future;
  }

  Future<void> _show() async {
    final metaId = _metaAdId;
    final googleAd = _googleAd;
    _metaAdId = null;
    _googleAd = null;
    _loadedAt = null;
    _navigations = 0;
    _showing = true;

    if (metaId != null) {
      await MetaAdsBridge.showInterstitial(metaId);
      _showing = false;
      return;
    }

    googleAd!.fullScreenContentCallback =
        FullScreenContentCallback<InterstitialAd>(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            _showing = false;
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            debugPrint('AdMob interstitial failed to show: $error');
            ad.dispose();
            _showing = false;
          },
        );
    googleAd.show();
  }
}
