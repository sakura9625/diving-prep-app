import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'AIzaSyDmm2uMGXFIET6e2zzfcPTOKsPLHe6veKk',
    appId:             '1:187561670094:web:fce76426c2a1aec547a79f',
    messagingSenderId: '187561670094',
    projectId:         'mogunchu-triplist',
    authDomain:        'mogunchu-triplist.firebaseapp.com',
    storageBucket:     'mogunchu-triplist.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'AIzaSyBOGYVxs9Vj1eXUxdSftUIjtdCh7tg3Nw0',
    appId:             '1:187561670094:ios:4dffc26ef5b8a24047a79f',
    messagingSenderId: '187561670094',
    projectId:         'mogunchu-triplist',
    storageBucket:     'mogunchu-triplist.firebasestorage.app',
    iosBundleId:       'com.sakura9625.divingprepapp',
  );
}
