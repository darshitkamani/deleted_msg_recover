import 'package:firebase_analytics/firebase_analytics.dart';

/// Thin wrapper around FirebaseAnalytics -- gives the rest of the app a
/// single place to log custom events without importing the plugin directly
/// everywhere (mirrors AdsService/UpdateService's own singleton pattern).
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Automatic screen-view tracking for [RecoverApp]'s navigatorObservers.
  FirebaseAnalyticsObserver get navigatorObserver =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> logEvent(String name, {Map<String, Object>? parameters}) {
    return _analytics.logEvent(name: name, parameters: parameters);
  }
}
