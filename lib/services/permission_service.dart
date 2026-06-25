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
      // 購入済みフラグを確認（将来の課金実装用）
      final userDoc = await _db
          .collection('users').doc(userId)
          .collection('settings').doc('purchase')
          .get();
      if (userDoc.exists) {
        _isPremium = (userDoc.data()!['isPremium'] as bool?) ?? false;
        return _isPremium!;
      }
      _isPremium = false;
      return false;
    } catch (_) {
      return false;
    }
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
