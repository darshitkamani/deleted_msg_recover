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

  Locale? locale;
  bool onboardingComplete = false;

  StreamSubscription<Map<dynamic, dynamic>>? _eventSub;

  bool get isSupportedPlatform => Platform.isAndroid;

  Future<void> init() async {
    await _loadLocale();
    await _loadOnboardingComplete();
    if (!isSupportedPlatform) return;
    await refreshPermissions();
    await refreshMonitoredApps();
    await refreshData();
    _eventSub ??= NativeBridge.events.listen((_) => refreshData());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isSupportedPlatform) {
      refreshData();
    }
  }

  Future<void> _loadOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    onboardingComplete = prefs.getBool(_onboardingCompletePrefKey) ?? false;
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
    notificationAccessGranted = await NativeBridge.isNotificationAccessGranted();
    ignoringBatteryOptimizations = await NativeBridge.isIgnoringBatteryOptimizations();
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
    notifyListeners();
    chats = await NativeBridge.getChats();
    loading = false;
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

  Future<void> requestBatteryExclusion() {
    return NativeBridge.requestIgnoreBatteryOptimizations();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
