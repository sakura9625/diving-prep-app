enum ItemCondition {
  always,
  stayOnly,
  wetOnly,
  dryOnly,
  boatOnly,
  wetAndBoatOnly,
  wetAndBeachOnly;

  bool isActive(bool isWet, bool isOvernight, bool isBoat) =>
      switch (this) {
        always          => true,
        stayOnly        => isOvernight,
        wetOnly         => isWet,
        dryOnly         => !isWet,
        boatOnly        => isBoat,
        wetAndBoatOnly  => isWet && isBoat,
        wetAndBeachOnly => isWet && !isBoat,
      };
}

class TemplateItem {
  final String id;
  String name;
  String genre;
  String bagName;
  final ItemCondition condition;
  bool isChecked;
  final bool isCustom;

  TemplateItem({
    required this.id,
    required this.name,
    required this.genre,
    this.bagName = '',
    this.condition = ItemCondition.always,
    this.isChecked = true,
    this.isCustom = false,
  });

  bool isNaturallyActive(bool isWet, bool isOvernight, bool isBoat) {
    if (isCustom) return true;
    switch (name) {
      // suitType == 'wet' のみ
      case '半ズボン':
      case 'Tシャツ':
      case 'ラッシュガード':
      case '水着':
      case '日焼け止め':
      case '扇子':
      case 'ウェットスーツ':
      case 'バブ':
      case '水着を着ておく':
        return isWet;
      // entryType == 'boat' のみ
      case 'アネロン（酔い止め）':
      case 'フロート':
      case 'リール':
      case 'カレントフック':
      case 'アネロンを飲む':
        return isBoat;
      // suitType == 'wet' && entryType == 'boat'
      case 'フィン（フルフットフィン）':
      case '3mmソックス':
        return isWet && isBoat;
      // suitType == 'wet' && entryType == 'beach'
      case 'フィン（ストラップフィン）':
      case 'ブーツ':
        return isWet && !isBoat;
      // suitType == 'dry' のみ
      case 'フィン（ドライ用）':
        return !isWet;
      // それ以外は condition フィールドで判定
      default:
        return condition.isActive(isWet, isOvernight, isBoat);
    }
  }
}

class SavedTemplate {
  final String id;
  String name;
  final bool isWetSuit;
  final bool isOvernight;
  final bool isBoat;
  // item.id → isChecked
  final Map<String, bool> checkStates;
  // [{id, name, genre}]
  final List<Map<String, String>> customItems;
  // item.id → bagName
  final Map<String, String> bagAssignments;

  SavedTemplate({
    required this.id,
    required this.name,
    required this.isWetSuit,
    required this.isOvernight,
    this.isBoat = true,
    this.checkStates = const {},
    this.customItems = const [],
    this.bagAssignments = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isWetSuit': isWetSuit,
    'isOvernight': isOvernight,
    'isBoat': isBoat,
    'checkStates': checkStates,
    'customItems': customItems,
    'bagAssignments': bagAssignments,
  };

  factory SavedTemplate.fromJson(Map<String, dynamic> json) => SavedTemplate(
    id: json['id'] as String,
    name: json['name'] as String,
    isWetSuit: json['isWetSuit'] as bool,
    isOvernight: json['isOvernight'] as bool,
    isBoat: (json['isBoat'] as bool?) ?? true,
    checkStates: {
      for (final e in ((json['checkStates'] as Map?) ?? {}).entries)
        e.key as String: e.value as bool,
    },
    customItems: (json['customItems'] as List? ?? [])
        .map((e) => Map<String, String>.from(e as Map))
        .toList(),
    bagAssignments: Map<String, String>.from(
        (json['bagAssignments'] as Map? ?? {})),
  );
}
