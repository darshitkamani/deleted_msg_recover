import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the Google "Ad Metrics Lab" overlay (PreloadGoogleAds.showAdCounter)
/// and the Ad Inspector overlay (ad_inspector_lab.dart) are shown.
///
/// Each overlay follows the `showAdMetricsLab` remote flag (always on in debug
/// builds) unless it's been switched on/off by hand from the hidden ad lab
/// dialog (a 10-second hold on the home screen's settings button). That
/// manual choice is saved on the device and wins over the remote flag until
/// it's reset from the same dialog.
///
/// Only controls visibility: the Ad Metrics Lab's stats keep counting either
/// way.
class AdLabSettings {
  AdLabSettings._();

  static final AdLabSettings instance = AdLabSettings._();

  static const _googlePrefKey = 'ad_lab_google_override';
  static const _inspectorPrefKey = 'ad_lab_inspector_override';

  final ValueNotifier<bool> showGoogleLab = ValueNotifier(kDebugMode);
  final ValueNotifier<bool> showInspectorLab = ValueNotifier(kDebugMode);

  bool _remoteFlag = false;
  bool? _googleOverride;
  bool? _inspectorOverride;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _googleOverride = prefs.getBool(_googlePrefKey);
    _inspectorOverride = prefs.getBool(_inspectorPrefKey);
    _apply();
  }

  /// Called by AdsService once the `showAdMetricsLab` remote flag is fetched.
  void applyRemoteFlag(bool value) {
    _remoteFlag = value;
    _apply();
  }

  Future<void> setGoogleLab(bool value) async {
    _googleOverride = value;
    _apply();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_googlePrefKey, value);
  }

  Future<void> setInspectorLab(bool value) async {
    _inspectorOverride = value;
    _apply();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_inspectorPrefKey, value);
  }

  /// Drops both manual choices so the overlays follow the remote flag again.
  Future<void> resetToRemote() async {
    _googleOverride = null;
    _inspectorOverride = null;
    _apply();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_googlePrefKey);
    await prefs.remove(_inspectorPrefKey);
  }

  void _apply() {
    final byDefault = _remoteFlag || kDebugMode;
    showGoogleLab.value = _googleOverride ?? byDefault;
    showInspectorLab.value = _inspectorOverride ?? byDefault;
  }
}
