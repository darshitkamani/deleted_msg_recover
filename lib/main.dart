import 'package:flutter/material.dart';

import 'app.dart';
import 'core/ads/ads_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Fire-and-forget: the Google Mobile Ads SDK loads ads purely on demand,
  // so nothing needs to block the first frame on this finishing.
  AdsService.instance.init();
  runApp(const RecoverApp());
}
