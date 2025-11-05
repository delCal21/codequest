import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBhv5c65qTs_iPIOf8IA3aH2uoI55yvsl4',
    appId: '1:203944103708:web:880109c184e32da9fc34d9',
    messagingSenderId: '203944103708',
    projectId: 'codequest-a5317',
    authDomain: 'codequest-a5317.firebaseapp.com',
    storageBucket: 'codequest-a5317.firebasestorage.app',
    measurementId: 'G-6KH369ZNNX',
    databaseURL: 'https://codequest-a5317-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBOS0rRTx_SE_YCX9QVFH2fpsbUVwToLrM',
    appId: '1:203944103708:android:0246b146b00b2cdafc34d9',
    messagingSenderId: '203944103708',
    projectId: 'codequest-a5317',
    storageBucket: 'codequest-a5317.firebasestorage.app',
    databaseURL: 'https://codequest-a5317-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBOS0rRTx_SE_YCX9QVFH2fpsbUVwToLrM',
    appId: '1:203944103708:ios:0246b146b00b2cdafc34d9',
    messagingSenderId: '203944103708',
    projectId: 'codequest-a5317',
    storageBucket: 'codequest-a5317.firebasestorage.app',
    databaseURL: 'https://codequest-a5317-default-rtdb.firebaseio.com',
    iosClientId: '203944103708-ios-client-id',
    iosBundleId: 'com.example.codequest',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBOS0rRTx_SE_YCX9QVFH2fpsbUVwToLrM',
    appId: '1:203944103708:macos:0246b146b00b2cdafc34d9',
    messagingSenderId: '203944103708',
    projectId: 'codequest-a5317',
    storageBucket: 'codequest-a5317.firebasestorage.app',
    databaseURL: 'https://codequest-a5317-default-rtdb.firebaseio.com',
    iosClientId: '203944103708-macos-client-id',
    iosBundleId: 'com.example.codequest',
  );
}
