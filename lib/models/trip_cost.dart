import 'package:flutter/material.dart';

enum TransportMode {
  plane, train, taxi, boat, bus;

  String get label => switch (this) {
    plane => '飛行機', train => '電車', taxi => 'タクシー',
    boat  => '船',     bus   => 'バス',
  };

  IconData get icon => switch (this) {
    plane => Icons.flight,           train => Icons.train,
    taxi  => Icons.local_taxi,       boat  => Icons.directions_boat,
    bus   => Icons.directions_bus,
  };
}

class TransportLeg {
  String direction;
  TransportMode mode;
  int amount;

  TransportLeg({
    required this.direction,
    this.mode = TransportMode.plane,
    this.amount = 0,
  });

  Map<String, dynamic> toJson() => {
    'direction': direction,
    'mode': mode.name,
    'amount': amount,
  };

  factory TransportLeg.fromJson(Map<String, dynamic> json) => TransportLeg(
    direction: json['direction'] as String,
    mode: TransportMode.values.firstWhere(
      (m) => m.name == (json['mode'] as String? ?? ''),
      orElse: () => TransportMode.plane,
    ),
    amount: (json['amount'] as num?)?.toInt() ?? 0,
  );
}

class TripCostData {
  int diveCount;
  int diveCost;
  int accommodation;
  List<TransportLeg> legs;

  TripCostData({
    this.diveCount = 0,
    this.diveCost  = 0,
    this.accommodation = 0,
    List<TransportLeg>? legs,
  }) : legs = legs ?? [];

  int get transportTotal => legs.fold(0, (s, l) => s + l.amount);
  int get totalCost => diveCost + accommodation + transportTotal;

  Map<String, dynamic> toJson() => {
    'diveCount':     diveCount,
    'diveCost':      diveCost,
    'accommodation': accommodation,
    'legs': legs.map((l) => l.toJson()).toList(),
  };

  factory TripCostData.fromJson(Map<String, dynamic> json) => TripCostData(
    diveCount:     (json['diveCount']     as num?)?.toInt() ?? 0,
    diveCost:      (json['diveCost']      as num?)?.toInt() ?? 0,
    accommodation: (json['accommodation'] as num?)?.toInt() ?? 0,
    legs: (json['legs'] as List? ?? [])
        .map((e) => TransportLeg.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
