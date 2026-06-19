import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/template_item.dart';
import '../models/trip.dart';
import 'trip_detail_screen.dart';

class TravelScreen extends StatefulWidget {
  const TravelScreen({super.key});

  @override
  State<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends State<TravelScreen> {
  final List<Trip> _trips = [];
  List<SavedTemplate> _savedTemplates = [];
  List<String> _savedLocations = [];
  List<String> _savedShops = [];
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _loadTrips();
    _loadTemplates();
    _loadHistory();
  }

  // ─── 旅行の永続化 ──────────────────────────────────

  static const _kSavedTrips = 'saved_trips';
  static const _kLocations  = 'saved_locations';
  static const _kShops      = 'saved_shops';

  Future<void> _loadTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSavedTrips);
    if (raw == null) return;
    try {
      final List data = jsonDecode(raw) as List;
      if (!mounted) return;
      setState(() {
        _trips
          ..clear()
          ..addAll(data.map((e) => Trip.fromJson(e as Map<String, dynamic>)));
      });
    } catch (_) {}
  }

  Future<void> _saveTrips() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kSavedTrips,
      jsonEncode(_trips.map((t) => t.toJson()).toList()),
    );
  }

  Future<void> _loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_templates');
    if (raw == null) return;
    try {
      final List data = jsonDecode(raw) as List;
      if (!mounted) return;
      setState(() {
        _savedTemplates = data
            .map((e) => SavedTemplate.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (_) {}
  }

  // ─── 場所・ショップ履歴 ────────────────────────────

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final locsRaw = prefs.getString(_kLocations);
      if (locsRaw != null) {
        _savedLocations = List<String>.from(jsonDecode(locsRaw) as List);
      }
      final shopsRaw = prefs.getString(_kShops);
      if (shopsRaw != null) {
        _savedShops = List<String>.from(jsonDecode(shopsRaw) as List);
      }
    } catch (_) {}
  }

  Future<void> _saveHistory(String? location, String? shop) async {
    final prefs = await SharedPreferences.getInstance();
    bool changed = false;
    if (location != null && location.isNotEmpty &&
        !_savedLocations.contains(location)) {
      _savedLocations.insert(0, location);
      changed = true;
    }
    if (shop != null && shop.isNotEmpty && !_savedShops.contains(shop)) {
      _savedShops.insert(0, shop);
      changed = true;
    }
    if (changed) {
      await prefs.setString(_kLocations, jsonEncode(_savedLocations));
      await prefs.setString(_kShops, jsonEncode(_savedShops));
    }
  }

  // ─── カレンダー操作 ────────────────────────────────

  List<Trip> _tripsForDay(DateTime day) =>
      _trips.where((t) => isSameDay(t.date, day)).toList();

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });

    final trips = _tripsForDay(selectedDay);
    if (trips.isEmpty) {
      _showAddTripDialog(initialDate: selectedDay);
    } else {
      _openDetail(trips.first);
    }
  }

  void _openDetail(Trip trip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripDetailScreen(
          trip: trip,
          onTripUpdated: () {
            _saveTrips();
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  // ─── 旅行追加ダイアログ ────────────────────────────

  Future<void> _showAddTripDialog({DateTime? initialDate}) async {
    await Future.wait([_loadTemplates(), _loadHistory()]);
    if (!mounted) return;
    DateTime selectedDate = initialDate ?? _focusedDay;
    SuitType suitType = SuitType.wet;
    bool isOvernight = false;
    String? selectedTemplateName;
    final nameCtrl     = TextEditingController();
    final locationCtrl = TextEditingController();
    final shopCtrl     = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('旅行を追加'),
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
                      hintText: '例：沖縄ダイビング',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 場所（履歴付き）
                  _HistorySuggestField(
                    ctrl: locationCtrl,
                    label: '場所（任意）',
                    hint: '例：沖縄・慶良間',
                    history: _savedLocations,
                  ),
                  const SizedBox(height: 14),

                  // ショップ名（履歴付き）
                  _HistorySuggestField(
                    ctrl: shopCtrl,
                    label: 'ショップ名（任意）',
                    hint: '例：〇〇ダイビングサービス',
                    history: _savedShops,
                  ),
                  const SizedBox(height: 20),

                  // テンプレート選択
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
                      value: selectedTemplateName,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('テンプレートなし'),
                        ),
                        for (final t in _savedTemplates)
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
                        setDialogState(() {
                          selectedTemplateName = val;
                          if (val != null) {
                            final tmpl = _savedTemplates
                                .firstWhere((t) => t.name == val);
                            suitType =
                                tmpl.isWetSuit ? SuitType.wet : SuitType.dry;
                            isOvernight = tmpl.isOvernight;
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
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        locale: const Locale('ja', 'JP'),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
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
                            '${selectedDate.year}年'
                            '${selectedDate.month}月'
                            '${selectedDate.day}日',
                          ),
                          const Spacer(),
                          Icon(Icons.arrow_drop_down,
                              color: Colors.grey[600]),
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
                    selected: {suitType},
                    onSelectionChanged: (val) =>
                        setDialogState(() => suitType = val.first),
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
                    selected: {isOvernight},
                    onSelectionChanged: (val) =>
                        setDialogState(() => isOvernight = val.first),
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
                  final location = locationCtrl.text.trim().isEmpty
                      ? null
                      : locationCtrl.text.trim();
                  final shop = shopCtrl.text.trim().isEmpty
                      ? null
                      : shopCtrl.text.trim();
                  setState(() {
                    _trips.add(Trip(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: name,
                      date: selectedDate,
                      suitType: suitType,
                      isOvernight: isOvernight,
                      templateName: selectedTemplateName,
                      location: location,
                      shopName: shop,
                    ));
                  });
                  _saveTrips();
                  _saveHistory(location, shop);
                  Navigator.pop(ctx);
                },
                child: const Text('追加'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── 旅行複製 ──────────────────────────────────────

  Future<void> _duplicateTrip(Trip original) async {
    // ステップ1: 旅行名を入力
    final nameCtrl = TextEditingController(text: '${original.name}（コピー）');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('旅行を複製'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('新しい旅行名を入力してください',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '旅行名',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('次へ：日付を選択'),
          ),
        ],
      ),
    );

    final newName = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (confirmed != true || !mounted) return;

    // ステップ2: 日付を選択
    final newDate = await showDatePicker(
      context: context,
      initialDate: original.date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ja', 'JP'),
    );
    if (newDate == null || !mounted) return;

    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newTrip = Trip(
      id: newId,
      name: newName,
      date: newDate,
      suitType: original.suitType,
      isOvernight: original.isOvernight,
      templateName: original.templateName,
      location: original.location,
      shopName: original.shopName,
    );

    // コスト情報を複製（チェックリスト状態は引き継がない）
    final prefs = await SharedPreferences.getInstance();
    final costRaw = prefs.getString('trip_${original.id}_cost');
    if (costRaw != null && mounted) {
      await prefs.setString('trip_${newId}_cost', costRaw);
    }

    if (!mounted) return;
    setState(() => _trips.add(newTrip));
    await _saveTrips();
  }

  // ─── 旅行削除 ──────────────────────────────────────

  Future<void> _deleteTrip(Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('旅行を削除'),
        content: Text(
          '「${trip.name}」を削除しますか？\nコスト・チェックリストのデータもすべて削除されます。\nこの操作は取り消せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red[600]),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // SharedPreferences から関連データも削除
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('trip_${trip.id}_cost');
    await prefs.remove('trip_${trip.id}_checks');

    if (!mounted) return;
    setState(() => _trips.remove(trip));
    await _saveTrips();
  }

  // ─── build ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final monthTrips = [..._trips]..sort((a, b) => a.date.compareTo(b.date));
    final filteredTrips = monthTrips
        .where((t) =>
            t.date.year == _focusedDay.year &&
            t.date.month == _focusedDay.month)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('旅行準備'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // カレンダー（月表示）
          TableCalendar<Trip>(
            locale: 'ja_JP',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {CalendarFormat.month: '月'},
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _tripsForDay,
            onDaySelected: _onDaySelected,
            onPageChanged: (focusedDay) =>
                setState(() => _focusedDay = focusedDay),
            calendarStyle: CalendarStyle(
              markerDecoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              markerSize: 6.0,
              markersMaxCount: 1,
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),

          const Divider(height: 1),

          // ＋ 旅行を追加ボタン
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAddTripDialog(),
                icon: const Icon(Icons.add),
                label: const Text('旅行を追加'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  side: BorderSide(
                      color: Theme.of(context).colorScheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // 当月の旅行リスト
          Expanded(
            child: filteredTrips.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.travel_explore,
                            size: 56, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          'この月の旅行はありません\n日付タップまたは＋ボタンで追加',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: filteredTrips.length,
                    itemBuilder: (_, i) => _TripCard(
                      trip: filteredTrips[i],
                      onTap: () => _openDetail(filteredTrips[i]),
                      onDuplicate: () => _duplicateTrip(filteredTrips[i]),
                      onDelete: () => _deleteTrip(filteredTrips[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── 旅行カード ───────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.onTap,
    required this.onDuplicate,
    required this.onDelete,
  });
  final Trip trip;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final d = trip.date;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              // アイコン
              CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.scuba_diving,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // 旅行名・日付・場所
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${d.year}年${d.month}月${d.day}日'
                      '${trip.location != null ? "  ·  ${trip.location}" : ""}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              // スーツ・日程チップ
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusChip(
                    label: trip.suitType == SuitType.wet ? 'ウェット' : 'ドライ',
                    color: trip.suitType == SuitType.wet
                        ? Colors.blue
                        : Colors.indigo,
                  ),
                  const SizedBox(height: 4),
                  _StatusChip(
                    label: trip.isOvernight ? '宿泊' : '日帰り',
                    color: trip.isOvernight ? Colors.orange : Colors.green,
                  ),
                ],
              ),

              // ポップアップメニュー（複製・削除）
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[500]),
                tooltip: 'メニュー',
                onSelected: (val) {
                  if (val == 'duplicate') onDuplicate();
                  if (val == 'delete')    onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Row(
                      children: [
                        Icon(Icons.copy_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('複製'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18,
                            color: Colors.red[600]),
                        const SizedBox(width: 10),
                        Text('削除', style: TextStyle(color: Colors.red[600])),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── ステータスチップ ─────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color, width: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
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
