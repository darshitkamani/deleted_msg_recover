import 'dart:async';

import 'package:preload_google_ads/preload_google_ads.dart';

import 'meta_ad_stats.dart';
import 'meta_ads_bridge.dart';

/// The app-open slot (cold start and every return from the background). Meta
/// has no app open format, so it shows a Meta interstitial first and only asks
/// for the AdMob app open ad ([OnDemandAppOpenAd]) if Meta has nothing -- an
/// error, a timeout, or the format past its no-fill limit. Like the AdMob one,
/// nothing is preloaded and an ad that arrives too late is never shown.
class MetaFirstAppOpen {
  MetaFirstAppOpen({required this.metaPlacementId, String? googleAdUnitId})
    : _google = googleAdUnitId == null
          ? null
          : OnDemandAppOpenAd(adUnitId: googleAdUnitId);

  final String? metaPlacementId;
  final OnDemandAppOpenAd? _google;

  /// Total wait for an ad on a return from the background, Meta and AdMob
  /// together -- the same budget the AdMob app open ad had on its own.
  static const resumeTimeout = Duration(seconds: 4);

  bool _busy = false;
  StreamSubscription<AppState>? _appStateSub;

  /// Shows an ad if one arrives within [timeout] (Meta first, AdMob with what
  /// is left of it). Completes with whether one was shown and dismissed.
  Future<bool> loadAndShow({Duration timeout = resumeTimeout}) async {
    if (_busy) return false;
    _busy = true;
    try {
      final deadline = DateTime.now().add(timeout);
      final metaId = metaPlacementId;
      if (metaId != null) {
        final id = await MetaAdsBridge.loadInterstitialWithin(metaId, timeout);
        if (id != null) return MetaAdsBridge.showInterstitial(id);
      }
      final google = _google;
      if (google == null) return false;
      if (metaId != null) {
        MetaAdStats.instance[MetaAdFormat.interstitial].fallbacks.value++;
      }
      final left = deadline.difference(DateTime.now());
      if (left <= Duration.zero) return false;
      return google.loadAndShow(timeout: left);
    } finally {
      _busy = false;
    }
  }

  /// Calls [loadAndShow] every time the app comes back to the foreground.
  /// Safe to call more than once.
  void startListening() {
    if (_appStateSub != null) return;
    AppStateEventNotifier.startListening();
    _appStateSub = AppStateEventNotifier.appStateStream.listen((state) {
      if (state == AppState.foreground) loadAndShow();
    });
  }
}
