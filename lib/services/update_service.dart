import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  static final _db = FirebaseFirestore.instance;

  static Future<bool> isUpdateAvailable() async {
    try {
      final doc = await _db.collection('config').doc('appVersion').get();
      if (!doc.exists) return false;
      final minVersion = (doc.data()!['minVersion'] as int?) ?? 0;
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      return currentBuild < minVersion;
    } catch (_) {
      return false;
    }
  }

  static Future<String> getStoreUrl() async {
    try {
      final doc = await _db.collection('config').doc('appVersion').get();
      return (doc.data()!['appStoreUrl'] as String?) ?? '';
    } catch (_) {
      return '';
    }
  }
}
