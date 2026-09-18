import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:preload_google_ads/preload_google_ads.dart';

import 'app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Catches Dart-side crashes (Flutter framework errors, and anything else uncaught).
  // The background WhatsApp-notification listener that this app depends on is native
  // Kotlin, not Dart -- see NotificationListener.kt/MessageStore.kt's own
  // FirebaseCrashlytics.recordException calls for that half of the picture.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(testDeviceIds: ['B4037EE73E605DACD92FC5BBF15EEA8A']),
  );
  runApp(const RecoverApp());
}
