import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:preload_google_ads/preload_google_ads.dart';

import 'app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(testDeviceIds: ['B4037EE73E605DACD92FC5BBF15EEA8A']),
  );
  runApp(const RecoverApp());
}
