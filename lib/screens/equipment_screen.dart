import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/equipment.dart';
import '../models/trip.dart';
import '../models/trip_cost.dart';

// --- アラートレベル ---
enum _AlertLevel { none, orange, red }

// --- ヘルパー関数 ---
int _daysSince(DateTime date) => DateTime.now().difference(date).inDays;

_AlertLevel _alertLevel(Equipment e, int totalDives) {
  final daysAlert  = _daysSince(e.lastMaintenanceDate) >= 365;
  final divesAlert = totalDives >= 100;
  if (daysAlert && divesAlert) return _AlertLevel.red;
  if (daysAlert || divesAlert) return _AlertLevel.orange;
  return _AlertLevel.none;
}

Color _alertColor(_AlertLevel level) {
  switch (level) {
    case _AlertLevel.orange: return Colors.orange;
    case _AlertLevel.red:    return Colors.red;
    case _AlertLevel.none:   return Colors.transparent;
  }
}

String _fmt(DateTime d) => '${d.year}年${d.month}月${d.day}日';

bool _isOnOrAfter(DateTime tripDate, DateTime maintenanceDate) {
  final t = DateTime(tripDate.year, tripDate.month, tripDate.day);
  final m = DateTime(maintenanceDate.year, maintenanceDate.month, maintenanceDate.day);
  return t.compareTo(m) >= 0;
}

// --- 画面 ---
class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({super.key});

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen>
    with WidgetsBindingObserver {
  List<Equipment> _equipments = [];
  Map<String, int> _tripDives = {}; // equipmentId -> 旅行由来のダイブ本数合計
  bool _isLoading = true;

  static const _equipKey = 'equipment_list';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  // アプリがフォアグラウンドに戻ったときに旅行データを再集計
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadTripDives();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ─── 永続化 ──────────────────────────────────────

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    List<Equipment> equipments = [];
    final raw = prefs.getString(_equipKey);
    if (raw != null) {
      try {
        equipments = (jsonDecode(raw) as List)
            .map((e) => Equipment.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    final tripDives = await _computeTripDives(equipments, prefs);

    if (!mounted) return;
    setState(() {
      _equipments = equipments;
      _tripDives  = tripDives;
      _isLoading  = false;
    });
  }

  Future<void> _saveEquipments() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _equipKey,
      jsonEncode(_equipments.map((e) => e.toJson()).toList()),
    );
  }

  // 旅行ダイブ本数のみ再集計（アプリ復帰時など）
  Future<void> _reloadTripDives() async {
    if (!mounted) return;
    final prefs     = await SharedPreferences.getInstance();
    final tripDives = await _computeTripDives(_equipments, prefs);
    if (mounted) setState(() => _tripDives = tripDives);
  }

  // ─── 旅行由来ダイブ本数の集計 ────────────────────

  Future<Map<String, int>> _computeTripDives(
    List<Equipment> equipments,
    SharedPreferences prefs,
  ) async {
    // 旅行リストを取得
    List<Trip> trips = [];
    final tripsRaw = prefs.getString('saved_trips');
    if (tripsRaw != null) {
      try {
        trips = (jsonDecode(tripsRaw) as List)
            .map((e) => Trip.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    final result = <String, int>{};
    for (final eq in equipments) {
      int total = 0;
      for (final trip in trips) {
        if (!_isOnOrAfter(trip.date, eq.lastMaintenanceDate)) continue;
        final costRaw = prefs.getString('trip_${trip.id}_cost');
        if (costRaw == null) continue;
        try {
          final cost = TripCostData.fromJson(
              jsonDecode(costRaw) as Map<String, dynamic>);
          total += cost.diveCount;
        } catch (_) {}
      }
      result[eq.id] = total;
    }
    return result;
  }

  // ─── 追加 / 編集ダイアログ ───────────────────────

  Future<void> _showEquipmentDialog({Equipment? equipment}) async {
    final isEdit         = equipment != null;
    var selectedType     = isEdit ? equipment.type : EquipmentType.bcd;
    var purchaseDate     = isEdit ? equipment.purchaseDate : DateTime.now();
    var maintenanceDate  = isEdit ? equipment.lastMaintenanceDate : DateTime.now();
    final nameCtrl       = TextEditingController(text: isEdit ? equipment.name : '');
    final divesCtrl      = TextEditingController(
      text: isEdit && equipment.divesManual > 0
          ? equipment.divesManual.toString()
          : '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) {
          Future<void> pickDate({
            required DateTime initial,
            required ValueChanged<DateTime> onPicked,
          }) async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: initial,
              firstDate: DateTime(2000),
              lastDate: DateTime(2035),
              locale: const Locale('ja', 'JP'),
            );
            if (picked != null) onPicked(picked);
          }

          return AlertDialog(
            title: Text(isEdit ? '器材を編集' : '器材を追加'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 器材種類
                  _FieldLabel('器材種類'),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButton<EquipmentType>(
                      value: selectedType,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      items: EquipmentType.values
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Row(
                                  children: [
                                    Icon(t.icon, size: 18),
                                    const SizedBox(width: 8),
                                    Text(t.label),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: (val) =>
                          setDs(() => selectedType = val!),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 器材名
                  _FieldLabel('器材名'),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      hintText: '例：Scubapro Hydros Pro',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 購入日
                  _FieldLabel('購入日'),
                  _DatePickerRow(
                    value: _fmt(purchaseDate),
                    onTap: () => pickDate(
                      initial: purchaseDate,
                      onPicked: (d) => setDs(() => purchaseDate = d),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 最終メンテナンス日
                  _FieldLabel('最終メンテナンス日'),
                  _DatePickerRow(
                    value: _fmt(maintenanceDate),
                    onTap: () => pickDate(
                      initial: maintenanceDate,
                      onPicked: (d) => setDs(() => maintenanceDate = d),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 前回メンテナンスからの使用本数
                  _FieldLabel('前回メンテナンスからの使用本数'),
                  TextField(
                    controller: divesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '0',
                      border: OutlineInputBorder(),
                      suffixText: '本',
                      helperText: '旅行データから自動集計した本数と合算されます',
                      helperMaxLines: 2,
                    ),
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
                  if (nameCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                child: Text(isEdit ? '保存' : '追加'),
              ),
            ],
          );
        },
      ),
    );

    final name        = nameCtrl.text.trim();
    final divesManual = int.tryParse(divesCtrl.text) ?? 0;
    nameCtrl.dispose();
    divesCtrl.dispose();

    if (saved != true || !mounted) return;

    if (isEdit) {
      setState(() {
        equipment.name                = name;
        equipment.type                = selectedType;
        equipment.purchaseDate        = purchaseDate;
        equipment.lastMaintenanceDate = maintenanceDate;
        equipment.divesManual         = divesManual;
      });
    } else {
      setState(() {
        _equipments.add(Equipment(
          id:                  DateTime.now().millisecondsSinceEpoch.toString(),
          name:                name,
          type:                selectedType,
          purchaseDate:        purchaseDate,
          lastMaintenanceDate: maintenanceDate,
          divesManual:         divesManual,
        ));
      });
    }

    await _saveEquipments();
    // メンテ日変更に備えてトリップダイブ本数を再集計
    final prefs     = await SharedPreferences.getInstance();
    final tripDives = await _computeTripDives(_equipments, prefs);
    if (mounted) setState(() => _tripDives = tripDives);
  }

  // ─── build ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('マイ器材'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ＋ 器材を追加ボタン
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showEquipmentDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('器材を追加'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.primary,
                        side: BorderSide(
                            color: Theme.of(context).colorScheme.primary),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),

                // 器材リスト
                Expanded(
                  child: _equipments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.backpack,
                                  size: 56, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text('器材を追加してください',
                                  style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 14)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: _equipments.length,
                          itemBuilder: (_, i) {
                            final e          = _equipments[i];
                            final tripCount  = _tripDives[e.id] ?? 0;
                            final totalDives = e.divesManual + tripCount;
                            final level      = _alertLevel(e, totalDives);
                            final days       = _daysSince(e.lastMaintenanceDate);
                            return _EquipmentCard(
                              equipment:           e,
                              alertLevel:          level,
                              alertColor:          _alertColor(level),
                              daysSinceMaintenance: days,
                              totalDives:          totalDives,
                              tripDives:           tripCount,
                              onEdit: () =>
                                  _showEquipmentDialog(equipment: e),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// --- 器材カード ---
class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({
    required this.equipment,
    required this.alertLevel,
    required this.alertColor,
    required this.daysSinceMaintenance,
    required this.totalDives,
    required this.tripDives,
    required this.onEdit,
  });

  final Equipment   equipment;
  final _AlertLevel alertLevel;
  final Color       alertColor;
  final int         daysSinceMaintenance;
  final int         totalDives;
  final int         tripDives;
  final VoidCallback onEdit;

  String _alertMessage() {
    final daysOver  = daysSinceMaintenance >= 365;
    final divesOver = totalDives >= 100;
    if (daysOver && divesOver) return '経過日数・ダイブ本数ともに超過しています';
    if (daysOver)              return '最終メンテナンスから365日を超えています';
    if (divesOver)             return '最終メンテナンスから100本を超えています';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final hasAlert = alertLevel != _AlertLevel.none;
    final e = equipment;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasAlert) Container(height: 4, color: alertColor),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 器材種類バッジ + 器材名 + アラート + 編集
                Row(
                  children: [
                    Icon(e.type.icon,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        e.type.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                    if (hasAlert)
                      Icon(Icons.warning_amber_rounded,
                          color: alertColor, size: 22),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: '編集',
                      onPressed: onEdit,
                      visualDensity: VisualDensity.compact,
                      color: Colors.grey[500],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 購入日・最終メンテ日
                _InfoRow(
                  icon: Icons.shopping_bag_outlined,
                  label: '購入日',
                  value: _fmt(e.purchaseDate),
                ),
                const SizedBox(height: 4),
                _InfoRow(
                  icon: Icons.build_outlined,
                  label: '最終メンテ',
                  value: _fmt(e.lastMaintenanceDate),
                ),
                const SizedBox(height: 12),

                // 経過日数・ダイブ本数チップ
                Row(
                  children: [
                    _StatChip(
                      label: '経過',
                      value: '$daysSinceMaintenance日',
                      highlight: daysSinceMaintenance >= 365,
                      alertColor: alertColor,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: 'ダイブ',
                      value: '$totalDives本',
                      highlight: totalDives >= 100,
                      alertColor: alertColor,
                    ),
                    if (tripDives > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(手動${e.divesManual}＋旅行$tripDives)',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),

                // アラートメッセージ
                if (hasAlert) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: alertColor.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(6),
                      border:
                          Border.all(color: alertColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: alertColor),
                        const SizedBox(width: 6),
                        Text(
                          _alertMessage(),
                          style: TextStyle(
                            fontSize: 12,
                            color: alertColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- 情報行 ---
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String   label;
  final String   value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text('$label：',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text(value, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// --- 統計チップ ---
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.highlight,
    required this.alertColor,
  });
  final String label;
  final String value;
  final bool   highlight;
  final Color  alertColor;

  @override
  Widget build(BuildContext context) {
    final fg     = highlight ? alertColor : Colors.grey[600]!;
    final bg     = highlight
        ? alertColor.withValues(alpha: 0.08)
        : Colors.grey[100]!;
    final border = highlight
        ? alertColor.withValues(alpha: 0.4)
        : Colors.grey[300]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ', style: TextStyle(fontSize: 11, color: fg)),
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

// --- ダイアログ内：フィールドラベル ---
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }
}

// --- ダイアログ内：日付選択行 ---
class _DatePickerRow extends StatelessWidget {
  const _DatePickerRow({required this.value, required this.onTap});
  final String       value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today,
                size: 18,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(value),
            const Spacer(),
            Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}
