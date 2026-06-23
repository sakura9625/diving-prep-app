import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/template_item.dart';
import '../models/trip.dart';
import '../models/trip_cost.dart';
import '../services/user_service.dart';
import '../utils/checklist_data.dart';
import '../widgets/sky_card.dart';

// ─── 画面 ─────────────────────────────────────────────────────────────────────

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({
    super.key,
    required this.trip,
    this.onTripUpdated,
  });
  final Trip trip;
  final VoidCallback? onTripUpdated;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  String? _userId;

  // チェックリスト
  Map<String, List<TemplateItem>> _genreItems = {};
  bool _isBoat      = true;
  bool _isLoading   = true;
  bool _hasTemplate = false;
  String _bagFilter = 'すべて';
  List<String> _customBags = [];

  // コスト
  TripCostData _cost = TripCostData();
  late final TextEditingController _diveCountCtrl;
  late final TextEditingController _diveCostCtrl;
  late final TextEditingController _accommodationCtrl;
  final _legAmountCtrls = <TextEditingController>[];

  // タブ
  late TabController _tabController;

  bool get _isWet       => widget.trip.suitType == SuitType.wet;
  bool get _isOvernight => widget.trip.isOvernight;

  @override
  void initState() {
    super.initState();
    _tabController     = TabController(length: 2, vsync: this);
    _diveCountCtrl     = TextEditingController();
    _diveCostCtrl      = TextEditingController();
    _accommodationCtrl = TextEditingController();
    _initUser();
  }

  Future<void> _initUser() async {
    _userId = await UserService.getUserId();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _diveCountCtrl.dispose();
    _diveCostCtrl.dispose();
    _accommodationCtrl.dispose();
    for (final c in _legAmountCtrls) { c.dispose(); }
    super.dispose();
  }

  // ─── データ読み込み ───────────────────────────────

  Future<void> _loadData({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);

    // チェックリスト・コストを並列読み込み
    final results = await Future.wait([
      _db.collection('templates').get(),
      _db.collection('checks').doc(widget.trip.id).get(),
      _db.collection('costs').doc(widget.trip.id).get(),
    ]);

    final templatesSnapshot = results[0] as QuerySnapshot;
    final checksDoc         = results[1] as DocumentSnapshot;
    final costDoc           = results[2] as DocumentSnapshot;

    // ── チェックリスト ──
    Map<String, List<TemplateItem>> genreItems = {};
    bool hasTemplate = false;
    bool isBoat = true;

    if (widget.trip.templateName != null) {
      SavedTemplate? template;
      final matches = templatesSnapshot.docs
          .map((d) => SavedTemplate.fromJson(d.data() as Map<String, dynamic>))
          .where((t) => t.name == widget.trip.templateName)
          .toList();
      if (matches.isNotEmpty) template = matches.first;

      if (template != null) {
        genreItems = createInitialGenreItems();
        for (final items in genreItems.values) {
          for (final item in items) {
            item.isChecked = false;
          }
        }
        for (final ci in template.customItems) {
          final genre = ci['genre']!;
          if (genreItems.containsKey(genre)) {
            genreItems[genre]!.add(TemplateItem(
              id: ci['id']!,
              name: ci['name']!,
              genre: genre,
              isCustom: true,
              isChecked: false,
            ));
          }
        }

        if (checksDoc.exists) {
          final saved =
              (checksDoc.data()! as Map<String, dynamic>)['data']
                  as Map<String, dynamic>? ?? {};
          for (final items in genreItems.values) {
            for (final item in items) {
              if (saved.containsKey(item.id)) {
                item.isChecked = saved[item.id] as bool;
              }
            }
          }
        }

        isBoat = template.isBoat;
        hasTemplate = true;
      }
    }

    // ── バッグ割り当て ──
    List<String> customBags = [];
    try {
      final bagsDoc = await _db
          .collection('users').doc(_userId)
          .collection('settings').doc('bags')
          .get();
      if (bagsDoc.exists) {
        final data = bagsDoc.data()!;
        final bagMap = Map<String, String>.from(
            (data['bagAssignments'] as Map? ?? {}));
        for (final items in genreItems.values) {
          for (final item in items) {
            if (bagMap.containsKey(item.id)) {
              item.bagName = bagMap[item.id]!;
            }
          }
        }
        customBags = List<String>.from(
            (data['customBagNames'] as List? ?? []));
      }
    } catch (_) {}

    // ── コスト ──
    for (final c in _legAmountCtrls) { c.dispose(); }
    _legAmountCtrls.clear();

    TripCostData cost = TripCostData();
    if (costDoc.exists) {
      try {
        cost = TripCostData.fromJson(costDoc.data()! as Map<String, dynamic>);
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      _genreItems  = genreItems;
      _isBoat      = isBoat;
      _hasTemplate = hasTemplate;
      _cost        = cost;
      _customBags  = customBags;
      _isLoading   = false;
    });

    if (cost.diveCount > 0)     _diveCountCtrl.text     = cost.diveCount.toString();
    if (cost.diveCost > 0)      _diveCostCtrl.text      = cost.diveCost.toString();
    if (cost.accommodation > 0) _accommodationCtrl.text = cost.accommodation.toString();
    for (final leg in cost.legs) {
      _legAmountCtrls.add(TextEditingController(
        text: leg.amount > 0 ? leg.amount.toString() : '',
      ));
    }
  }

  // ─── チェックリスト操作 ──────────────────────────

  Future<void> _toggleItem(TemplateItem item) async {
    setState(() => item.isChecked = !item.isChecked);
    final allChecks = <String, bool>{};
    for (final items in _genreItems.values) {
      for (final i in items) { allChecks[i.id] = i.isChecked; }
    }
    await _db.collection('checks').doc(widget.trip.id)
        .set({'data': allChecks});
  }

  // ─── コスト操作 ──────────────────────────────────

  Future<void> _saveCost() async {
    await _db.collection('costs').doc(widget.trip.id).set(_cost.toJson());
  }

  void _addLeg(String direction) {
    setState(() {
      _cost.legs.add(TransportLeg(direction: direction));
      _legAmountCtrls.add(TextEditingController());
    });
    _saveCost();
  }

  void _removeLeg(int index) {
    _legAmountCtrls[index].dispose();
    setState(() {
      _cost.legs.removeAt(index);
      _legAmountCtrls.removeAt(index);
    });
    _saveCost();
  }

  // ─── 編集ダイアログ ──────────────────────────────

  Future<void> _showEditDialog() async {
    List<SavedTemplate> templates = [];
    List<String> locationHistory = [];
    List<String> shopHistory = [];

    try {
      final results = await Future.wait([
        _db.collection('templates').get(),
        _db.collection('history').doc('locations').get(),
        _db.collection('history').doc('shops').get(),
      ]);
      templates = (results[0] as QuerySnapshot).docs
          .map((d) => SavedTemplate.fromJson(d.data() as Map<String, dynamic>))
          .toList();
      final locsDoc = results[1] as DocumentSnapshot;
      if (locsDoc.exists) {
        locationHistory = List<String>.from(
            (locsDoc.data()! as Map<String, dynamic>)['items'] as List? ?? []);
      }
      final shopsDoc = results[2] as DocumentSnapshot;
      if (shopsDoc.exists) {
        shopHistory = List<String>.from(
            (shopsDoc.data()! as Map<String, dynamic>)['items'] as List? ?? []);
      }
    } catch (_) {}

    if (!mounted) return;

    String? editTemplateName = widget.trip.templateName;
    DateTime editDate        = widget.trip.date;
    SuitType editSuitType    = widget.trip.suitType;
    bool editOvernight       = widget.trip.isOvernight;
    final nameCtrl           = TextEditingController(text: widget.trip.name);
    final locationCtrl       = TextEditingController(text: widget.trip.location ?? '');
    final shopCtrl           = TextEditingController(text: widget.trip.shopName ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: const Text('旅行を編集'),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '旅行名',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                _HistorySuggestField(
                  ctrl: locationCtrl,
                  label: '場所（任意）',
                  hint: '例：沖縄・慶良間',
                  history: locationHistory,
                ),
                const SizedBox(height: 14),

                _HistorySuggestField(
                  ctrl: shopCtrl,
                  label: 'ショップ名（任意）',
                  hint: '例：〇〇ダイビングサービス',
                  history: shopHistory,
                ),
                const SizedBox(height: 20),

                const Text(
                  '準備リストテンプレート',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButton<String?>(
                    value: editTemplateName,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('テンプレートなし'),
                      ),
                      for (final t in templates)
                        DropdownMenuItem<String?>(
                          value: t.name,
                          child: Text(
                            '${t.name}  ·  '
                            '${t.isWetSuit ? "ウェット" : "ドライ"} · '
                            '${t.isOvernight ? "宿泊" : "日帰り"} · '
                            '${t.isBoat ? "ボート" : "ビーチ"}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (val) {
                      setDs(() {
                        editTemplateName = val;
                        if (val != null) {
                          final t = templates.firstWhere((t) => t.name == val);
                          editSuitType =
                              t.isWetSuit ? SuitType.wet : SuitType.dry;
                          editOvernight = t.isOvernight;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  '旅行開始日',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: editDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      locale: const Locale('ja', 'JP'),
                    );
                    if (picked != null) setDs(() => editDate = picked);
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 18,
                            color: Theme.of(ctx).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          '${editDate.year}年'
                          '${editDate.month}月'
                          '${editDate.day}日',
                        ),
                        const Spacer(),
                        Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'スーツ種類',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                SegmentedButton<SuitType>(
                  segments: const [
                    ButtonSegment(
                      value: SuitType.wet,
                      label: Text('ウェット'),
                      icon: Icon(Icons.waves),
                    ),
                    ButtonSegment(
                      value: SuitType.dry,
                      label: Text('ドライ'),
                      icon: Icon(Icons.ac_unit),
                    ),
                  ],
                  selected: {editSuitType},
                  onSelectionChanged: (val) =>
                      setDs(() => editSuitType = val.first),
                ),
                const SizedBox(height: 20),

                const Text(
                  '日程',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('日帰り'),
                      icon: Icon(Icons.wb_sunny_outlined),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('宿泊'),
                      icon: Icon(Icons.hotel),
                    ),
                  ],
                  selected: {editOvernight},
                  onSelectionChanged: (val) =>
                      setDs(() => editOvernight = val.first),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    ).then((saved) async {
      if (saved != true) {
        nameCtrl.dispose();
        locationCtrl.dispose();
        shopCtrl.dispose();
        return;
      }

      final newName     = nameCtrl.text.trim();
      final newLocation = locationCtrl.text.trim().isEmpty
          ? null
          : locationCtrl.text.trim();
      final newShop     = shopCtrl.text.trim().isEmpty
          ? null
          : shopCtrl.text.trim();

      nameCtrl.dispose();
      locationCtrl.dispose();
      shopCtrl.dispose();

      widget.trip.name         = newName;
      widget.trip.date         = editDate;
      widget.trip.suitType     = editSuitType;
      widget.trip.isOvernight  = editOvernight;
      widget.trip.templateName = editTemplateName;
      widget.trip.location     = newLocation;
      widget.trip.shopName     = newShop;

      await Future.wait([
        _saveHistoryItem(newLocation, locationHistory, 'locations'),
        _saveHistoryItem(newShop, shopHistory, 'shops'),
      ]);

      if (!mounted) return;
      widget.onTripUpdated?.call();
      _loadData(silent: true);
    });
  }

  Future<void> _saveHistoryItem(
    String? value,
    List<String> list,
    String docId,
  ) async {
    if (value == null || value.isEmpty || list.contains(value)) return;
    list.insert(0, value);
    await _db.collection('history').doc(docId).set({'items': list});
  }

  // ─── ヘルパー ─────────────────────────────────────

  String _formatYen(int amount) {
    if (amount <= 0) return '¥0';
    final s = amount.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '¥$buf';
  }

  // ─── build ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    final allItems = _hasTemplate
        ? _genreItems.values.expand((l) => l).toList()
        : <TemplateItem>[];
    final activeItems = allItems
        .where((e) => e.isNaturallyActive(_isWet, _isOvernight, _isBoat))
        .toList();
    final checkedCount = activeItems.where((e) => e.isChecked).length;
    final progress     = activeItems.isEmpty ? 0.0 : checkedCount / activeItems.length;
    final allDone      = activeItems.isNotEmpty && checkedCount == activeItems.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trip.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF6B8FA0)),
            tooltip: '編集',
            onPressed: _showEditDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1A3A4A),
          unselectedLabelColor: const Color(0xFF6B8FA0),
          indicatorColor: const Color(0xFF4EC8E8),
          tabs: const [
            Tab(text: 'チェックリスト'),
            Tab(text: 'コスト管理'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildChecklistTab(
                  primary: primary,
                  checkedCount: checkedCount,
                  activeItems: activeItems,
                  progress: progress,
                  allDone: allDone,
                ),
                _buildCostTab(primary),
              ],
            ),
    );
  }

  // ─── チェックリストタブ ───────────────────────────

  Widget _buildChecklistTab({
    required Color primary,
    required int checkedCount,
    required List<TemplateItem> activeItems,
    required double progress,
    required bool allDone,
  }) {
    return Column(
      children: [
        if (_hasTemplate)
          _ProgressBar(
            checked: checkedCount,
            total: activeItems.length,
            progress: progress,
          ),
        Expanded(
          child: Material(color: const Color(0xFFF9FEFF), child: ListView(
            children: [
              SkyCard(
                title: widget.trip.name,
                subtitle: [
                  '${widget.trip.date.year}年${widget.trip.date.month}月${widget.trip.date.day}日',
                  if (widget.trip.location != null) widget.trip.location!,
                ].join(' · '),
                emoji: '🤿',
              ),
              _buildInfoCard(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    const Icon(Icons.checklist, size: 18, color: Color(0xFF4EC8E8)),
                    const SizedBox(width: 6),
                    const Text(
                      '準備リスト',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A3A4A)),
                    ),
                  ],
                ),
              ),
              if (_hasTemplate) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Row(
                    children: ['すべて', 'メッシュバッグ', 'バックパック', '旅行ケース', ..._customBags, '未設定'].map((f) {
                      final sel = _bagFilter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _bagFilter = f),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: sel ? const Color(0xFF4EC8E8) : const Color(0xFFF0FAFE),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFE8F8FC)),
                            ),
                            child: Text(f, style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : const Color(0xFF4EC8E8),
                            )),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                ...genreOrder
                    .where((g) => (_genreItems[g]?.isNotEmpty ?? false))
                    .map((g) => _buildGenreSection(g)),
              ] else
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.checklist, size: 52, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          'テンプレートが選択されていません',
                          style: TextStyle(color: Colors.grey[500], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 32),
            ],
          )),
        ),
      ],
    );
  }

  // ─── コストタブ ───────────────────────────────────

  Widget _buildCostTab(Color primary) {
    return ListView(
      children: [
        _buildCostSection(primary),
        const SizedBox(height: 32),
      ],
    );
  }

  // ─── 旅行情報カード ───────────────────────────────

  Widget _buildInfoCard() {
    final t = widget.trip;
    final d = t.date;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow(
                icon: Icons.calendar_today,
                label: '日付',
                value: '${d.year}年${d.month}月${d.day}日',
              ),
              if (t.location != null) ...[
                const Divider(height: 1),
                _DetailRow(
                  icon: Icons.place_outlined,
                  label: '場所',
                  value: t.location!,
                ),
              ],
              if (t.shopName != null) ...[
                const Divider(height: 1),
                _DetailRow(
                  icon: Icons.store_outlined,
                  label: 'ショップ',
                  value: t.shopName!,
                ),
              ],
              const Divider(height: 1),
              _DetailRow(
                icon: Icons.waves,
                label: 'スーツ種類',
                value: t.suitType == SuitType.wet ? 'ウェットスーツ' : 'ドライスーツ',
              ),
              const Divider(height: 1),
              _DetailRow(
                icon: Icons.hotel,
                label: '日程',
                value: t.isOvernight ? '宿泊' : '日帰り',
              ),
              const Divider(height: 1),
              _DetailRow(
                icon: Icons.checklist,
                label: 'テンプレート',
                value: t.templateName ?? 'なし',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── チェックリストセクション ─────────────────────

  Widget _buildGenreSection(String genre) {
    final allItems = _genreItems[genre] ?? [];
    final color    = genreColor(genre);

    final displayItems = _bagFilter == 'すべて'
        ? allItems
        : _bagFilter == '未設定'
            ? allItems.where((e) => e.bagName.isEmpty).toList()
            : allItems.where((e) => e.bagName == _bagFilter).toList();

    if (displayItems.isEmpty) return const SizedBox.shrink();

    final activeList = allItems
        .where((e) => e.isNaturallyActive(_isWet, _isOvernight, _isBoat))
        .toList();
    final checked    = activeList.where((e) => e.isChecked).length;
    final sectionDone =
        activeList.isNotEmpty && checked == activeList.length;

    return ExpansionTile(
      initiallyExpanded: true,
      leading: CircleAvatar(radius: 8, backgroundColor: color),
      title: Row(
        children: [
          Text(genre,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(width: 8),
          Text(
            '$checked/${allItems.length}',
            style: TextStyle(
              fontSize: 12,
              color: sectionDone ? Colors.green[700] : Colors.grey[500],
              fontWeight: sectionDone ? FontWeight.w700 : null,
            ),
          ),
        ],
      ),
      children: displayItems.map((item) => _buildItemRow(item, color)).toList(),
    );
  }

  Widget _buildItemRow(TemplateItem item, Color color) {
    final isActive = item.isChecked || item.isNaturallyActive(_isWet, _isOvernight, _isBoat);
    final textColor = isActive ? const Color(0xFF1A3A4A) : const Color(0xFFB0CDD5);
    final borderColor = isActive ? color : const Color(0xFFE8F8FC);
    final bgColor = item.isChecked ? color.withValues(alpha: 0.12) : Colors.white;
    final circleColor = isActive ? color : const Color(0xFFE8F8FC);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onTap: () => _toggleItem(item),
        child: Container(
          margin: const EdgeInsets.only(bottom: 5),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(children: [
            Container(
              width: 16, height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.isChecked ? color : Colors.transparent,
                border: Border.all(color: circleColor, width: 1.5),
              ),
              child: item.isChecked
                ? const Icon(Icons.check, size: 10, color: Colors.white)
                : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(item.name,
                style: TextStyle(fontSize: 12, color: textColor)),
            ),
            if (item.bagName.isNotEmpty)
              Text(item.bagName,
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B8FA0))),
          ]),
        ),
      ),
    );
  }

  // ─── コストセクション ────────────────────────────

  Widget _buildCostSection(Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.attach_money, size: 20, color: primary),
              const SizedBox(width: 6),
              Text(
                'コスト',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  _CostField(
                    label: 'ダイブ本数',
                    controller: _diveCountCtrl,
                    suffix: '本',
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      setState(() => _cost.diveCount = int.tryParse(v) ?? 0);
                      _saveCost();
                    },
                  ),
                  const Divider(height: 16),
                  _CostField(
                    label: 'ダイブ費',
                    controller: _diveCostCtrl,
                    suffix: '円',
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      setState(() => _cost.diveCost = int.tryParse(v) ?? 0);
                      _saveCost();
                    },
                  ),
                  const Divider(height: 16),
                  _CostField(
                    label: '宿泊費',
                    controller: _accommodationCtrl,
                    suffix: '円',
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      setState(
                          () => _cost.accommodation = int.tryParse(v) ?? 0);
                      _saveCost();
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Text(
            '交通費',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < _cost.legs.length; i++) ...[
            _buildLegCard(i),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _addLeg('往路'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('往路を追加'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4EC8E8),
                  side: const BorderSide(color: Color(0xFF4EC8E8)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _addLeg('復路'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('復路を追加'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFA78BFA),
                  side: const BorderSide(color: Color(0xFFA78BFA)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          _buildCostSummary(primary),
        ],
      ),
    );
  }

  Widget _buildLegCard(int i) {
    final leg = _cost.legs[i];
    final isOutbound = leg.direction == '往路';
    final dirColor =
        isOutbound ? const Color(0xFF4EC8E8) : const Color(0xFFA78BFA);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: dirColor.withValues(alpha: 0.1),
                border: Border.all(color: dirColor, width: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                leg.direction,
                style: TextStyle(
                    fontSize: 11,
                    color: dirColor,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            DropdownButton<TransportMode>(
              value: leg.mode,
              underline: const SizedBox(),
              isDense: true,
              items: TransportMode.values
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(m.icon, size: 15, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(m.label,
                                style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (m) {
                if (m != null) {
                  setState(() => leg.mode = m);
                  _saveCost();
                }
              },
            ),
            const Spacer(),
            SizedBox(
              width: 110,
              child: TextField(
                controller: _legAmountCtrls[i],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  isDense: true,
                  prefixText: '¥',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                onChanged: (v) {
                  setState(() => leg.amount = int.tryParse(v) ?? 0);
                  _saveCost();
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: Colors.grey[400],
              onPressed: () => _removeLeg(i),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostSummary(Color primary) {
    final transportTotal = _cost.transportTotal;
    final totalCost      = _cost.totalCost;
    final diveCount      = _cost.diveCount;
    final costPerDive =
        diveCount > 0 ? (totalCost / diveCount).round() : null;

    return Card(
      color: const Color(0xFF4EC8E8).withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
            color: Color(0xFF4EC8E8), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _SummaryRow(
              label: '交通費合計',
              value: _formatYen(transportTotal),
              color: Colors.grey[700]!,
            ),
            const Divider(height: 16),
            _SummaryRow(
              label: '合計コスト',
              value: _formatYen(totalCost),
              color: primary,
              bold: true,
            ),
            if (costPerDive != null) ...[
              const Divider(height: 16),
              _SummaryRow(
                label: 'ダイブ単価',
                value: '${_formatYen(costPerDive)} / 本',
                color: Colors.deepOrange[700]!,
                bold: true,
              ),
            ] else if (totalCost > 0) ...[
              const Divider(height: 16),
              Row(
                children: [
                  Text(
                    'ダイブ単価',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Text(
                    'ダイブ本数を入力してください',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── 進捗バー ─────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.checked,
    required this.total,
    required this.progress,
  });
  final int checked;
  final int total;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF4EC8E8)),
                const SizedBox(width: 4),
                const Text('準備状況', style: TextStyle(fontSize: 11, color: Color(0xFF4EC8E8), fontWeight: FontWeight.w600)),
              ]),
              Text('$checked / $total 項目',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1A3A4A))),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 24,
              backgroundColor: const Color(0xFFE8F8FC),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD233)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 情報行 ───────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── コスト入力フィールド ─────────────────────────────────────────────────────

class _CostField extends StatelessWidget {
  const _CostField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.suffix = '円',
    this.keyboardType = TextInputType.number,
  });
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String suffix;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(label,
              style: TextStyle(fontSize: 14, color: Colors.grey[700])),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              isDense: true,
              suffixText: suffix,
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ─── サマリー行 ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });
  final String label;
  final String value;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── 履歴付き入力フィールド ───────────────────────────────────────────────────

class _HistorySuggestField extends StatelessWidget {
  const _HistorySuggestField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.history,
  });
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final List<String> history;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        suffixIcon: history.isEmpty
            ? null
            : PopupMenuButton<String>(
                icon: Icon(Icons.history, size: 20, color: Colors.grey[600]),
                tooltip: '履歴から選択',
                onSelected: (val) => ctrl.text = val,
                itemBuilder: (_) => history
                    .map((s) => PopupMenuItem(value: s, child: Text(s)))
                    .toList(),
              ),
      ),
    );
  }
}
