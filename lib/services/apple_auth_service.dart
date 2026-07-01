import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';

class AppleAuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db  = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;
  static bool get isSignedIn => _auth.currentUser != null;

  static Future<bool> signIn() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      await _auth.signInWithCredential(oauthCredential);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // デバイスIDからApple IDにデータ移行
  static Future<void> migrateData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final deviceId = await UserService.getUserId();
    final appleId = user.uid;

    if (deviceId == appleId) return;

    try {
      // デバイスIDのコレクション一覧
      const collections = [
        'trips', 'costs', 'checks', 'templates',
        'equipment', 'history', 'marineLife', 'templateItems'
      ];

      for (final col in collections) {
        final snapshot = await _db
            .collection('users').doc(deviceId)
            .collection(col).get();

        for (final doc in snapshot.docs) {
          await _db
              .collection('users').doc(appleId)
              .collection(col).doc(doc.id)
              .set(doc.data());
        }
      }

      // settingsも移行
      final settingsSnap = await _db
          .collection('users').doc(deviceId)
          .collection('settings').get();

      for (final doc in settingsSnap.docs) {
        await _db
            .collection('users').doc(appleId)
            .collection('settings').doc(doc.id)
            .set(doc.data(), SetOptions(merge: true));
      }

      // UserServiceのIDをApple IDに更新
      await UserService.overrideUserId(appleId);

    } catch (_) {}
  }
}
