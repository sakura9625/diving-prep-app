enum SuitType { wet, dry }

class Trip {
  final String id;
  String name;
  DateTime date;
  SuitType suitType;
  bool isOvernight;
  String? templateName;
  String? location;
  String? shopName;

  Trip({
    required this.id,
    required this.name,
    required this.date,
    this.suitType = SuitType.wet,
    this.isOvernight = false,
    this.templateName,
    this.location,
    this.shopName,
  });

  Map<String, dynamic> toJson() => {
    'id':           id,
    'name':         name,
    'date':         date.toIso8601String(),
    'suitType':     suitType.name,
    'isOvernight':  isOvernight,
    'templateName': templateName,
    'location':     location,
    'shopName':     shopName,
  };

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
    id: json['id'] as String,
    name: json['name'] as String,
    date: DateTime.parse(json['date'] as String),
    suitType: SuitType.values.firstWhere(
      (s) => s.name == (json['suitType'] as String? ?? 'wet'),
      orElse: () => SuitType.wet,
    ),
    isOvernight: (json['isOvernight'] as bool?) ?? false,
    templateName: json['templateName'] as String?,
    location: json['location'] as String?,
    shopName: json['shopName'] as String?,
  );
}
