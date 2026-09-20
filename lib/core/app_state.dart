import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';
import 'models/chat.dart';
import 'models/message.dart';
import 'native_bridge.dart';

const _localeCodePrefKey = 'locale_code';
const _onboardingCompletePrefKey = 'onboarding_complete';
const _appTourCompletePrefKey = 'app_tour_complete';

/// Central app state: permission status, monitored apps, cached chats, and
/// the user's chosen display language. Refreshes itself when the native
/// listener reports a new message while the app is in the foreground, and
/// again on every app resume -- some OEMs (notably on Android 10-12) kill
/// the Flutter engine while the app is backgrounded, so a message captured
/// by the still-running NotificationListenerService never reaches the live
/// event stream and would otherwise only show up after the app is fully
/// relaunched.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  bool notificationAccessGranted = false;
  bool ignoringBatteryOptimizations = false;
  Set<String> monitoredApps = {pkgWhatsApp, pkgWhatsAppBusiness};

  List<Chat> chats = [];
  bool loading = false;
  Object? chatsError;

  Locale? locale;
  bool onboardingComplete = false;
  bool appTourComplete = false;

  /// True once the fast, prefs-only loads below (locale + onboarding
  /// status) are done -- the signal [_RootRouter] waits on before it can
  /// decide between the splash, onboarding, and home screens. Deliberately
  /// not gated on the slower native calls further down (permissions,
  /// monitored apps, chats), which keep loading in the background and
  /// notify their own listeners when done.
  bool ready = false;

  /// True once the first notification-access check has finished (whether it
  /// succeeded or threw). [_RootRouter] waits on it so a persisted
  /// "onboarding complete" flag can be overridden by the real permission
  /// state before any post-onboarding screen is shown.
  bool accessChecked = false;

  /// Bumped every time [refreshData] finishes -- which also runs on every
  /// native message event and app resume. Screens that keep their own copy
  /// of native data (e.g. the Deleted tab) watch it to know when to reload.
  int dataRevision = 0;

  /// Set by a pushed screen (e.g. the welcome chat's "See how to use" link)
  /// that wants [HomeShell] to switch its bottom-nav tab once the screen
  /// pops back to it. `null` once consumed.
  int? pendingTabIndex;

  void goToTab(int index) {
    pendingTabIndex = index;
    notifyListeners();
  }

  void clearPendingTab() {
    pendingTabIndex = null;
  }

  StreamSubscription<Map<dynamic, dynamic>>? _eventSub;

  bool get isSupportedPlatform => Platform.isAndroid;

  Future<void> init() async {
    await _loadLocale();
    await _loadOnboardingComplete();
    ready = true;
    notifyListeners();
    if (!isSupportedPlatform) return;
    // Each step runs independently -- one throwing (permissions, monitored
    // apps) must not stop the others (crucially refreshData and the event
    // subscription) from ever running at all.
    await _guard(refreshPermissions);
    // A persisted "onboarding complete" flag can outlive the permission it
    // was earned with -- e.g. Android Auto Backup restoring app prefs on a
    // fresh install, where notification access is not granted, or access
    // revoked later in system settings. Without access the app can't capture
    // anything, so onboarding (which asks for it) has to run again. Only the
    // in-memory flag is reset; "Get started" persists it again.
    if (!notificationAccessGranted) onboardingComplete = false;
    accessChecked = true;
    notifyListeners();
    await _guard(refreshMonitoredApps);
    await refreshData();
    _eventSub ??= NativeBridge.events.listen((_) => refreshData());
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _guard(Future<void> Function() step) async {
    try {
      await step();
    } catch (_) {
      // Swallowed deliberately: the field(s) that step would have set just
      // keep their prior/default value, and later steps still run.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isSupportedPlatform) {
      // Notification access and battery-optimization exclusion can only be
      // granted from their system settings screens, so re-check both
      // whenever the user comes back -- otherwise the Settings tab's
      // switches would keep showing the pre-settings-visit state until
      // some unrelated action (like opening a chat) happened to trigger a
      // refresh.
      _guard(refreshPermissions);
      refreshData();
    }
  }

  Future<void> _loadOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    onboardingComplete = prefs.getBool(_onboardingCompletePrefKey) ?? false;
    appTourComplete = prefs.getBool(_appTourCompletePrefKey) ?? false;
    notifyListeners();
  }

  /// Called once the user finishes the onboarding flow (taps "Get started").
  /// Kept separate from live permission status so the root router doesn't
  /// jump straight to the home screen the moment a permission is granted
  /// mid-onboarding -- the user should still see the remaining steps.
  Future<void> completeOnboarding() async {
    onboardingComplete = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletePrefKey, true);
  }

  /// Called once the user dismisses [AppTourScreen] (taps "Continue"), right
  /// after onboarding -- the point [_RootRouter] treats as safe to show
  /// [HomeShell]. Persisted like onboarding so the tour, like onboarding, is
  /// only ever shown to a given install once.
  Future<void> completeAppTour() async {
    appTourComplete = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appTourCompletePrefKey, true);
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeCodePrefKey);
    if (code != null) {
      locale = Locale(code);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale? newLocale) async {
    locale = newLocale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (newLocale == null) {
      await prefs.remove(_localeCodePrefKey);
    } else {
      await prefs.setString(_localeCodePrefKey, newLocale.languageCode);
    }
  }

  Future<void> refreshPermissions() async {
    if (!isSupportedPlatform) return;
    notificationAccessGranted =
        await NativeBridge.isNotificationAccessGranted();
    ignoringBatteryOptimizations =
        await NativeBridge.isIgnoringBatteryOptimizations();
    notifyListeners();
  }

  Future<void> refreshMonitoredApps() async {
    if (!isSupportedPlatform) return;
    monitoredApps = await NativeBridge.getMonitoredApps();
    notifyListeners();
  }

  Future<void> setMonitored(String package, bool enabled) async {
    final next = Set<String>.from(monitoredApps);
    if (enabled) {
      next.add(package);
    } else {
      next.remove(package);
    }
    monitoredApps = next;
    notifyListeners();
    await NativeBridge.setMonitoredApps(next);
  }

  Future<void> refreshData() async {
    if (!isSupportedPlatform) return;
    loading = true;
    chatsError = null;
    notifyListeners();
    try {
      chats = await NativeBridge.getChats();
    } catch (e) {
      // Otherwise a throw here (e.g. a stale build missing a platform
      // channel method) leaves `loading` stuck true with nothing ever
      // clearing it, and no indication anywhere of what went wrong.
      chatsError = e;
    }
    loading = false;
    dataRevision++;
    notifyListeners();
  }

  Future<List<Message>> loadMessages(String chatKey) {
    return NativeBridge.getMessages(chatKey);
  }

  Future<void> openChat(String chatKey) async {
    await NativeBridge.markChatOpened(chatKey);
  }

  Future<void> clearAll() async {
    await NativeBridge.clearAll();
    await refreshData();
  }

  Future<void> requestNotificationAccess() {
    return NativeBridge.openNotificationAccessSettings();
  }

  Future<bool> requestBatteryExclusion() {
    return NativeBridge.requestIgnoreBatteryOptimizations();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
