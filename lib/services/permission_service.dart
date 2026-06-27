import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';

class PermissionService {
  static final _db = FirebaseFirestore.instance;
  static bool? _isPremium;

  static Future<bool> isPremium() async {
    if (_isPremium != null) return _isPremium!;
    try {
      final userId = await UserService.getUserId();
      // 特別扱いリストを確認
      final doc = await _db.collection('config').doc('permissions').get();
      if (doc.exists) {
        final premiumIds = List<String>.from(
            (doc.data()!['premiumDeviceIds'] as List? ?? []));
        if (premiumIds.contains(userId)) {
          _isPremium = true;
          return true;
        }
      }
      // 購入済みフラグを確認
      final userDoc = await _db
          .collection('users').doc(userId)
          .collection('settings').doc('purchase')
          .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        // Lifetimeを購入済みの場合
        if (data['isLifetime'] == true) {
          _isPremium = true;
          return true;
        }
        // Travel Packを購入済みの場合
        if (data['isPremium'] == true) {
          _isPremium = true;
          return true;
        }
      }
      _isPremium = false;
      return false;
    } catch (_) {
      return false;
    }
  }

  // Travel Packの追加スロット数を取得
  static Future<int> getExtraTripSlots() async {
    try {
      final userId = await UserService.getUserId();
      final doc = await _db
          .collection('users').doc(userId)
          .collection('settings').doc('purchase')
          .get();
      if (!doc.exists) return 0;
      return (doc.data()!['extraTripSlots'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // 旅行の上限数を取得（基本5件 + Travel Pack追加分）
  static Future<int> getMaxTrips() async {
    final isPrem = await isPremium();
    if (isPrem) return 999999;
    final extra = await getExtraTripSlots();
    return maxTrips + extra;
  }

  static void reset() => _isPremium = null;

  static const int maxTrips = 5;
  static const int maxEquipment = 3;
  static const int maxTemplates = 1;

  // アプリ導入日以降の旅行数をカウント
  static Future<int> countTripsAfterInstall(List<dynamic> trips) async {
    final installedAt = await UserService.getInstalledAt();
    if (installedAt == null) return trips.length;
    return trips.where((t) {
      final date = t.date as DateTime;
      return !date.isBefore(DateTime(installedAt.year, installedAt.month, installedAt.day));
    }).length;
  }
}
