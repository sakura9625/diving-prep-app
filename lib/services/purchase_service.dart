import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'user_service.dart';
import 'permission_service.dart';

class PurchaseService {
  static final _iap = InAppPurchase.instance;
  static final _db  = FirebaseFirestore.instance;

  static const String travelPackId  = 'com.sakura9625.divingprepapp.travelpack';
  static const String lifetimeId    = 'com.sakura9625.divingprepapp.lifetime';
  static const String diveCloudId   = 'com.sakura9625.divingprepapp.divecloud.annual';

  static const Set<String> _productIds = {
    travelPackId,
    lifetimeId,
    diveCloudId,
  };

  static StreamSubscription<List<PurchaseDetails>>? _subscription;
  static List<ProductDetails> _products = [];

  static List<ProductDetails> get products => _products;

  static Future<void> initialize() async {
    final available = await _iap.isAvailable();
    if (!available) return;

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (_) {},
    );

    await _loadProducts();
  }

  static Future<void> _loadProducts() async {
    final response = await _iap.queryProductDetails(_productIds);
    _products = response.productDetails;
  }

  static Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _savePurchase(purchase.productID);
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  static Future<void> _savePurchase(String productId) async {
    final userId = await UserService.getUserId();
    final data = <String, dynamic>{
      'isPremium': true,
      'purchasedAt': DateTime.now().toIso8601String(),
    };

    if (productId == travelPackId) {
      // 現在のtravel pack数を取得して+1
      final doc = await _db
          .collection('users').doc(userId)
          .collection('settings').doc('purchase')
          .get();
      final current = (doc.data()?['travelPackCount'] as int?) ?? 0;
      data['travelPackCount'] = current + 1;
      data['extraTripSlots'] = (current + 1) * 20;
    } else if (productId == lifetimeId) {
      data['isLifetime'] = true;
    } else if (productId == diveCloudId) {
      data['isDiveCloud'] = true;
    }

    await _db
        .collection('users').doc(userId)
        .collection('settings').doc('purchase')
        .set(data, SetOptions(merge: true));

    PermissionService.reset();
  }

  static Future<void> buy(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    if (product.id == travelPackId) {
      await _iap.buyConsumable(purchaseParam: param);
    } else {
      await _iap.buyNonConsumable(purchaseParam: param);
    }
  }

  static Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  static void dispose() {
    _subscription?.cancel();
  }
}
