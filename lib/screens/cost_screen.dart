import 'dart:convert';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip.dart';
import '../models/trip_cost.dart';

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
  List<_TripEntry> _entries = [];
  bool _isLoading = true;
  late TabController _tabController;

  String _barMetric  = 'bar_dives';
  String _lineMetric = 'line_monthly_cost_per_dive';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── データ読み込み ───────────────────────────────

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();

    List<Trip> trips = [];
    final tripsRaw = prefs.getString('saved_trips');
    if (tripsRaw != null) {
      try {
        final List decoded = jsonDecode(tripsRaw) as List;
        trips = decoded
            .map((e) => Trip.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('[CostScreen] saved_trips parse error: $e');
      }
    }

    final entries = <_TripEntry>[];
    for (final trip in trips) {
      TripCostData cost = TripCostData();
      final costRaw = prefs.getString('trip_${trip.id}_cost');
      if (costRaw != null) {
        try {
          cost = TripCostData.fromJson(
              jsonDecode(costRaw) as Map<String, dynamic>);
        } catch (e) {
          debugPrint('[CostScreen] cost parse error for ${trip.id}: $e');
        }
      }
      entries.add(_TripEntry(trip: trip, cost: cost));
    }

    debugPrint('[CostScreen] loaded ${entries.length} trips');

    if (!mounted) return;
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  // ─── 集計 ────────────────────────────────────────

  int get _totalDives         => _entries.fold(0, (s, e) => s + e.cost.diveCount);
  int get _totalCost          => _entries.fold(0, (s, e) => s + e.cost.totalCost);
  int get _totalDiveCost      => _entries.fold(0, (s, e) => s + e.cost.diveCost);
  int get _totalAccommodation => _entries.fold(0, (s, e) => s + e.cost.accommodation);
  int get _totalTransport     => _entries.fold(0, (s, e) => s + e.cost.transportTotal);
  int get _avgCostPerDive     => _totalDives > 0 ? _totalCost ~/ _totalDives : 0;

  List<_MonthData> get _monthlyData {
    final map = <String, _MonthData>{};
    for (final e in _entries) {
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
    for (final e in _entries) {
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
    for (final e in _entries) {
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
        title: const Text('コストレポート'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '再読み込み',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _buildEmpty()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSummary(primary),
                    const SizedBox(height: 20),
                    _buildTables(primary),
                    const SizedBox(height: 20),
                    _buildChart(primary),
                    const SizedBox(height: 32),
                  ],
                ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.bar_chart, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(
          '旅行データがありません',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        Text(
          '「旅行準備」タブから旅行を追加して\nコストを入力してください',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500]),
        ),
      ],
    ),
  );

  // ─── サマリーセクション ──────────────────────────

  Widget _buildSummary(Color primary) {
    return _Section(
      label: 'サマリー',
      primary: primary,
      child: Column(
        children: [
          _StatRow2(
            left:  _StatTile(label: '累計コスト',   value: _yen(_totalCost),    color: primary),
            right: _StatTile(label: 'ダイブ単価',   value: _totalDives > 0 ? _yen(_avgCostPerDive) : '---', color: Colors.deepOrange[700]!),
          ),
          const SizedBox(height: 8),
          _StatRow2(
            left:  _StatTile(label: '累計ダイブ費', value: _yen(_totalDiveCost),      color: Colors.blue[700]!),
            right: _StatTile(label: '累計宿泊費',   value: _yen(_totalAccommodation), color: Colors.orange[700]!),
          ),
          const SizedBox(height: 8),
          _StatRow2(
            left:  _StatTile(label: '累計交通費',   value: _yen(_totalTransport), color: Colors.purple[700]!),
            right: _StatTile(label: '累計ダイブ本数', value: '$_totalDives 本',     color: Colors.teal[700]!),
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
          // 凡例
          Row(
            children: [
              Container(width: 14, height: 14, color: primary.withValues(alpha: 0.65)),
              const SizedBox(width: 4),
              Text(_barOptions[_barMetric] ?? '',  style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 12),
              Container(width: 18, height: 3, color: Colors.orange),
              const SizedBox(width: 4),
              Text(_lineOptions[_lineMetric] ?? '', style: const TextStyle(fontSize: 11)),
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
                    barColor: primary.withValues(alpha: 0.65),
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
        // ── 棒グラフ（左軸）──
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
                        style: const TextStyle(fontSize: 9, color: Color(0xFF005F8A)),
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

        // ── 折れ線グラフ（右軸）──
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
                    color: Colors.orange,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      getDotPainter: (spot, pct, bar, idx) =>
                          FlDotCirclePainter(
                        radius: 3,
                        color: Colors.orange,
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
                                fontSize: 9, color: Colors.orange),
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
            Icon(Icons.circle, size: 10, color: primary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800])),
          ],
        ),
        const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: child)),
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
