import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/template_item.dart';
import '../models/trip.dart';
import '../widgets/sky_card.dart';
import 'trip_detail_screen.dart';

class TravelScreen extends StatefulWidget {
  const TravelScreen({super.key});

  @override
  State<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends State<TravelScreen> {
  final _db = FirebaseFirestore.instance;

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

  Future<void> _loadTrips() async {
    try {
      final snapshot = await _db.collection('trips').get();
      if (!mounted) return;
      setState(() {
        _trips
          ..clear()
          ..addAll(snapshot.docs.map((d) => Trip.fromJson(d.data())));
      });
    } catch (_) {}
  }

  Future<void> _saveTripToFirestore(Trip trip) async {
    await _db.collection('trips').doc(trip.id).set(trip.toJson());
  }

  Future<void> _loadTemplates() async {
    try {
      final snapshot = await _db.collection('templates').get();
      if (!mounted) return;
      setState(() {
        _savedTemplates = snapshot.docs
            .map((d) => SavedTemplate.fromJson(d.data()))
            .toList();
      });
    } catch (_) {}
  }

  // ─── 場所・ショップ履歴 ────────────────────────────

  Future<void> _loadHistory() async {
    try {
      final results = await Future.wait([
        _db.collection('history').doc('locations').get(),
        _db.collection('history').doc('shops').get(),
      ]);
      if (!mounted) return;
      final locsDoc  = results[0];
      final shopsDoc = results[1];
      if (locsDoc.exists) {
        _savedLocations = List<String>.from(
            (locsDoc.data()!['items'] as List? ?? []));
      }
      if (shopsDoc.exists) {
        _savedShops = List<String>.from(
            (shopsDoc.data()!['items'] as List? ?? []));
      }
    } catch (_) {}
  }

  Future<void> _saveHistory(String? location, String? shop) async {
    bool locChanged  = false;
    bool shopChanged = false;

    if (location != null && location.isNotEmpty &&
        !_savedLocations.contains(location)) {
      _savedLocations.insert(0, location);
      locChanged = true;
    }
    if (shop != null && shop.isNotEmpty && !_savedShops.contains(shop)) {
      _savedShops.insert(0, shop);
      shopChanged = true;
    }

    final futures = <Future>[];
    if (locChanged) {
      futures.add(_db.collection('history').doc('locations')
          .set({'items': _savedLocations}));
    }
    if (shopChanged) {
      futures.add(_db.collection('history').doc('shops')
          .set({'items': _savedShops}));
    }
    if (futures.isNotEmpty) await Future.wait(futures);
  }

  // ─── カレンダー操作 ────────────────────────────────

  List<Trip> _tripsForDay(DateTime day) =>
      _trips.where((t) => isSameDay(t.date, day)).toList();

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay  = focusedDay;
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
            _saveTripToFirestore(trip);
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
                  final newTrip = Trip(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    date: selectedDate,
                    suitType: suitType,
                    isOvernight: isOvernight,
                    templateName: selectedTemplateName,
                    location: location,
                    shopName: shop,
                  );
                  setState(() => _trips.add(newTrip));
                  _saveTripToFirestore(newTrip);
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

    // コスト情報をFirestoreから複製
    try {
      final costDoc = await _db.collection('costs').doc(original.id).get();
      if (costDoc.exists && mounted) {
        await _db.collection('costs').doc(newId).set(costDoc.data()!);
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _trips.add(newTrip));
    await _saveTripToFirestore(newTrip);
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

    await Future.wait([
      _db.collection('trips').doc(trip.id).delete(),
      _db.collection('costs').doc(trip.id).delete(),
      _db.collection('checks').doc(trip.id).delete(),
    ]);

    if (!mounted) return;
    setState(() => _trips.remove(trip));
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
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SkyCard(
              title: _trips.isEmpty ? '旅行を追加しましょう' : '${_trips.length}件の旅行予定',
              subtitle: _trips.isEmpty ? '日付をタップして旅行予定を追加' : '旅行の準備を進めましょう',
              emoji: '✈️',
            ),
          ),
          const SliverToBoxAdapter(
            child: ColoredBox(
              color: Color(0xFFE8F8FC),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'ダイビング旅行の準備リストが作れます。\n日付をタップして旅行予定を追加しましょう。\nコスト管理や本数カウントもできます。',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B8FA0)),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ColoredBox(color: Colors.white, child: TableCalendar<Trip>(
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
                markersMaxCount: 0,
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
              calendarBuilders: CalendarBuilders<Trip>(
                defaultBuilder: (context, day, focusedDay) {
                  final hasTrips = _tripsForDay(day).isNotEmpty;
                  if (!hasTrips) return null;
                  return Container(
                    margin: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF4EC8E8),
                        width: 2,
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(
                        color: Color(0xFF4EC8E8),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
            )),
          ),
          const SliverToBoxAdapter(
            child: Divider(height: 1),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _showAddTripDialog(),
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  label: const Text('旅行を追加'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9340),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
          if (filteredTrips.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.flight, size: 48, color: Color(0xFFB0CDD5)),
                    SizedBox(height: 12),
                    Text(
                      'この月の旅行はありません\n日付タップまたは＋ボタンで追加',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6B8FA0), fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _TripCard(
                    trip: filteredTrips[i],
                    onTap: () => _openDetail(filteredTrips[i]),
                    onDuplicate: () => _duplicateTrip(filteredTrips[i]),
                    onDelete: () => _deleteTrip(filteredTrips[i]),
                  ),
                  childCount: filteredTrips.length,
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
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xFF4EC8E8), width: 5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        trip.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: Color(0xFF1A3A4A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${d.year}年${d.month}月${d.day}日'
                        '${trip.location != null ? "  ·  ${trip.location}" : ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B8FA0)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _StatusChip(
                            label: trip.suitType == SuitType.wet ? 'ウェット' : 'ドライ',
                            bg: trip.suitType == SuitType.wet ? const Color(0xFFE6F8FC) : const Color(0xFFF1EEFF),
                            fg: trip.suitType == SuitType.wet ? const Color(0xFF1A7A94) : const Color(0xFF6D43D4),
                            icon: trip.suitType == SuitType.wet ? Icons.waves : Icons.ac_unit,
                          ),
                          const SizedBox(width: 6),
                          _StatusChip(
                            label: trip.isOvernight ? '宿泊' : '日帰り',
                            bg: trip.isOvernight ? const Color(0xFFFFF0E0) : const Color(0xFFEEFACC),
                            fg: trip.isOvernight ? const Color(0xFFC45A00) : const Color(0xFF5A8A00),
                            icon: trip.isOvernight ? Icons.hotel : Icons.wb_sunny_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      size: 20,
                      color: Color(0xFF6B8FA0)),
                  tooltip: 'メニュー',
                  onSelected: (val) {
                    if (val == 'duplicate') onDuplicate();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          const Icon(Icons.copy,
                              size: 16,
                              color: Color(0xFF6B8FA0)),
                          const SizedBox(width: 10),
                          const Text('複製'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline,
                              size: 16,
                              color: Color(0xFFFF5B5B)),
                          SizedBox(width: 10),
                          Text('削除',
                              style:
                                  TextStyle(color: Color(0xFFFF5B5B))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── ステータスチップ ─────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.bg, required this.fg, required this.icon});
  final String label;
  final Color bg;
  final Color fg;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
        ],
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
