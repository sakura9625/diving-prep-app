import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../models/trip_cost.dart';
import '../services/user_service.dart';
import '../widgets/help_bottom_sheet.dart';
import '../widgets/sky_card.dart';

// ─── 集計モデル ───────────────────────────────────────────────────────────────

class _TripEntry {
  final Trip trip;
  final TripCostData cost;
  _TripEntry({required this.trip, required this.cost});
}

class _MonthData {
  final int year;
  final int month;
  int diveCount     = 0;
  int totalCost     = 0;
  int diveCost      = 0;
  int accommodation = 0;
  int transport     = 0;

  _MonthData({required this.year, required this.month});

  String get label      => '$year/${month.toString().padLeft(2, '0')}';
  String get shortLabel => '${year.toString().substring(2)}/${month.toString().padLeft(2, '0')}';
  int    get costPerDive => diveCount > 0 ? totalCost ~/ diveCount : 0;

  void add(TripCostData c) {
    diveCount     += c.diveCount;
    totalCost     += c.totalCost;
    diveCost      += c.diveCost;
    accommodation += c.accommodation;
    transport     += c.transportTotal;
  }
}

class _GroupData {
  final String name;
  int diveCount = 0;
  int totalCost = 0;

  _GroupData({required this.name});

  int get costPerDive => diveCount > 0 ? totalCost ~/ diveCount : 0;

  void add(TripCostData c) {
    diveCount += c.diveCount;
    totalCost += c.totalCost;
  }
}

// ─── 画面 ─────────────────────────────────────────────────────────────────────

class CostScreen extends StatefulWidget {
  const CostScreen({super.key});

  @override
  State<CostScreen> createState() => _CostScreenState();
}

class _CostScreenState extends State<CostScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;

  String? _userId;
  List<_TripEntry> _entries = [];
  bool _isLoading = true;
  int? _selectedYear;
  late TabController _tabController;
  int _pastDives = 0;

  String _barMetric  = 'bar_dives';
  String _lineMetric = 'line_cumulative_cost_per_dive';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initUser();
  }

  Future<void> _initUser() async {
    _userId = await UserService.getUserId();
    _loadData();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (_userId == null) return;
    try {
      final doc = await _db
          .collection('users').doc(_userId)
          .collection('settings').doc('profile')
          .get();
      if (doc.exists) {
        setState(() {
          _pastDives = (doc.data()!['pastDives'] as int?) ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _savePastDives(int value) async {
    if (_userId == null) return;
    setState(() => _pastDives = value);
    try {
      await _db
          .collection('users').doc(_userId)
          .collection('settings').doc('profile')
          .set({'pastDives': value}, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── データ読み込み ───────────────────────────────

  Future<void> _loadData() async {
    if (_userId == null) return;
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _db.collection('users').doc(_userId).collection('trips').get(),
        _db.collection('users').doc(_userId).collection('costs').get(),
      ]);

      final tripsSnapshot = results[0] as QuerySnapshot;
      final costsSnapshot = results[1] as QuerySnapshot;

      final trips = tripsSnapshot.docs
          .map((d) => Trip.fromJson(d.data() as Map<String, dynamic>))
          .toList();

      final costMap = <String, TripCostData>{
        for (final d in costsSnapshot.docs)
          d.id: TripCostData.fromJson(d.data() as Map<String, dynamic>),
      };

      final entries = trips
          .map((t) => _TripEntry(
                trip: t,
                cost: costMap[t.id] ?? TripCostData(),
              ))
          .toList();

      debugPrint('[CostScreen] loaded ${entries.length} trips');

      if (!mounted) return;
      setState(() {
        _entries   = entries;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[CostScreen] load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── 集計 ────────────────────────────────────────

  List<int> get _yearList {
    final years = _entries.map((e) => e.trip.date.year).toSet().toList()..sort();
    return years;
  }

  List<_TripEntry> get _filteredEntries =>
      _selectedYear == null
          ? _entries
          : _entries.where((e) => e.trip.date.year == _selectedYear).toList();

  int get _totalDives         => _filteredEntries.fold(0, (s, e) => s + e.cost.diveCount);
  int get _totalCost          => _filteredEntries.fold(0, (s, e) => s + e.cost.totalCost);
  int get _totalDiveCost      => _filteredEntries.fold(0, (s, e) => s + e.cost.diveCost);
  int get _totalAccommodation => _filteredEntries.fold(0, (s, e) => s + e.cost.accommodation);
  int get _totalTransport     => _filteredEntries.fold(0, (s, e) => s + e.cost.transportTotal);
  int get _avgCostPerDive     => _totalDives > 0 ? _totalCost ~/ _totalDives : 0;

  int get _totalTrips      => _entries.length;
  int get _appDives        => _entries.fold(0, (s, e) => s + e.cost.diveCount);
  int get _grandTotalDives => _pastDives + _appDives;

  List<_GroupData> get _topLocationsByDives {
    final map = <String, _GroupData>{};
    for (final e in _filteredEntries) {
      final key = e.trip.location?.isNotEmpty == true ? e.trip.location! : null;
      if (key == null) continue;
      map.putIfAbsent(key, () => _GroupData(name: key)).add(e.cost);
    }
    final list = map.values.toList()..sort((a, b) => b.diveCount.compareTo(a.diveCount));
    return list.take(3).toList();
  }

  List<MapEntry<String, int>> get _topShopsByTrips {
    final map = <String, int>{};
    for (final e in _filteredEntries) {
      final key = e.trip.shopName?.isNotEmpty == true ? e.trip.shopName! : null;
      if (key == null) continue;
      map[key] = (map[key] ?? 0) + 1;
    }
    final list = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list.take(3).toList();
  }

  _GroupData? get _topLocationByDives => _locationData.isNotEmpty ? _locationData.first : null;

  MapEntry<String, int>? get _homePoint {
    final map = <String, int>{};
    for (final e in _filteredEntries) {
      final key = e.trip.location?.isNotEmpty == true ? e.trip.location! : null;
      if (key == null) continue;
      map[key] = (map[key] ?? 0) + 1;
    }
    if (map.isEmpty) return null;
    return map.entries.reduce((a, b) => a.value >= b.value ? a : b);
  }

  _GroupData? get _mostExpensiveLocation => _locationData.isNotEmpty ? _locationData.first : null;

  _GroupData? get _bestCostpaShop {
    final list = _shopData.where((e) => e.diveCount > 0 && e.costPerDive > 0).toList()
      ..sort((a, b) => a.costPerDive.compareTo(b.costPerDive));
    return list.isNotEmpty ? list.first : null;
  }

  _GroupData? get _cheapestLocation {
    final list = _locationData.where((e) => e.diveCount > 0 && e.costPerDive > 0).toList()
      ..sort((a, b) => a.costPerDive.compareTo(b.costPerDive));
    return list.isNotEmpty ? list.first : null;
  }

  _GroupData? get _mostExpensivePerDiveLocation {
    final list = _locationData.where((e) => e.diveCount > 0 && e.costPerDive > 0).toList()
      ..sort((a, b) => b.costPerDive.compareTo(a.costPerDive));
    return list.isNotEmpty ? list.first : null;
  }

  Map<String, int> get _blankStats {
    final sorted = [..._filteredEntries]..sort((a, b) => a.trip.date.compareTo(b.trip.date));
    if (sorted.length < 2) return {'max': 0, 'avg': 0};
    int maxBlank = 0, totalBlank = 0;
    for (int i = 1; i < sorted.length; i++) {
      final days = sorted[i].trip.date.difference(sorted[i-1].trip.date).inDays;
      if (days > maxBlank) maxBlank = days;
      totalBlank += days;
    }
    return {'max': maxBlank, 'avg': totalBlank ~/ (sorted.length - 1)};
  }

  Map<String, dynamic>? get _longestAbsentLocation {
    if (_filteredEntries.length < 2) return null;
    final sorted = [..._filteredEntries]..sort((a, b) => a.trip.date.compareTo(b.trip.date));
    final locationVisits = <String, List<DateTime>>{};
    for (final e in sorted) {
      final loc = e.trip.location;
      if (loc == null || loc.isEmpty) continue;
      locationVisits.putIfAbsent(loc, () => []).add(e.trip.date);
    }
    String? maxLoc;
    int maxDays = 0;
    for (final entry in locationVisits.entries) {
      if (entry.value.length < 2) continue;
      final visits = entry.value..sort();
      for (int i = 1; i < visits.length; i++) {
        final days = visits[i].difference(visits[i-1]).inDays;
        if (days > maxDays) {
          maxDays = days;
          maxLoc = entry.key;
        }
      }
    }
    if (maxLoc == null) return null;
    return {'name': maxLoc, 'days': maxDays};
  }

  List<String> get _newLocations {
    if (_selectedYear == null) return [];
    final beforeYear = _entries
        .where((e) => e.trip.date.year < _selectedYear! && e.trip.location?.isNotEmpty == true)
        .map((e) => e.trip.location!)
        .toSet();
    final thisYear = _filteredEntries
        .where((e) => e.trip.location?.isNotEmpty == true)
        .map((e) => e.trip.location!)
        .toSet();
    return thisYear.where((l) => !beforeYear.contains(l)).take(3).toList();
  }

  Map<String, dynamic> get _allTimeStats {
    final byYear = <int, int>{};
    final byYearCost = <int, int>{};
    final byMonth = <int, int>{};
    for (final e in _entries) {
      final y = e.trip.date.year;
      final m = e.trip.date.month;
      byYear[y] = (byYear[y] ?? 0) + e.cost.diveCount;
      byYearCost[y] = (byYearCost[y] ?? 0) + e.cost.totalCost;
      byMonth[m] = (byMonth[m] ?? 0) + e.cost.diveCount;
    }
    final topYear = byYear.isEmpty ? null : byYear.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final topYearCost = byYearCost.isEmpty ? null : byYearCost.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final topMonth = byMonth.isEmpty ? null : byMonth.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final topTripByDives = _entries.isEmpty ? null : _entries.reduce((a, b) => a.cost.diveCount >= b.cost.diveCount ? a : b);
    final topTripByCost = _entries.isEmpty ? null : _entries.reduce((a, b) => a.cost.totalCost >= b.cost.totalCost ? a : b);
    final byYearTrips = <int, int>{};
    for (final e in _entries) {
      byYearTrips[e.trip.date.year] = (byYearTrips[e.trip.date.year] ?? 0) + 1;
    }
    final topYearTrips = byYearTrips.isEmpty ? null : byYearTrips.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return {
      'topYear': topYear,
      'topYearCost': topYearCost,
      'topMonth': topMonth,
      'topTripByDives': topTripByDives,
      'topTripByCost': topTripByCost,
      'topYearTrips': topYearTrips,
    };
  }

  List<_MonthData> get _monthlyData {
    final map = <String, _MonthData>{};
    for (final e in _filteredEntries) {
      final key = '${e.trip.date.year}/${e.trip.date.month.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () =>
          _MonthData(year: e.trip.date.year, month: e.trip.date.month));
      map[key]!.add(e.cost);
    }
    return map.values.toList()
      ..sort((a, b) {
        final r = a.year.compareTo(b.year);
        return r != 0 ? r : a.month.compareTo(b.month);
      });
  }

  List<_GroupData> get _locationData {
    final map = <String, _GroupData>{};
    for (final e in _filteredEntries) {
      final key = (e.trip.location?.isNotEmpty == true)
          ? e.trip.location!
          : '（未設定）';
      map.putIfAbsent(key, () => _GroupData(name: key)).add(e.cost);
    }
    return map.values.toList()
      ..sort((a, b) => b.totalCost.compareTo(a.totalCost));
  }

  List<_GroupData> get _shopData {
    final map = <String, _GroupData>{};
    for (final e in _filteredEntries) {
      final key = (e.trip.shopName?.isNotEmpty == true)
          ? e.trip.shopName!
          : '（未設定）';
      map.putIfAbsent(key, () => _GroupData(name: key)).add(e.cost);
    }
    return map.values.toList()
      ..sort((a, b) => b.totalCost.compareTo(a.totalCost));
  }

  // ─── グラフデータ ─────────────────────────────────

  List<double> _barValues(List<_MonthData> m) => switch (_barMetric) {
    'bar_dives' => m.map((d) => d.diveCount.toDouble()).toList(),
    _           => m.map((d) => d.totalCost.toDouble()).toList(),
  };

  List<double> _lineValues(List<_MonthData> m) {
    switch (_lineMetric) {
      case 'line_monthly_cost_per_dive':
        return m.map((d) => d.costPerDive.toDouble()).toList();
      case 'line_cumulative_cost_per_dive':
        int cc = 0, cd = 0;
        return m.map((d) { cc += d.totalCost; cd += d.diveCount; return cd > 0 ? cc / cd : 0.0; }).toList();
      case 'line_monthly_dives':
        return m.map((d) => d.diveCount.toDouble()).toList();
      case 'line_cumulative_dives':
        int cum = 0;
        return m.map((d) { cum += d.diveCount; return cum.toDouble(); }).toList();
      case 'line_monthly_cost':
        return m.map((d) => d.totalCost.toDouble()).toList();
      case 'line_cumulative_cost':
        int cum = 0;
        return m.map((d) { cum += d.totalCost; return cum.toDouble(); }).toList();
      default:
        return [];
    }
  }

  // ─── ヘルパー ─────────────────────────────────────

  String _yen(int v) {
    if (v <= 0) return '¥0';
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '¥$b';
  }

  String _axisLabel(double v) {
    final i = v.round();
    if (i == 0) return '0';
    if (i >= 100000) return '${(i / 10000).round()}万';
    if (i >= 10000)  return '${(i / 10000).toStringAsFixed(1)}万';
    if (i >= 1000)   return '${(i / 1000).toStringAsFixed(1)}k';
    return i.toString();
  }

  // ─── build ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('レポート'),
        actions: [
          IconButton(
            icon: const Text('🔰', style: TextStyle(fontSize: 18)),
            tooltip: '使い方',
            onPressed: () => HelpBottomSheet.show(context, HelpTab.report),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: '再読み込み',
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkyCard(
            title: _isLoading ? 'ロード中...' : '累計 ${_yen(_totalCost)}',
            subtitle: _isLoading ? '' : '総ダイブ $_totalDives 本 · 単価 ${_totalDives > 0 ? _yen(_avgCostPerDive) : "---"}',
            emoji: '💰',
          ),
          const ColoredBox(
            color: Color(0xFFE8F8FC),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '旅行ごとのダイビングコストを自動集計します。\n累計費用・ダイブ単価・場所別・月別のレポートを確認できます。',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B8FA0)),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredEntries.isEmpty
                    ? _buildEmpty()
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildYearFilter(),
                          const SizedBox(height: 12),
                          _buildSummary(primary),
                          const SizedBox(height: 20),
                          _buildChart(primary),
                          const SizedBox(height: 20),
                          _buildActivityCards(primary),
                          const SizedBox(height: 20),
                          _buildTables(primary),
                          const SizedBox(height: 32),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.bar_chart, size: 48, color: Color(0xFFB0CDD5)),
        const SizedBox(height: 16),
        const Text(
          '旅行データがありません',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B8FA0)),
        ),
        const SizedBox(height: 8),
        const Text(
          '「旅行準備」タブから旅行を追加して\nコストを入力してください',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6B8FA0)),
        ),
      ],
    ),
  );

  // ─── 年フィルター ────────────────────────────────

  Widget _buildYearFilter() {
    final years = _yearList.reversed.toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _YearChip(
            label: '全期間',
            selected: _selectedYear == null,
            onTap: () => setState(() => _selectedYear = null),
          ),
          for (final y in years)
            _YearChip(
              label: '$y年',
              selected: _selectedYear == y,
              onTap: () => setState(() => _selectedYear = y),
            ),
        ],
      ),
    );
  }

  // ─── サマリーセクション ──────────────────────────

  Widget _buildSummary(Color primary) {
    return _Section(
      label: 'サマリー',
      primary: primary,
      child: Column(
        children: [
          // 生涯旅行数・生涯累計ダイブ本数（年フィルター対象外）
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF4EC8E8).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('生涯旅行数', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text('${_totalTrips}回', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF4EC8E8))),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: const Color(0xFF4EC8E8).withValues(alpha: 0.2)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('生涯累計ダイブ本数', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              const SizedBox(height: 4),
                              Text('$_grandTotalDives本', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF4EC8E8))),
                              Text('アプリ登録: $_appDives本 + 過去: $_pastDives本', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            final ctrl = TextEditingController(text: _pastDives > 0 ? _pastDives.toString() : '');
                            final result = await showDialog<int>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('アプリ登録前のダイブ本数'),
                                content: TextField(
                                  controller: ctrl,
                                  keyboardType: TextInputType.number,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    labelText: '本数',
                                    suffixText: '本',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
                                  FilledButton(
                                    onPressed: () {
                                      final v = int.tryParse(ctrl.text) ?? 0;
                                      Navigator.pop(ctx, v);
                                    },
                                    child: const Text('保存'),
                                  ),
                                ],
                              ),
                            );
                            ctrl.dispose();
                            if (result != null) _savePastDives(result);
                          },
                          child: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF6B8FA0)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF4EC8E8).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF4EC8E8).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedYear != null ? '$_selectedYear年の旅行数' : '累計旅行数',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_filteredEntries.length}回',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF4EC8E8)),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: const Color(0xFF4EC8E8).withValues(alpha: 0.2)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedYear != null ? '$_selectedYear年のダイブ本数' : '累計ダイブ本数',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_totalDives本',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF4EC8E8)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _StatRow2(
            left:  _StatTile(label: '累計コスト',     value: _yen(_totalCost),    color: const Color(0xFF4EC8E8)),
            right: _StatTile(label: 'ダイブ単価',     value: _totalDives > 0 ? _yen(_avgCostPerDive) : '---', color: const Color(0xFFFF9340)),
          ),
          const SizedBox(height: 8),
          _StatRow2(
            left:  _StatTile(label: '累計ダイブ費',   value: _yen(_totalDiveCost),      color: const Color(0xFF4EC8E8)),
            right: _StatTile(label: '累計宿泊費',     value: _yen(_totalAccommodation), color: const Color(0xFFFF9340)),
          ),
          const SizedBox(height: 8),
          _StatRow2(
            left:  _StatTile(label: '累計交通費',     value: _yen(_totalTransport), color: const Color(0xFFA78BFA)),
            right: _StatTile(label: '潜った海の数', value: '${_filteredEntries.where((e) => e.trip.location != null && e.trip.location!.isNotEmpty).map((e) => e.trip.location!).toSet().length}箇所', color: const Color(0xFF7BBF00)),
          ),
        ],
      ),
    );
  }

  // ─── 集計テーブルセクション ──────────────────────

  Widget _buildTables(Color primary) {
    final locs   = _locationData;
    final shops  = _shopData;
    final months = _monthlyData;

    final maxRows = [locs.length, shops.length, months.length].reduce(max);
    final tableH  = 48.0 + (maxRows.clamp(1, 10) * 44.0);

    return _Section(
      label: '集計テーブル',
      primary: primary,
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '場所別'),
              Tab(text: 'ショップ別'),
              Tab(text: '月別'),
            ],
          ),
          SizedBox(
            height: tableH,
            child: TabBarView(
              controller: _tabController,
              children: [
                _GroupTable(data: locs,   colLabel: '場所',    formatter: _yen),
                _GroupTable(data: shops,  colLabel: 'ショップ', formatter: _yen),
                _MonthTable(data: months, formatter: _yen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── アクティビティカード ────────────────────────

  Widget _buildActivityCards(Color primary) {
    final blank = _blankStats;
    final allTime = _allTimeStats;
    final monthNames = ['1月','2月','3月','4月','5月','6月','7月','8月','9月','10月','11月','12月'];

    Widget card({
      required String label,
      required String value,
      String? sub,
      required IconData icon,
      required Color iconBg,
      String? badge,
    }) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8F8FC), width: 1.5),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 16, color: Colors.white),
                ),
                const Spacer(),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F8FC),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(badge, style: const TextStyle(fontSize: 10, color: Color(0xFF1A7A94))),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B8FA0))),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A3A4A))),
            if (sub != null)
              Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF6B8FA0))),
          ],
        ),
      );
    }

    Widget barCard({
      required String label,
      required List<MapEntry<String, int>> ranks,
    }) {
      if (ranks.isEmpty) return const SizedBox.shrink();
      final maxVal = ranks.first.value;
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8F8FC), width: 1.5),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B8FA0))),
            const SizedBox(height: 8),
            ...ranks.asMap().entries.map((e) {
              final ratio = maxVal > 0 ? e.value.value / maxVal : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(children: [
                  SizedBox(
                    width: 14,
                    child: Text('${e.key + 1}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4EC8E8))),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio.toDouble(),
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE6F8FC),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF4EC8E8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: Text(e.value.key,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF1A3A4A)),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right),
                  ),
                ]),
              );
            }),
          ],
        ),
      );
    }

    final cardWidth = (MediaQuery.of(context).size.width - 32 - 8) / 2;

    final filteredCards = <Widget>[
      if (_topLocationByDives != null)
        SizedBox(width: cardWidth, child: card(
          label: '最も潜った海（本数）',
          value: _topLocationByDives!.name,
          sub: '${_topLocationByDives!.diveCount}本',
          icon: Icons.waves,
          iconBg: const Color(0xFF4EC8E8),
          badge: '1位',
        )),
      if (_homePoint != null)
        SizedBox(width: cardWidth, child: card(
          label: 'ホームポイント（旅行数）',
          value: _homePoint!.key,
          sub: '${_homePoint!.value}回',
          icon: Icons.home_outlined,
          iconBg: const Color(0xFFFFD233),
          badge: '常連',
        )),
      if (_mostExpensiveLocation != null)
        SizedBox(width: cardWidth, child: card(
          label: '最もお金を使った海',
          value: _mostExpensiveLocation!.name,
          sub: _yen(_mostExpensiveLocation!.totalCost),
          icon: Icons.attach_money,
          iconBg: const Color(0xFFFF9340),
        )),
      if (_bestCostpaShop != null)
        SizedBox(width: cardWidth, child: card(
          label: 'ベストコスパショップ',
          value: _bestCostpaShop!.name,
          sub: '${_yen(_bestCostpaShop!.costPerDive)} / 本',
          icon: Icons.emoji_events_outlined,
          iconBg: const Color(0xFF7BBF00),
          badge: '最安値',
        )),
      if (_cheapestLocation != null)
        SizedBox(width: cardWidth, child: card(
          label: '最安単価の場所',
          value: _cheapestLocation!.name,
          sub: '${_yen(_cheapestLocation!.costPerDive)} / 本',
          icon: Icons.arrow_downward,
          iconBg: const Color(0xFF7BBF00),
        )),
      if (_mostExpensivePerDiveLocation != null)
        SizedBox(width: cardWidth, child: card(
          label: '最高単価の場所',
          value: _mostExpensivePerDiveLocation!.name,
          sub: '${_yen(_mostExpensivePerDiveLocation!.costPerDive)} / 本',
          icon: Icons.arrow_upward,
          iconBg: const Color(0xFFFF8FAB),
        )),
      if (blank['max']! > 0)
        SizedBox(width: cardWidth, child: card(
          label: '最長ブランク',
          value: '${blank['max']}日',
          sub: '平均 ${blank['avg']}日',
          icon: Icons.hourglass_empty,
          iconBg: const Color(0xFFA78BFA),
        )),
      if (_longestAbsentLocation != null)
        SizedBox(width: cardWidth, child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8F8FC), width: 1.5),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFA78BFA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.hourglass_bottom_outlined, size: 16, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text('一番久しぶりだった場所', style: TextStyle(fontSize: 10, color: Color(0xFF6B8FA0))),
              const SizedBox(height: 2),
              Text(_longestAbsentLocation!['name'] as String,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A3A4A))),
              Text('${_longestAbsentLocation!['days']}日ぶり',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B8FA0))),
            ],
          ),
        )),
      if (_topLocationsByDives.isNotEmpty)
        SizedBox(
          width: double.infinity,
          child: barCard(
            label: 'よくいく場所 TOP3（本数）',
            ranks: _topLocationsByDives.map((e) => MapEntry(e.name, e.diveCount)).toList(),
          ),
        ),
      if (_topShopsByTrips.isNotEmpty)
        SizedBox(
          width: double.infinity,
          child: barCard(
            label: 'よく使うショップ TOP3（旅行数）',
            ranks: _topShopsByTrips,
          ),
        ),
      if (_newLocations.isNotEmpty)
        SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8F8FC), width: 1.5),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('新しく潜った海', style: TextStyle(fontSize: 10, color: Color(0xFF6B8FA0))),
                const SizedBox(height: 8),
                ..._newLocations.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    const Icon(Icons.star_outline, size: 14, color: Color(0xFF4EC8E8)),
                    const SizedBox(width: 6),
                    Text(l, style: const TextStyle(fontSize: 13, color: Color(0xFF1A3A4A))),
                  ]),
                )),
              ],
            ),
          ),
        ),
    ];

    Widget tripDetailCard({
      required String label,
      required _TripEntry entry,
      required IconData icon,
      required Color iconBg,
      required String mainValue,
    }) {
      final t = entry.trip;
      final d = t.date;
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8F8FC), width: 1.5),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 16, color: Colors.white),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B8FA0))),
            const SizedBox(height: 2),
            Text(t.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A3A4A))),
            const SizedBox(height: 4),
            Text(mainValue, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4EC8E8))),
            const SizedBox(height: 6),
            if (t.location != null && t.location!.isNotEmpty)
              Row(children: [
                const Icon(Icons.place_outlined, size: 12, color: Color(0xFF6B8FA0)),
                const SizedBox(width: 4),
                Text(t.location!, style: const TextStyle(fontSize: 11, color: Color(0xFF6B8FA0))),
              ]),
            if (t.shopName != null && t.shopName!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.store_outlined, size: 12, color: Color(0xFF6B8FA0)),
                const SizedBox(width: 4),
                Text(t.shopName!, style: const TextStyle(fontSize: 11, color: Color(0xFF6B8FA0))),
              ]),
            ],
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF6B8FA0)),
              const SizedBox(width: 4),
              Text('${d.year}年${d.month}月${d.day}日',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B8FA0))),
            ]),
          ],
        ),
      );
    }

    final allTimeStats = allTime;
    final topYear = allTimeStats['topYear'] as MapEntry<int, int>?;
    final topYearCost = allTimeStats['topYearCost'] as MapEntry<int, int>?;
    final topMonth = allTimeStats['topMonth'] as MapEntry<int, int>?;
    final topYearTrips = allTimeStats['topYearTrips'] as MapEntry<int, int>?;
    final topTripByDives = allTimeStats['topTripByDives'] as _TripEntry?;
    final topTripByCost = allTimeStats['topTripByCost'] as _TripEntry?;

    final allTimeCards = <Widget>[
      if (topMonth != null)
        SizedBox(width: cardWidth, child: card(
          label: '最も潜った月',
          value: monthNames[topMonth.key - 1],
          sub: '${topMonth.value}本',
          icon: Icons.calendar_today,
          iconBg: const Color(0xFF4EC8E8),
        )),
      if (topYear != null)
        SizedBox(width: cardWidth, child: card(
          label: '最も潜った年',
          value: '${topYear.key}年',
          sub: '${topYear.value}本',
          icon: Icons.calendar_today,
          iconBg: const Color(0xFF4EC8E8),
        )),
      if (topYearTrips != null)
        SizedBox(width: cardWidth, child: card(
          label: '最高旅行年',
          value: '${topYearTrips.key}年',
          sub: '${topYearTrips.value}回',
          icon: Icons.flight,
          iconBg: const Color(0xFFFFD233),
        )),
      if (topYearCost != null)
        SizedBox(width: cardWidth, child: card(
          label: '最多費用年',
          value: '${topYearCost.key}年',
          sub: _yen(topYearCost.value),
          icon: Icons.attach_money,
          iconBg: const Color(0xFFFF9340),
        )),
      if (topTripByDives != null)
        SizedBox(width: cardWidth, child: tripDetailCard(
          label: '最も潜った旅行',
          entry: topTripByDives,
          icon: Icons.scuba_diving,
          iconBg: const Color(0xFF4EC8E8),
          mainValue: '${topTripByDives.cost.diveCount}本',
        )),
      if (topTripByCost != null)
        SizedBox(width: cardWidth, child: tripDetailCard(
          label: '最もお金を使った旅行',
          entry: topTripByCost,
          icon: Icons.wallet_outlined,
          iconBg: const Color(0xFFFF9340),
          mainValue: _yen(topTripByCost.cost.totalCost),
        )),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 8, height: 8,
            decoration: const BoxDecoration(color: Color(0xFF4EC8E8), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          const Text('アクティビティ',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A3A4A))),
        ]),
        const SizedBox(height: 8),
        if (filteredCards.isNotEmpty) ...[
          Wrap(spacing: 8, runSpacing: 8, children: filteredCards),
          const SizedBox(height: 16),
        ],
        if (allTimeCards.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('全期間', style: TextStyle(fontSize: 12, color: Color(0xFF6B8FA0), fontWeight: FontWeight.w600)),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: allTimeCards),
        ],
      ],
    );
  }

  // ─── グラフセクション ────────────────────────────

  static const _barOptions = {
    'bar_dives': '月別ダイブ本数',
    'bar_cost':  '月別コスト',
  };

  static const _lineOptions = {
    'line_monthly_cost_per_dive':    '月別単価',
    'line_cumulative_cost_per_dive': '累計単価',
    'line_monthly_dives':            '月別本数',
    'line_cumulative_dives':         '累計本数',
    'line_monthly_cost':             '月別コスト',
    'line_cumulative_cost':          '累計コスト',
  };

  Widget _buildChart(Color primary) {
    final months = _monthlyData;

    return _Section(
      label: 'グラフ',
      primary: primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Dropdown(
                  label: '棒グラフ',
                  value: _barMetric,
                  items: _barOptions,
                  onChanged: (v) => setState(() => _barMetric = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Dropdown(
                  label: '折れ線',
                  value: _lineMetric,
                  items: _lineOptions,
                  onChanged: (v) => setState(() => _lineMetric = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(width: 14, height: 14,
                  color: const Color(0xFF4EC8E8).withValues(alpha: 0.65)),
              const SizedBox(width: 4),
              Text(_barOptions[_barMetric] ?? '',
                  style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 12),
              Container(width: 18, height: 3,
                  color: const Color(0xFFFF9340)),
              const SizedBox(width: 4),
              Text(_lineOptions[_lineMetric] ?? '',
                  style: const TextStyle(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 280,
            child: months.length < 2
                ? Center(
                    child: Text(
                      months.isEmpty ? 'データなし' : '2ヶ月以上のデータが必要です',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  )
                : _CombinedChart(
                    months: months,
                    barValues: _barValues(months),
                    lineValues: _lineValues(months),
                    barColor: const Color(0xFF4EC8E8).withValues(alpha: 0.7),
                    axisFormatter: _axisLabel,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── 複合チャート ─────────────────────────────────────────────────────────────

class _CombinedChart extends StatelessWidget {
  const _CombinedChart({
    required this.months,
    required this.barValues,
    required this.lineValues,
    required this.barColor,
    required this.axisFormatter,
  });

  final List<_MonthData>        months;
  final List<double>            barValues;
  final List<double>            lineValues;
  final Color                   barColor;
  final String Function(double) axisFormatter;

  @override
  Widget build(BuildContext context) {
    final n        = months.length;
    final maxBar   = barValues.isEmpty  ? 1.0 : barValues.reduce(max)  * 1.25;
    final maxLine  = lineValues.isEmpty ? 1.0 : lineValues.reduce(max) * 1.25;
    final barWidth = n <= 6 ? 18.0 : (n <= 12 ? 12.0 : 7.0);
    final showEvery = n <= 6 ? 1 : (n <= 12 ? 2 : 3);

    const double lRes = 52, rRes = 52, bRes = 30, tRes = 6;

    return Stack(
      children: [
        BarChart(
          BarChartData(
            maxY: maxBar.clamp(1.0, double.infinity),
            barGroups: [
              for (int i = 0; i < barValues.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: barValues[i],
                      color: barColor,
                      width: barWidth,
                      borderRadius: const BorderRadius.only(
                        topLeft:  Radius.circular(3),
                        topRight: Radius.circular(3),
                      ),
                    ),
                  ],
                ),
            ],
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: lRes,
                  getTitlesWidget: (v, meta) {
                    if (v == meta.max) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        axisFormatter(v),
                        style: const TextStyle(fontSize: 9, color: Color(0xFF6B8FA0)),
                        textAlign: TextAlign.right,
                      ),
                    );
                  },
                ),
              ),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: rRes,
                  getTitlesWidget: (_, _) => const SizedBox.shrink(),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: bRes,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= n || i % showEvery != 0) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(months[i].shortLabel,
                          style: const TextStyle(fontSize: 9)),
                    );
                  },
                ),
              ),
              topTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: tRes,
                  getTitlesWidget: (_, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: Colors.grey[200]!, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
          ),
        ),

        if (lineValues.isNotEmpty)
          IgnorePointer(
            child: LineChart(
              LineChartData(
                backgroundColor: Colors.transparent,
                minX: 0,
                maxX: (n - 1).toDouble(),
                minY: 0,
                maxY: maxLine.clamp(1.0, double.infinity),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (int i = 0; i < lineValues.length; i++)
                        FlSpot(i.toDouble(), lineValues[i]),
                    ],
                    isCurved: true,
                    color: const Color(0xFFFF9340),
                    barWidth: 2.5,
                    dotData: FlDotData(
                      getDotPainter: (spot, pct, bar, idx) =>
                          FlDotCirclePainter(
                        radius: 3,
                        color: const Color(0xFFFF9340),
                        strokeColor: Colors.white,
                        strokeWidth: 1.5,
                      ),
                    ),
                  ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: lRes,
                      getTitlesWidget: (_, _) => const SizedBox.shrink(),
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: rRes,
                      getTitlesWidget: (v, meta) {
                        if (v == meta.max) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            axisFormatter(v),
                            style: const TextStyle(
                                fontSize: 9, color: Color(0xFFFF9340)),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: bRes,
                      getTitlesWidget: (_, _) => const SizedBox.shrink(),
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: tRes,
                      getTitlesWidget: (_, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── 集計テーブル ─────────────────────────────────────────────────────────────

class _GroupTable extends StatelessWidget {
  const _GroupTable({
    required this.data,
    required this.colLabel,
    required this.formatter,
  });
  final List<_GroupData>   data;
  final String             colLabel;
  final String Function(int) formatter;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: FlexColumnWidth(1.8),
          2: FlexColumnWidth(2.5),
          3: FlexColumnWidth(2.5),
        },
        children: [
          _header([colLabel, '本数', '合計コスト', '単価']),
          for (final d in data)
            _row([
              d.name,
              '${d.diveCount} 本',
              formatter(d.totalCost),
              d.costPerDive > 0 ? formatter(d.costPerDive) : '---',
            ]),
        ],
      ),
    );
  }
}

class _MonthTable extends StatelessWidget {
  const _MonthTable({required this.data, required this.formatter});
  final List<_MonthData>   data;
  final String Function(int) formatter;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.2),
          1: FlexColumnWidth(1.8),
          2: FlexColumnWidth(2.5),
          3: FlexColumnWidth(2.5),
        },
        children: [
          _header(['月', '本数', '合計コスト', '単価']),
          for (final d in data)
            _row([
              d.label,
              '${d.diveCount} 本',
              formatter(d.totalCost),
              d.costPerDive > 0 ? formatter(d.costPerDive) : '---',
            ]),
        ],
      ),
    );
  }
}

TableRow _header(List<String> cols) => TableRow(
  decoration: BoxDecoration(
    color: Colors.grey[100],
    border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
  ),
  children: cols
      .map((c) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Text(c,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ))
      .toList(),
);

TableRow _row(List<String> cells) => TableRow(
  decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.grey[100]!))),
  children: cells.asMap().entries
      .map((e) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Text(
              e.value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      e.key == 0 ? FontWeight.normal : FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ))
      .toList(),
);

// ─── 汎用ウィジェット ─────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.primary,
    required this.child,
  });
  final String label;
  final Color  primary;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800])),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          shadowColor: Colors.black12,
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ],
    );
  }
}

class _StatRow2 extends StatelessWidget {
  const _StatRow2({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: left),
      const SizedBox(width: 8),
      Expanded(child: right),
    ],
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

class _YearChip extends StatelessWidget {
  const _YearChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4EC8E8) : const Color(0xFFF0FAFE),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE8F8FC)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF4EC8E8),
          ),
        ),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String               label;
  final String               value;
  final Map<String, String>  items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            isDense: true,
            underline: const SizedBox.shrink(),
            items: items.entries
                .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value,
                          style: const TextStyle(fontSize: 12)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}
