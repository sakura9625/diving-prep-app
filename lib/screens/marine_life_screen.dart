import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// --- データモデル ---
class MarineLifeItem {
  final String name;
  final String category;
  String seenLocation;
  String seenPeriod;
  bool isSeen;
  final bool isCustom;

  MarineLifeItem({
    required this.name,
    required this.category,
    this.seenLocation = '',
    this.seenPeriod = '',
    this.isSeen = false,
    this.isCustom = false,
  });
}

// --- カテゴリ一覧 ---
const List<String> _categories = [
  'すべて',
  'かわいい系',
  'ハゼ系',
  '幼魚系',
  'ハナダイ系',
  'ウミウシ系',
  '大物系',
  '体験・現象系',
];

// --- 初期データ ---
List<MarineLifeItem> _createInitialData() => [
  // かわいい系
  MarineLifeItem(name: 'テングカワハギ',         category: 'かわいい系'),
  MarineLifeItem(name: 'ニシキテグリ',           category: 'かわいい系'),
  MarineLifeItem(name: 'ハナタツ',               category: 'かわいい系'),
  MarineLifeItem(name: 'ピグミーシーホース',     category: 'かわいい系'),
  MarineLifeItem(name: 'オイランヨウジ',         category: 'かわいい系'),
  MarineLifeItem(name: 'ダンゴウオ',             category: 'かわいい系'),
  MarineLifeItem(name: 'チンアナゴ',             category: 'かわいい系'),
  MarineLifeItem(name: 'フリソデエビ',           category: 'かわいい系'),
  MarineLifeItem(name: 'ジョーフィッシュ',       category: 'かわいい系'),
  MarineLifeItem(name: 'イロカエルアンコウ',     category: 'かわいい系'),
  MarineLifeItem(name: 'クマドリカエルアンコウ', category: 'かわいい系'),
  MarineLifeItem(name: 'コケギンポ',             category: 'かわいい系'),
  MarineLifeItem(name: 'ハナイカ',               category: 'かわいい系'),

  // ハゼ系
  MarineLifeItem(name: 'アケボノハゼ',           category: 'ハゼ系'),
  MarineLifeItem(name: 'シコンハタタテハゼ',     category: 'ハゼ系'),
  MarineLifeItem(name: 'モエギハゼ',             category: 'ハゼ系'),
  MarineLifeItem(name: 'ニチリンダテハゼ',       category: 'ハゼ系'),
  MarineLifeItem(name: 'ギンガハゼ',             category: 'ハゼ系'),
  MarineLifeItem(name: 'ナカモトイロワケハゼ',   category: 'ハゼ系'),
  MarineLifeItem(name: 'ミジンベニハゼ',         category: 'ハゼ系'),
  MarineLifeItem(name: 'ホムラハゼ',             category: 'ハゼ系'),
  MarineLifeItem(name: 'ヤシャハゼ',             category: 'ハゼ系'),
  MarineLifeItem(name: 'ネジリンボウ',           category: 'ハゼ系'),
  MarineLifeItem(name: 'ヒレナガネジリンボウ',   category: 'ハゼ系'),

  // 幼魚系
  MarineLifeItem(name: 'サラサハタ',               category: '幼魚系'),
  MarineLifeItem(name: 'マダラタルミ',             category: '幼魚系'),
  MarineLifeItem(name: 'ハナヒゲウツボ',           category: '幼魚系'),
  MarineLifeItem(name: 'ミナミハコフグ',           category: '幼魚系'),
  MarineLifeItem(name: 'タテジマキンチャクダイ',   category: '幼魚系'),
  MarineLifeItem(name: 'ホホスジタルミ',           category: '幼魚系'),
  MarineLifeItem(name: 'ノコギリハギ',             category: '幼魚系'),
  MarineLifeItem(name: 'アカククリ',               category: '幼魚系'),

  // ハナダイ系
  MarineLifeItem(name: 'スジハナダイ',     category: 'ハナダイ系'),
  MarineLifeItem(name: 'アカオビハナダイ', category: 'ハナダイ系'),
  MarineLifeItem(name: 'カシワハナダイ',   category: 'ハナダイ系'),
  MarineLifeItem(name: 'ケラマハナダイ',   category: 'ハナダイ系'),
  MarineLifeItem(name: 'アサヒハナゴイ',   category: 'ハナダイ系'),
  MarineLifeItem(name: 'マダラハナダイ',   category: 'ハナダイ系'),
  MarineLifeItem(name: 'ハナゴンベ',       category: 'ハナダイ系'),

  // ウミウシ系
  MarineLifeItem(name: 'ミカドウミウシ',             category: 'ウミウシ系'),
  MarineLifeItem(name: 'ニシキウミウシ',             category: 'ウミウシ系'),
  MarineLifeItem(name: 'クロスジリュウグウウミウシ', category: 'ウミウシ系'),
  MarineLifeItem(name: 'ゾウゲイロウミウシ',         category: 'ウミウシ系'),
  MarineLifeItem(name: 'アオウミウシ',               category: 'ウミウシ系'),

  // 大物系
  MarineLifeItem(name: 'マンタ',         category: '大物系'),
  MarineLifeItem(name: 'ジンベエザメ',   category: '大物系'),
  MarineLifeItem(name: 'ウミガメ',       category: '大物系'),
  MarineLifeItem(name: 'ナポレオン',     category: '大物系'),
  MarineLifeItem(name: 'ギンガメアジ',   category: '大物系'),
  MarineLifeItem(name: 'バラクーダ',     category: '大物系'),
  MarineLifeItem(name: 'イルカ',         category: '大物系'),
  MarineLifeItem(name: 'トド',           category: '大物系'),
  MarineLifeItem(name: 'マダラトビエイ', category: '大物系'),

  // 体験・現象系
  MarineLifeItem(name: '夜光虫',                 category: '体験・現象系'),
  MarineLifeItem(name: 'イワシトルネード',       category: '体験・現象系'),
  MarineLifeItem(name: 'クリーニングステーション', category: '体験・現象系'),
  MarineLifeItem(name: '奄美ミステリーサークル', category: '体験・現象系'),
  MarineLifeItem(name: 'ナイトダイビング',       category: '体験・現象系'),
  MarineLifeItem(name: 'レイクダイビング',       category: '体験・現象系'),
];

// --- カテゴリ別カラー ---
Color _categoryColor(String category) {
  switch (category) {
    case 'かわいい系':   return const Color(0xFFFF8FAB);
    case 'ハゼ系':       return const Color(0xFF5B9BD5);
    case '幼魚系':       return const Color(0xFF70C56A);
    case 'ハナダイ系':   return const Color(0xFFD97BCA);
    case 'ウミウシ系':   return const Color(0xFF5BBAD5);
    case '大物系':       return const Color(0xFFE57373);
    case '体験・現象系': return const Color(0xFF9E9E9E);
    default:             return const Color(0xFF005F8A);
  }
}

// --- 画面ウィジェット ---
class MarineLifeScreen extends StatefulWidget {
  const MarineLifeScreen({super.key});

  @override
  State<MarineLifeScreen> createState() => _MarineLifeScreenState();
}

class _MarineLifeScreenState extends State<MarineLifeScreen> {
  final _db = FirebaseFirestore.instance;

  List<MarineLifeItem> _items = [];
  String _selectedCategory = 'すべて';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ─── 永続化 ──────────────────────────────────────

  Future<void> _loadData() async {
    Map<String, dynamic> stateMap = {};
    List<dynamic> customList = [];

    try {
      final results = await Future.wait([
        _db.collection('marineLife').doc('state').get(),
        _db.collection('marineLife').doc('custom').get(),
      ]);
      final stateDoc  = results[0];
      final customDoc = results[1];
      if (stateDoc.exists) {
        stateMap = (stateDoc.data()!['data'] as Map<String, dynamic>?) ?? {};
      }
      if (customDoc.exists) {
        customList = (customDoc.data()!['items'] as List?) ?? [];
      }
    } catch (_) {}

    final items = _createInitialData();
    for (final item in items) {
      _applyState(item, stateMap);
    }

    for (final e in customList) {
      final item = MarineLifeItem(
        name:     e['name']     as String,
        category: e['category'] as String,
        isCustom: true,
      );
      _applyState(item, stateMap);
      items.add(item);
    }

    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  void _applyState(MarineLifeItem item, Map<String, dynamic> stateMap) {
    final s = stateMap['${item.category}:${item.name}'] as Map<String, dynamic>?;
    if (s == null) return;
    item.isSeen       = (s['isSeen']       as bool?)   ?? false;
    item.seenLocation = (s['seenLocation'] as String?) ?? '';
    item.seenPeriod   = (s['seenPeriod']   as String?) ?? '';
  }

  Future<void> _saveData() async {
    final stateMap = <String, dynamic>{};
    for (final item in _items) {
      stateMap['${item.category}:${item.name}'] = {
        'isSeen':       item.isSeen,
        'seenLocation': item.seenLocation,
        'seenPeriod':   item.seenPeriod,
      };
    }

    final customList = _items
        .where((e) => e.isCustom)
        .map((e) => {'name': e.name, 'category': e.category})
        .toList();

    await Future.wait([
      _db.collection('marineLife').doc('state').set({'data': stateMap}),
      _db.collection('marineLife').doc('custom').set({'items': customList}),
    ]);
  }

  // ─── 操作 ────────────────────────────────────────

  List<String> get _visibleCategories {
    if (_selectedCategory == 'すべて') {
      return _categories.where((c) => c != 'すべて').toList();
    }
    return [_selectedCategory];
  }

  List<MarineLifeItem> _itemsFor(String category) =>
      _items.where((e) => e.category == category).toList();

  void _toggleSeen(MarineLifeItem item, bool? val) {
    setState(() => item.isSeen = val ?? false);
    _saveData();
  }

  void _showEditDialog(MarineLifeItem item) {
    final locationCtrl = TextEditingController(text: item.seenLocation);
    final periodCtrl   = TextEditingController(text: item.seenPeriod);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: locationCtrl,
              decoration: const InputDecoration(
                labelText: '見た場所',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: periodCtrl,
              decoration: const InputDecoration(
                labelText: '見た時期',
                prefixIcon: Icon(Icons.calendar_today_outlined),
                hintText: '例：2025年3月',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                item.seenLocation = locationCtrl.text.trim();
                item.seenPeriod   = periodCtrl.text.trim();
              });
              _saveData();
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddItemDialog(String category) async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$category に追加'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '生物名',
            border: OutlineInputBorder(),
            hintText: '例：カクレクマノミ',
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final n = nameCtrl.text.trim();
              if (n.isEmpty) return;
              Navigator.pop(ctx, n);
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    if (name == null || !mounted) return;
    setState(() {
      _items.add(MarineLifeItem(name: name, category: category, isCustom: true));
    });
    await _saveData();
  }

  Future<void> _deleteItem(MarineLifeItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('生物を削除'),
        content: Text('「${item.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _items.remove(item));
    await _saveData();
  }

  // ─── build ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final allVisible = _items.where(
      (e) => _selectedCategory == 'すべて' || e.category == _selectedCategory,
    );
    final totalSeen  = allVisible.where((e) => e.isSeen).length;
    final totalCount = allVisible.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('見たい生物'),
      ),
      body: Column(
        children: [
          // カテゴリフィルター
          SizedBox(
            height: 58,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat      = _categories[i];
                final selected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat, style: const TextStyle(fontSize: 13)),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = cat),
                    selectedColor: Theme.of(context).colorScheme.primaryContainer,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  ),
                );
              },
            ),
          ),

          // 発見数サマリー
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                Text(
                  '$totalSeen／$totalCount 種を発見済み',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // アコーディオンリスト
          Expanded(
            child: ListView(
              children: _visibleCategories.map((cat) {
                final catItems = _itemsFor(cat);
                final catSeen  = catItems.where((e) => e.isSeen).length;
                final catColor = _categoryColor(cat);

                return ExpansionTile(
                  key: ValueKey('$cat:$_selectedCategory'),
                  initiallyExpanded: _selectedCategory == cat,
                  leading: CircleAvatar(radius: 8, backgroundColor: catColor),
                  title: Row(
                    children: [
                      Text(cat,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(width: 8),
                      Text(
                        '$catSeen／${catItems.length}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  children: [
                    ...catItems.map((item) => Column(
                          children: [
                            _MarineLifeTile(
                              item: item,
                              onToggle: (val) => _toggleSeen(item, val),
                              onTap: () => _showEditDialog(item),
                              onLongPress: item.isCustom
                                  ? () => _deleteItem(item)
                                  : null,
                            ),
                            const Divider(height: 1, indent: 68),
                          ],
                        )),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: TextButton.icon(
                        onPressed: () => _showAddItemDialog(cat),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('生物を追加'),
                        style: TextButton.styleFrom(
                          foregroundColor: catColor,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// --- リストタイル ---
class _MarineLifeTile extends StatelessWidget {
  const _MarineLifeTile({
    required this.item,
    required this.onToggle,
    required this.onTap,
    this.onLongPress,
  });

  final MarineLifeItem item;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final catColor = _categoryColor(item.category);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 44,
              child: Checkbox(
                value: item.isSeen,
                onChanged: onToggle,
                activeColor: Theme.of(context).colorScheme.primary,
              ),
            ),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.15),
                          border: Border.all(color: catColor, width: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 10,
                            color: catColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: item.isSeen ? Colors.grey[400] : null,
                            decoration: item.isSeen
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      if (item.isSeen)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.check_circle,
                              size: 20, color: Colors.green[600]),
                        ),
                      if (item.isCustom)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Tooltip(
                            message: '長押しで削除',
                            child: Icon(Icons.touch_app,
                                size: 14, color: Colors.grey[400]),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.place_outlined,
                          size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 2),
                      Text(
                        item.seenLocation.isEmpty
                            ? '場所を記録'
                            : item.seenLocation,
                        style: TextStyle(
                          fontSize: 12,
                          color: item.seenLocation.isEmpty
                              ? Colors.grey[400]
                              : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Icon(Icons.calendar_today_outlined,
                          size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 2),
                      Text(
                        item.seenPeriod.isEmpty ? '時期を記録' : item.seenPeriod,
                        style: TextStyle(
                          fontSize: 12,
                          color: item.seenPeriod.isEmpty
                              ? Colors.grey[400]
                              : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Icon(Icons.edit_outlined, size: 16, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}
