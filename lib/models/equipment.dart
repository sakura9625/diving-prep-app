import 'package:flutter/material.dart';

enum EquipmentType {
  bcd,
  regulator,
  drySuit,
  wetSuit,
  other;

  String get label {
    switch (this) {
      case bcd:        return 'BCD';
      case regulator:  return 'レギュレーター';
      case drySuit:    return 'ドライスーツ';
      case wetSuit:    return 'ウェットスーツ';
      case other:      return 'その他';
    }
  }

  IconData get icon {
    switch (this) {
      case bcd:        return Icons.scuba_diving;
      case regulator:  return Icons.air;
      case drySuit:    return Icons.accessibility_new;
      case wetSuit:    return Icons.pool;
      case other:      return Icons.category;
    }
  }
}

class Equipment {
  final String id;
  String name;
  EquipmentType type;
  DateTime? purchaseDate;
  DateTime lastMaintenanceDate;
  int divesManual; // 前回メンテナンスからの使用本数（手動入力）

  Equipment({
    required this.id,
    required this.name,
    required this.type,
    this.purchaseDate,
    required this.lastMaintenanceDate,
    this.divesManual = 0,
  });

  Map<String, dynamic> toJson() => {
    'id':                  id,
    'name':                name,
    'type':                type.name,
    'purchaseDate':        purchaseDate?.toIso8601String(),
    'lastMaintenanceDate': lastMaintenanceDate.toIso8601String(),
    'divesManual':         divesManual,
  };

  factory Equipment.fromJson(Map<String, dynamic> json) => Equipment(
    id:   json['id']   as String,
    name: json['name'] as String,
    type: EquipmentType.values.firstWhere(
      (t) => t.name == (json['type'] as String? ?? ''),
      orElse: () => EquipmentType.other,
    ),
    purchaseDate: json['purchaseDate'] != null
        ? DateTime.parse(json['purchaseDate'] as String)
        : null,
    lastMaintenanceDate: DateTime.parse(json['lastMaintenanceDate'] as String),
    divesManual: (json['divesManual'] as num?)?.toInt() ?? 0,
  );
}
