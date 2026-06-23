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
    _userId = deviceId;
    return _userId!;
  }

  static Future<String> get userPath async {
    final id = await getUserId();
    return 'users/$id';
  }
}
