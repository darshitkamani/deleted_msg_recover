// File generated manually based on android/app/google-services.json.
// If you later add iOS/web/macOS apps in the Firebase console, regenerate
// this file with the FlutterFire CLI: `flutterfire configure`.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'run `flutterfire configure` to add web support.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS - '
          'run `flutterfire configure` to add iOS support.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAH-iTl2-N74Jcl-GZq0FsgJWSYvIgT0KM',
    appId: '1:415036222213:android:0c505ad28c9243fdd6256c',
    messagingSenderId: '415036222213',
    projectId: 'deleted-messages-recover-2263e',
    storageBucket: 'deleted-messages-recover-2263e.firebasestorage.app',
  );
}
