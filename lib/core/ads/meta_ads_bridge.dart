import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'meta_ad_stats.dart';

/// Dart side of the Meta Audience Network bridge (see
/// android/.../MetaAdsBridge.kt). Android only -- everywhere else every load
/// simply reports "no ad", which callers treat like any Meta failure: fall back
/// to AdMob.
///
/// Each `load*` resolves to an id once the ad has actually loaded, or null on
/// any error (no fill, bad placement id, SDK not ready, ...). The id is then
/// handed to a platform view (native/banner) or to [showInterstitial], and must
/// be released with [destroy] when its owner goes away.
class MetaAdsBridge {
  MetaAdsBridge._();

  static const _channel = MethodChannel('recover/meta_ads');

  /// Platform view types registered by MetaAdsBridge.kt.
  static const nativeViewType = 'recover/meta_native';
  static const bannerViewType = 'recover/meta_banner';

  static final _dismissals = <String, Completer<void>>{};
  static Future<bool>? _initFuture;

  /// Meta failures in a row after which a format stops asking Meta for the
  /// rest of this process (i.e. until the next app launch) -- its slots then go
  /// straight to AdMob. Set from the ad config's `metaNoFillLimit` by
  /// AdsService; a success resets the count. The interstitial, app-open and
  /// rewarded slots share one count, since they share one placement.
  static int noFillLimit = 3;

  /// Whether [format] has hit [noFillLimit] and is AdMob-only for now.
  static bool isSwitchedToGoogle(MetaAdFormat format) =>
      MetaAdStats.instance[format].switchedToGoogle.value;

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Starts the SDK once per process. [testMode] makes Meta serve its test
  /// creatives on the real placement ids (Meta has no shared test ids).
  static Future<bool> initialize({required bool testMode}) {
    return _initFuture ??= _initialize(testMode);
  }

  static Future<bool> _initialize(bool testMode) async {
    if (!isSupported) return false;
    _channel.setMethodCallHandler(_onNativeCall);
    bool ok;
    try {
      ok =
          await _channel.invokeMethod<bool>('initialize', {
            'testMode': testMode,
          }) ??
          false;
    } catch (e) {
      debugPrint('Meta ads init failed: $e');
      ok = false;
    }
    MetaAdStats.instance.initialized.value = ok;
    return ok;
  }

  static Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method == 'interstitialDismissed') {
      final id = (call.arguments as Map)['id'] as String;
      _dismissals.remove(id)?.complete();
    } else if (call.method == 'adEvent') {
      final args = call.arguments as Map;
      MetaAdStats.instance.recordEvent(
        args['format'] as String,
        args['event'] as String,
      );
    }
  }

  /// [small] loads a Meta *native banner* ad (no media view, for the small
  /// slot), otherwise a full native ad -- two different placement types in
  /// Monetization Manager.
  static Future<String?> loadNative(
    String placementId, {
    required bool small,
  }) => _load(
    small ? MetaAdFormat.nativeBanner : MetaAdFormat.native,
    'loadNative',
    {'placementId': placementId, 'small': small},
  );

  /// [mediumRectangle] loads a 300x250 ad instead of a 50dp-tall banner.
  static Future<String?> loadBanner(
    String placementId, {
    required bool mediumRectangle,
  }) => _load(
    mediumRectangle ? MetaAdFormat.mediumRectangle : MetaAdFormat.banner,
    'loadBanner',
    {'placementId': placementId, 'mediumRectangle': mediumRectangle},
  );

  static Future<String?> loadInterstitial(String placementId) => _load(
    MetaAdFormat.interstitial,
    'loadInterstitial',
    {'placementId': placementId},
  );

  static Future<String?> _load(
    MetaAdFormat format,
    String method,
    Map<String, Object> args,
  ) async {
    final stats = MetaAdStats.instance;
    // Past the no-fill limit: don't even ask, the caller goes to AdMob.
    if (isSwitchedToGoogle(format)) return null;
    if (!isSupported || !await (_initFuture ?? Future.value(false))) {
      _failed(format, 'SDK not initialized');
      return null;
    }
    stats[format].requests.value++;
    try {
      final id = await _channel.invokeMethod<String>(method, args);
      if (id == null) {
        _failed(format, 'no ad id returned');
        return null;
      }
      stats[format].loaded.value++;
      stats[format].failuresInARow.value = 0;
      return id;
    } on PlatformException catch (e) {
      debugPrint('Meta $method failed: ${e.code} ${e.details} ${e.message}');
      // details carries Meta's error code (1001 = no fill, 1002 = too many
      // requests, 2000s = server/network).
      _failed(format, '${e.details ?? e.code} ${e.message ?? ''}');
      return null;
    }
  }

  static void _failed(MetaAdFormat format, String error) {
    final stats = MetaAdStats.instance;
    stats.recordError(format, error);
    final row = stats[format];
    row.failuresInARow.value++;
    if (row.failuresInARow.value >= noFillLimit &&
        !row.switchedToGoogle.value) {
      row.switchedToGoogle.value = true;
      debugPrint(
        'Meta ${format.name}: $noFillLimit failures in a row, AdMob only until next launch',
      );
    }
  }

  /// [loadInterstitial] that gives up after [timeout] -- for slots that make
  /// the user wait (app open, the rewarded gate). An ad that arrives after
  /// that is destroyed rather than leaked; the wait doesn't count as a Meta
  /// failure, only a real load error does.
  static Future<String?> loadInterstitialWithin(
    String placementId,
    Duration timeout,
  ) {
    final load = loadInterstitial(placementId);
    return load.timeout(
      timeout,
      onTimeout: () {
        load.then((late) {
          if (late != null) destroy(late);
        });
        return null;
      },
    );
  }

  /// Shows a loaded interstitial and completes once it's dismissed. Returns
  /// false straight away (nothing shown) if the ad expired or failed to show.
  static Future<bool> showInterstitial(String id) async {
    final dismissed = _dismissals[id] = Completer<void>();
    bool shown;
    try {
      shown =
          await _channel.invokeMethod<bool>('showInterstitial', {'id': id}) ??
          false;
    } catch (_) {
      shown = false;
    }
    if (!shown) {
      _dismissals.remove(id);
      return false;
    }
    await dismissed.future;
    return true;
  }

  static Future<void> destroy(String id) async {
    try {
      await _channel.invokeMethod('destroy', {'id': id});
    } catch (_) {}
  }
}
