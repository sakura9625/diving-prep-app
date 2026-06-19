import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'AIzaSyDmm2uMGXFIET6e2zzfcPTOKsPLHe6veKk',
    appId:             '1:187561670094:web:fce76426c2a1aec547a79f',
    messagingSenderId: '187561670094',
    projectId:         'mogunchu-triplist',
    authDomain:        'mogunchu-triplist.firebaseapp.com',
    storageBucket:     'mogunchu-triplist.firebasestorage.app',
  );
}
