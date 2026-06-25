import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static String? _userId;

  static Future<String> getUserId() async {
    if (_userId != null) return _userId!;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('user_id');
    if (saved != null) {
      _userId = saved;
      return _userId!;
    }

    // デバイスIDを取得
    final deviceInfo = DeviceInfoPlugin();
    String deviceId;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown';
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else {
        deviceId = 'web_user';
      }
    } catch (_) {
      deviceId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
    }

    await prefs.setString('user_id', deviceId);
    // 初回導入日を保存
    await _saveInstalledAt(deviceId);
    _userId = deviceId;
    return _userId!;
  }

  static Future<void> _saveInstalledAt(String userId) async {
    try {
      final db = FirebaseFirestore.instance;
      final doc = await db
          .collection('users').doc(userId)
          .collection('settings').doc('profile')
          .get();
      if (!doc.exists || doc.data()!['installedAt'] == null) {
        await db
            .collection('users').doc(userId)
            .collection('settings').doc('profile')
            .set({'installedAt': DateTime.now().toIso8601String()},
                SetOptions(merge: true));
      }
    } catch (_) {}
  }

  static Future<DateTime?> getInstalledAt() async {
    try {
      final userId = await getUserId();
      final db = FirebaseFirestore.instance;
      final doc = await db
          .collection('users').doc(userId)
          .collection('settings').doc('profile')
          .get();
      if (!doc.exists) return null;
      final str = doc.data()!['installedAt'] as String?;
      if (str == null) return null;
      return DateTime.parse(str);
    } catch (_) {
      return null;
    }
  }

  static Future<String> get userPath async {
    final id = await getUserId();
    return 'users/$id';
  }
}
