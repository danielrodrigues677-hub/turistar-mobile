import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBGy-N7FGg-Bix5H2YahGhadYmn036bQgU',
    appId: '1:472803713819:web:9be19e0e6238f24a45a9be',
    messagingSenderId: '472803713819',
    projectId: 'app-turistar',
    authDomain: 'app-turistar.firebaseapp.com',
    storageBucket: 'app-turistar.firebasestorage.app',
    measurementId: 'G-VBCVFPCN9N',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBGy-N7FGg-Bix5H2YahGhadYmn036bQgU',
    appId: '1:472803713819:android:348d474102778f2b45a9be',
    messagingSenderId: '472803713819',
    projectId: 'app-turistar',
    storageBucket: 'app-turistar.firebasestorage.app',
  );
}
