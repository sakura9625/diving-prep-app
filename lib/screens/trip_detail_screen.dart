import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/template_item.dart';
import '../models/trip.dart';
import '../models/trip_cost.dart';
import '../utils/checklist_data.dart';

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
  // チェックリスト
  Map<String, List<TemplateItem>> _genreItems = {};
  bool _isBoat     = true;
  bool _isLoading  = true;
  bool _hasTemplate = false;

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
  String get _checksKey => 'trip_${widget.trip.id}_checks';
  String get _costKey   => 'trip_${widget.trip.id}_cost';

  @override
  void initState() {
    super.initState();
    _tabController     = TabController(length: 2, vsync: this);
    _diveCountCtrl     = TextEditingController();
    _diveCostCtrl      = TextEditingController();
    _accommodationCtrl = TextEditingController();
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
    final prefs = await SharedPreferences.getInstance();

    // ── チェックリスト ──
    Map<String, List<TemplateItem>> genreItems = {};
    bool hasTemplate = false;
    bool isBoat = true;

    if (widget.trip.templateName != null) {
      SavedTemplate? template;
      final raw = prefs.getString('saved_templates');
      if (raw != null) {
        try {
          final List data = jsonDecode(raw) as List;
          final matches = data
              .map((e) => SavedTemplate.fromJson(e as Map<String, dynamic>))
              .where((t) => t.name == widget.trip.templateName)
              .toList();
          if (matches.isNotEmpty) template = matches.first;
        } catch (_) {}
      }

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

        final tripChecksRaw = prefs.getString(_checksKey);
        if (tripChecksRaw != null) {
          try {
            final Map<String, dynamic> saved =
                jsonDecode(tripChecksRaw) as Map<String, dynamic>;
            for (final items in genreItems.values) {
              for (final item in items) {
                if (saved.containsKey(item.id)) {
                  item.isChecked = saved[item.id] as bool;
                }
              }
            }
          } catch (_) {}
        }

        isBoat = template.isBoat;
        hasTemplate = true;
      }
    }

    // ── コスト（再ロード時はコントローラーをリセット）──
    for (final c in _legAmountCtrls) { c.dispose(); }
    _legAmountCtrls.clear();

    TripCostData cost = TripCostData();
    final costRaw = prefs.getString(_costKey);
    if (costRaw != null) {
      try {
        cost = TripCostData.fromJson(jsonDecode(costRaw) as Map<String, dynamic>);
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      _genreItems  = genreItems;
      _isBoat      = isBoat;
      _hasTemplate = hasTemplate;
      _cost        = cost;
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_checksKey, jsonEncode(allChecks));
  }

  // ─── コスト操作 ──────────────────────────────────

  Future<void> _saveCost() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_costKey, jsonEncode(_cost.toJson()));
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
    final prefs = await SharedPreferences.getInstance();

    // テンプレート一覧を読み込み
    List<SavedTemplate> templates = [];
    final tmplRaw = prefs.getString('saved_templates');
    if (tmplRaw != null) {
      try {
        templates = (jsonDecode(tmplRaw) as List)
            .map((e) => SavedTemplate.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    // 場所・ショップ履歴を読み込み
    List<String> locationHistory = [];
    List<String> shopHistory = [];
    try {
      final locsRaw = prefs.getString('saved_locations');
      if (locsRaw != null) {
        locationHistory = List<String>.from(jsonDecode(locsRaw) as List);
      }
      final shopsRaw = prefs.getString('saved_shops');
      if (shopsRaw != null) {
        shopHistory = List<String>.from(jsonDecode(shopsRaw) as List);
      }
    } catch (_) {}

    if (!mounted) return;

    // ダイアログ内状態
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
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 旅行名
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '旅行名',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                // 場所
                _HistorySuggestField(
                  ctrl: locationCtrl,
                  label: '場所（任意）',
                  hint: '例：沖縄・慶良間',
                  history: locationHistory,
                ),
                const SizedBox(height: 14),

                // ショップ
                _HistorySuggestField(
                  ctrl: shopCtrl,
                  label: 'ショップ名（任意）',
                  hint: '例：〇〇ダイビングサービス',
                  history: shopHistory,
                ),
                const SizedBox(height: 20),

                // テンプレート
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

                // 日付
                const Text(
                  '日付',
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

                // スーツ種類
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

                // 日程
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

      // Trip を更新
      widget.trip.name         = newName;
      widget.trip.date         = editDate;
      widget.trip.suitType     = editSuitType;
      widget.trip.isOvernight  = editOvernight;
      widget.trip.templateName = editTemplateName;
      widget.trip.location     = newLocation;
      widget.trip.shopName     = newShop;

      // 場所・ショップ履歴を保存
      await _saveHistory(prefs, newLocation, locationHistory, 'saved_locations');
      await _saveHistory(prefs, newShop,     shopHistory,     'saved_shops');

      if (!mounted) return;
      widget.onTripUpdated?.call(); // 親が saveTrips() を実行
      _loadData(silent: true);     // チェックリストを再構築（テンプレート変更対応）
    });
  }

  Future<void> _saveHistory(
    SharedPreferences prefs,
    String? value,
    List<String> list,
    String key,
  ) async {
    if (value == null || value.isEmpty || list.contains(value)) return;
    list.insert(0, value);
    await prefs.setString(key, jsonEncode(list));
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
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '編集',
            onPressed: _showEditDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.checklist), text: 'チェックリスト'),
            Tab(icon: Icon(Icons.attach_money), text: 'コスト管理'),
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
            allDone: allDone,
            primary: primary,
          ),
        Expanded(
          child: ListView(
            children: [
              _buildInfoCard(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  children: [
                    Icon(Icons.checklist, size: 20, color: primary),
                    const SizedBox(width: 6),
                    Text(
                      '準備リスト',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasTemplate)
                ...genreOrder
                    .where((g) => (_genreItems[g]?.isNotEmpty ?? false))
                    .map((g) => _buildGenreSection(g))
              else
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
          ),
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
    final items = _genreItems[genre] ?? [];
    final color = genreColor(genre);
    final activeList = items
        .where((e) => e.isNaturallyActive(_isWet, _isOvernight, _isBoat))
        .toList();
    final checked = activeList.where((e) => e.isChecked).length;
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
            '$checked/${items.length}',
            style: TextStyle(
              fontSize: 12,
              color: sectionDone ? Colors.green[700] : Colors.grey[500],
              fontWeight: sectionDone ? FontWeight.w700 : null,
            ),
          ),
        ],
      ),
      children: items.map((item) => _buildItemRow(item, color)).toList(),
    );
  }

  Widget _buildItemRow(TemplateItem item, Color color) {
    final isActive = item.isNaturallyActive(_isWet, _isOvernight, _isBoat);
    final isGreyed = !item.isChecked && !isActive;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Checkbox(
        value: item.isChecked,
        onChanged: (_) => _toggleItem(item),
        activeColor: color,
        side: isGreyed
            ? const BorderSide(color: Color(0xFFBDBDBD), width: 1.2)
            : null,
        visualDensity: VisualDensity.compact,
      ),
      title: Text(
        item.name,
        style: TextStyle(
          fontSize: 14,
          color: isGreyed ? const Color(0xFFBDBDBD) : null,
        ),
      ),
      onTap: () => _toggleItem(item),
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

          // 基本費用カード
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

          // 交通費
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
                  foregroundColor: const Color(0xFF1565C0),
                  side: const BorderSide(color: Color(0xFF1565C0)),
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
                  foregroundColor: const Color(0xFF6A1B9A),
                  side: const BorderSide(color: Color(0xFF6A1B9A)),
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),

          // 合計サマリー
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
        isOutbound ? const Color(0xFF1565C0) : const Color(0xFF6A1B9A);

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
      color: Theme.of(context)
          .colorScheme
          .primaryContainer
          .withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: primary.withValues(alpha: 0.3)),
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
    required this.allDone,
    required this.primary,
  });
  final int checked;
  final int total;
  final double progress;
  final bool allDone;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final barColor = allDone ? Colors.green[600]! : primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: allDone ? Colors.green[50] : Colors.blue[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allDone
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 16,
                color: barColor,
              ),
              const SizedBox(width: 6),
              Text(
                allDone ? '全て準備完了！' : '$checked / $total 項目準備済み',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: barColor,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 13,
                  color: allDone ? Colors.green[700] : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(barColor),
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
