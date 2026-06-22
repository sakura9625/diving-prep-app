import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/template_item.dart';
import '../utils/checklist_data.dart';
import '../widgets/sky_card.dart';

// ─── 画面 ─────────────────────────────────────────────────────────────────────

class TemplateScreen extends StatefulWidget {
  const TemplateScreen({super.key});

  @override
  State<TemplateScreen> createState() => _TemplateScreenState();
}

class _TemplateScreenState extends State<TemplateScreen> {
  final _db = FirebaseFirestore.instance;

  late Map<String, List<TemplateItem>> _genreItems;
  bool _isWetSuit   = true;
  bool _isOvernight = false;
  bool _isBoat      = true;
  final List<SavedTemplate> _savedTemplates = [];
  String? _loadedTemplateName;

  String _bagFilter = 'すべて';
  Map<String, String> _bagAssignments = {};
  Map<String, String> _masterBagDefaults = {};
  List<String> _customBags = [];

  @override
  void initState() {
    super.initState();
    _genreItems = createInitialGenreItems();
    _loadCustomItems();
    _loadSavedTemplates();
    _loadMasterBagDefaults();
    _loadCustomBags();
  }

  // ─── カスタム項目の永続化 ───────────────────────────

  Future<void> _loadCustomItems() async {
    try {
      final doc = await _db.collection('templateItems').doc('custom').get();
      if (!doc.exists) return;
      final items = (doc.data()!['items'] as List? ?? []);
      if (!mounted) return;
      setState(() {
        for (final item in items) {
          final genre = item['genre'] as String;
          if (_genreItems.containsKey(genre)) {
            _genreItems[genre]!.add(TemplateItem(
              id: item['id'] as String,
              name: item['name'] as String,
              genre: genre,
              isCustom: true,
              isChecked: true,
            ));
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _saveCustomItems() async {
    final items = _genreItems.values
        .expand((l) => l)
        .where((e) => e.isCustom)
        .map((e) => {'id': e.id, 'name': e.name, 'genre': e.genre})
        .toList();
    await _db.collection('templateItems').doc('custom').set({'items': items});
  }

  // ─── バッグ割り当て ─────────────────────────────────

  Future<void> _loadMasterBagDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('master_bag_defaults');
      if (raw == null) return;
      final map = Map<String, String>.from(jsonDecode(raw) as Map);
      if (!mounted) return;
      setState(() {
        _masterBagDefaults = map;
        _bagAssignments = Map.from(map);
        _applyBagAssignments();
      });
    } catch (_) {}
  }

  Future<void> _saveMasterBagDefaults() async {
    setState(() => _masterBagDefaults = Map.from(_bagAssignments));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('master_bag_defaults', jsonEncode(_bagAssignments));
    } catch (_) {}
    _showSnackBar('カバンのデフォルト割り当てを保存しました');
  }

  void _applyBagAssignments() {
    for (final items in _genreItems.values) {
      for (final item in items) {
        if (_bagAssignments.containsKey(item.id)) {
          item.bagName = _bagAssignments[item.id]!;
        }
      }
    }
  }

  Future<void> _setBagForItem(TemplateItem item, String bagName) async {
    setState(() {
      item.bagName = bagName;
      _bagAssignments[item.id] = bagName;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bag_assignments', jsonEncode(_bagAssignments));
    } catch (_) {}
  }

  Future<void> _loadCustomBags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bags = prefs.getStringList('custom_bag_names') ?? [];
      if (!mounted) return;
      setState(() => _customBags = bags);
    } catch (_) {}
  }

  Future<void> _addCustomBag(String name) async {
    setState(() => _customBags.add(name));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('custom_bag_names', _customBags);
    } catch (_) {}
  }

  void _resetToNewTemplate() {
    setState(() {
      _isWetSuit          = true;
      _isOvernight        = false;
      _isBoat             = true;
      _genreItems         = createInitialGenreItems();
      _loadedTemplateName = null;
      _bagAssignments     = Map.from(_masterBagDefaults);
      _applyBagAssignments();
    });
    _showSnackBar('新規テンプレートを作成します');
  }

  // ─── テンプレート永続化 ─────────────────────────────

  Future<void> _loadSavedTemplates() async {
    try {
      final snapshot = await _db.collection('templates').get();
      if (!mounted) return;
      setState(() {
        _savedTemplates
          ..clear()
          ..addAll(snapshot.docs
              .map((d) => SavedTemplate.fromJson(d.data())));
      });
    } catch (_) {}
  }

  Future<void> _persistSavedTemplates() async {
    try {
      final existing = await _db.collection('templates').get();
      final existingIds = existing.docs.map((d) => d.id).toSet();
      final currentIds  = _savedTemplates.map((t) => t.id).toSet();

      final batch = _db.batch();
      for (final id in existingIds.difference(currentIds)) {
        batch.delete(_db.collection('templates').doc(id));
      }
      for (final t in _savedTemplates) {
        batch.set(_db.collection('templates').doc(t.id), t.toJson());
      }
      await batch.commit();
    } catch (_) {}
  }

  // ─── テンプレート操作 ───────────────────────────────

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _saveTemplateData(String name, {int? overwriteIndex}) {
    final checkStates = <String, bool>{};
    final customItems = <Map<String, String>>[];
    for (final items in _genreItems.values) {
      for (final item in items) {
        checkStates[item.id] = item.isChecked;
        if (item.isCustom) {
          customItems.add({'id': item.id, 'name': item.name, 'genre': item.genre});
        }
      }
    }
    final template = SavedTemplate(
      id: overwriteIndex != null
          ? _savedTemplates[overwriteIndex].id
          : DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      isWetSuit: _isWetSuit,
      isOvernight: _isOvernight,
      isBoat: _isBoat,
      checkStates: checkStates,
      customItems: customItems,
    );
    setState(() {
      if (overwriteIndex != null) {
        _savedTemplates[overwriteIndex] = template;
      } else {
        _savedTemplates.add(template);
      }
    });
    _persistSavedTemplates();
  }

  void _loadTemplate(SavedTemplate template) {
    setState(() {
      _isWetSuit   = template.isWetSuit;
      _isOvernight = template.isOvernight;
      _isBoat      = template.isBoat;

      _genreItems = createInitialGenreItems();
      for (final items in _genreItems.values) {
        for (final item in items) {
          if (template.checkStates.containsKey(item.id)) {
            item.isChecked = template.checkStates[item.id]!;
          }
        }
      }

      for (final ci in template.customItems) {
        final genre = ci['genre']!;
        if (_genreItems.containsKey(genre)) {
          _genreItems[genre]!.add(TemplateItem(
            id: ci['id']!,
            name: ci['name']!,
            genre: genre,
            isCustom: true,
            isChecked: template.checkStates[ci['id']!] ?? true,
          ));
        }
      }

      _applyBagAssignments();
      _loadedTemplateName = template.name;
    });
    _showSnackBar('「${template.name}」を読み込みました');
  }

  void _showOverwriteConfirmDialog(String name, int existingIndex) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('上書き確認'),
        content: Text('「$name」はすでに存在します。上書きしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange[700]),
            onPressed: () {
              Navigator.pop(ctx);
              _saveTemplateData(name, overwriteIndex: existingIndex);
              _showSnackBar('「$name」を上書き保存しました');
            },
            child: const Text('上書き'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(SavedTemplate template) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('テンプレートを削除'),
        content: Text('「${template.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _savedTemplates.removeWhere((t) => t.id == template.id));
              _persistSavedTemplates();
              _showSnackBar('「${template.name}」を削除しました');
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  // ─── 状態ロジック ───────────────────────────────────

  bool _isGreyed(TemplateItem item) =>
      !item.isChecked && !item.isNaturallyActive(_isWetSuit, _isOvernight, _isBoat);

  void _toggle(TemplateItem item) =>
      setState(() => item.isChecked = !item.isChecked);

  void _syncChecked() {
    for (final items in _genreItems.values) {
      for (final item in items) {
        if (!item.isCustom) {
          item.isChecked = item.isNaturallyActive(_isWetSuit, _isOvernight, _isBoat);
        }
      }
    }
  }

  void _reorder(String genre, int oldIndex, int newIndex) {
    setState(() {
      final item = _genreItems[genre]!.removeAt(oldIndex);
      _genreItems[genre]!.insert(newIndex, item);
    });
  }

  // ─── ダイアログ ─────────────────────────────────────

  void _showAddItemDialog(String genre) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('「$genre」に追加'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '項目名',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              setState(() {
                _genreItems[genre]!.add(TemplateItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  genre: genre,
                  isCustom: true,
                  isChecked: true,
                ));
              });
              Navigator.pop(ctx);
              _saveCustomItems();
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  void _showSaveDialog() {
    final ctrl = TextEditingController(text: _loadedTemplateName ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('テンプレートを保存'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'テンプレート名',
            hintText: '例：沖縄夏ダイビング',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              final existingIdx = _savedTemplates.indexWhere((t) => t.name == name);
              Navigator.pop(ctx);
              if (existingIdx >= 0) {
                _showOverwriteConfirmDialog(name, existingIdx);
              } else {
                _saveTemplateData(name);
                _showSnackBar('「$name」を保存しました');
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // ─── build ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final primary  = Theme.of(context).colorScheme.primary;
    final allItems = _genreItems.values.expand((l) => l).toList();
    final totalReq = allItems
        .where((e) => e.isNaturallyActive(_isWetSuit, _isOvernight, _isBoat))
        .length;
    final totalChk = allItems
        .where((e) =>
            e.isChecked && e.isNaturallyActive(_isWetSuit, _isOvernight, _isBoat))
        .length;
    final allDone = totalReq > 0 && totalChk == totalReq;

    return Scaffold(
      appBar: AppBar(
        title: const Text('準備リストの設定'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Material(color: const Color(0xFFF9FEFF), child: ListView(
              children: [
                SkyCard(
                  title: '準備リストを設定',
                  subtitle: '$totalChk / $totalReq 項目チェック済み',
                  emoji: '📋',
                ),
                const ColoredBox(
                  color: Color(0xFFE8F8FC),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '準備リストのテンプレートを作成・保存できます。\nテンプレートを旅行に適用すると、準備リストを自動生成できます。',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B8FA0)),
                    ),
                  ),
                ),

                if (_savedTemplates.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '保存済みテンプレート',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                            letterSpacing: 0.5,
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            foregroundColor: const Color(0xFF4EC8E8),
                          ),
                          onPressed: () async {
                            final toEdit =
                                await Navigator.push<SavedTemplate?>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _TemplateListScreen(
                                  templates: _savedTemplates,
                                  onDelete: (t) {
                                    setState(() => _savedTemplates
                                        .removeWhere((e) => e.id == t.id));
                                    _persistSavedTemplates();
                                  },
                                ),
                              ),
                            );
                            if (toEdit != null && mounted) {
                              _loadTemplate(toEdit);
                            }
                          },
                          child: const Text('一覧を見る →', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 68,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _savedTemplates.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return GestureDetector(
                            onTap: _resetToNewTemplate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: const Color(0xFF4EC8E8),
                                    width: 1.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add,
                                      size: 18, color: Color(0xFF4EC8E8)),
                                  const SizedBox(height: 2),
                                  const Text(
                                    '新規',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4EC8E8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        final t = _savedTemplates[i - 1];
                        return _SavedTemplateCard(
                          template: t,
                          onTap: () => _loadTemplate(t),
                          onLongPress: () => _showDeleteConfirmDialog(t),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 12),
                ],

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ToggleLabel('スーツ種類'),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: true,
                              label: Text('ウェットスーツ'),
                              icon: Icon(Icons.waves, size: 16),
                            ),
                            ButtonSegment(
                              value: false,
                              label: Text('ドライスーツ'),
                              icon: Icon(Icons.ac_unit, size: 16),
                            ),
                          ],
                          selected: {_isWetSuit},
                          onSelectionChanged: (v) => setState(() {
                            _isWetSuit = v.first;
                            _syncChecked();
                          }),
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith((s) =>
                                s.contains(WidgetState.selected)
                                    ? const Color(0xFF4EC8E8)
                                    : Colors.grey[200]),
                            foregroundColor: WidgetStateProperty.resolveWith((s) =>
                                s.contains(WidgetState.selected)
                                    ? Colors.white
                                    : Colors.grey[700]),
                            iconColor: WidgetStateProperty.resolveWith((s) =>
                                s.contains(WidgetState.selected)
                                    ? Colors.white
                                    : Colors.grey[600]),
                            side: const WidgetStatePropertyAll(BorderSide.none),
                            shape: const WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(Radius.circular(24)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _ToggleLabel('旅行タイプ'),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              label: Text('日帰り'),
                              icon: Icon(Icons.wb_sunny_outlined, size: 16),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text('宿泊'),
                              icon: Icon(Icons.hotel, size: 16),
                            ),
                          ],
                          selected: {_isOvernight},
                          onSelectionChanged: (v) => setState(() {
                            _isOvernight = v.first;
                            _syncChecked();
                          }),
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith((s) =>
                                s.contains(WidgetState.selected)
                                    ? const Color(0xFF4EC8E8)
                                    : Colors.grey[200]),
                            foregroundColor: WidgetStateProperty.resolveWith((s) =>
                                s.contains(WidgetState.selected)
                                    ? Colors.white
                                    : Colors.grey[700]),
                            iconColor: WidgetStateProperty.resolveWith((s) =>
                                s.contains(WidgetState.selected)
                                    ? Colors.white
                                    : Colors.grey[600]),
                            side: const WidgetStatePropertyAll(BorderSide.none),
                            shape: const WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(Radius.circular(24)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _ToggleLabel('エントリー'),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: true,
                              label: Text('ボート'),
                              icon: Icon(Icons.directions_boat, size: 16),
                            ),
                            ButtonSegment(
                              value: false,
                              label: Text('ビーチ'),
                              icon: Icon(Icons.beach_access, size: 16),
                            ),
                          ],
                          selected: {_isBoat},
                          onSelectionChanged: (v) => setState(() {
                            _isBoat = v.first;
                            _syncChecked();
                          }),
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith((s) =>
                                s.contains(WidgetState.selected)
                                    ? const Color(0xFF4EC8E8)
                                    : Colors.grey[200]),
                            foregroundColor: WidgetStateProperty.resolveWith((s) =>
                                s.contains(WidgetState.selected)
                                    ? Colors.white
                                    : Colors.grey[700]),
                            iconColor: WidgetStateProperty.resolveWith((s) =>
                                s.contains(WidgetState.selected)
                                    ? Colors.white
                                    : Colors.grey[600]),
                            side: const WidgetStatePropertyAll(BorderSide.none),
                            shape: const WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(Radius.circular(24)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                  child: Row(
                    children: [
                      Icon(
                        allDone ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 14,
                        color: allDone ? const Color(0xFF4EC8E8) : Colors.grey[500],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$totalChk / $totalReq 項目チェック済み',
                        style: TextStyle(
                          fontSize: 13,
                          color: allDone ? const Color(0xFF4EC8E8) : Colors.grey[600],
                          fontWeight: allDone ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 8),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      'すべて',
                      'メッシュバッグ',
                      'バックパック',
                      '旅行ケース',
                      '未設定',
                    ].map((f) {
                      final sel = _bagFilter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            f,
                            style: TextStyle(
                              fontSize: 12,
                              color: sel
                                  ? Colors.white
                                  : const Color(0xFF4EC8E8),
                            ),
                          ),
                          selected: sel,
                          onSelected: (_) =>
                              setState(() => _bagFilter = f),
                          selectedColor: const Color(0xFF4EC8E8),
                          backgroundColor: Colors.white,
                          side: const BorderSide(
                              color: Color(0xFF4EC8E8), width: 0.8),
                          checkmarkColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                ...genreOrder.map(_buildGenreSection),
              ],
            )),
          ),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_bagAssignments.isNotEmpty) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _saveMasterBagDefaults,
                      icon: const Icon(Icons.bookmark_outline, size: 16, color: Color(0xFF6B8FA0)),
                      label: const Text('カバン割り当てをデフォルトとして保存'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6B8FA0),
                        side: const BorderSide(color: Color(0xFF6B8FA0)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _showSaveDialog,
                    icon: const Icon(Icons.save_outlined, size: 18, color: Colors.white),
                    label: const Text('このテンプレートを保存'),
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreSection(String genre) {
    final allItems = _genreItems[genre] ?? [];
    final color    = genreColor(genre);

    final displayItems = _bagFilter == 'すべて'
        ? allItems
        : _bagFilter == '未設定'
            ? allItems.where((e) => e.bagName.isEmpty).toList()
            : allItems.where((e) => e.bagName == _bagFilter).toList();

    if (displayItems.isEmpty && _bagFilter != 'すべて') return const SizedBox.shrink();

    final reqList    = allItems
        .where((e) => e.isNaturallyActive(_isWetSuit, _isOvernight, _isBoat))
        .toList();
    final checked    = reqList.where((e) => e.isChecked).length;
    final allDone    = reqList.isNotEmpty && checked == reqList.length;
    final totalCount = allItems.length;

    return ExpansionTile(
      initiallyExpanded: true,
      backgroundColor: color.withValues(alpha: 0.04),
      collapsedBackgroundColor: color.withValues(alpha: 0.02),
      leading: CircleAvatar(radius: 8, backgroundColor: color),
      title: Row(
        children: [
          Text(
            genre,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(width: 8),
          Text(
            '$checked/$totalCount',
            style: TextStyle(
              fontSize: 12,
              color: allDone ? Colors.green[700] : Colors.grey[500],
              fontWeight: allDone ? FontWeight.w700 : null,
            ),
          ),
        ],
      ),
      children: [
        if (_bagFilter == 'すべて')
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (oldIdx, newIdx) => _reorder(genre, oldIdx, newIdx),
            children: [
              for (int i = 0; i < allItems.length; i++)
                _ItemRow(
                  key: ValueKey(allItems[i].id),
                  item: allItems[i],
                  index: i,
                  isGreyed: _isGreyed(allItems[i]),
                  color: color,
                  onToggle: () => _toggle(allItems[i]),
                  onBagChanged: (bag) => _setBagForItem(allItems[i], bag),
                  customBags: _customBags,
                  onBagAdded: _addCustomBag,
                ),
            ],
          )
        else
          Column(
            children: [
              for (final item in displayItems)
                _ItemRow(
                  key: ValueKey(item.id),
                  item: item,
                  index: allItems.indexOf(item),
                  isGreyed: _isGreyed(item),
                  color: color,
                  onToggle: () => _toggle(item),
                  onBagChanged: (bag) => _setBagForItem(item, bag),
                  customBags: _customBags,
                  onBagAdded: _addCustomBag,
                  showDragHandle: false,
                ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _showAddItemDialog(genre),
              icon: Icon(Icons.add, size: 15, color: color),
              label: Text(
                '項目を追加',
                style: TextStyle(fontSize: 13, color: color),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 項目行 ───────────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required Key key,
    required this.item,
    required this.index,
    required this.isGreyed,
    required this.color,
    required this.onToggle,
    required this.onBagChanged,
    required this.customBags,
    required this.onBagAdded,
    this.showDragHandle = true,
  }) : super(key: key);

  final TemplateItem                  item;
  final int                           index;
  final bool                          isGreyed;
  final Color                         color;
  final VoidCallback                  onToggle;
  final ValueChanged<String>          onBagChanged;
  final List<String>                  customBags;
  final Future<void> Function(String) onBagAdded;
  final bool                          showDragHandle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Checkbox(
        value: item.isChecked,
        onChanged: (_) => onToggle(),
        activeColor: color,
        side: isGreyed
            ? const BorderSide(color: Color(0xFFBDBDBD), width: 1.2)
            : null,
        visualDensity: VisualDensity.compact,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: TextStyle(
                fontSize: 14,
                color: isGreyed ? const Color(0xFFBDBDBD) : null,
              ),
            ),
          ),
          if (item.isCustom)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'カスタム',
                style: TextStyle(fontSize: 9, color: color),
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.bagName.isNotEmpty) ...[
            Text(
              item.bagName,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B8FA0)),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 4),
          ],
          GestureDetector(
            onTap: () => _showBagPicker(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 18,
                color: item.bagName.isNotEmpty
                    ? const Color(0xFF4EC8E8)
                    : const Color(0xFFBDBDBD),
              ),
            ),
          ),
          if (showDragHandle)
            ReorderableDragStartListener(
              index: index,
              child: const Icon(
                  Icons.drag_handle, color: Color(0xFFBDBDBD), size: 20),
            ),
        ],
      ),
    );
  }

  Future<void> _showBagPicker(BuildContext context) async {
    const defaultOptions = ['メッシュバッグ', 'バックパック', '旅行ケース', '未設定'];
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) {
          final allOptions = [...defaultOptions, ...customBags];
          return SimpleDialog(
            title: const Text('バッグを選択'),
            children: [
              for (final bag in allOptions)
                SimpleDialogOption(
                  onPressed: () =>
                      Navigator.pop(ctx, bag == '未設定' ? '' : bag),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 18,
                        color: (bag == item.bagName ||
                                (bag == '未設定' && item.bagName.isEmpty))
                            ? const Color(0xFF4EC8E8)
                            : Colors.grey[600],
                      ),
                      const SizedBox(width: 12),
                      Text(bag, style: const TextStyle(fontSize: 14)),
                      const Spacer(),
                      if (bag == item.bagName ||
                          (bag == '未設定' && item.bagName.isEmpty))
                        const Icon(
                            Icons.check, size: 16, color: Color(0xFF4EC8E8)),
                    ],
                  ),
                ),
              const Divider(height: 1),
              SimpleDialogOption(
                onPressed: () async {
                  final newBag = await _showAddBagDialog(ctx);
                  if (newBag != null && newBag.isNotEmpty) {
                    await onBagAdded(newBag);
                    setDs(() {});
                  }
                },
                child: const Row(
                  children: [
                    Icon(Icons.add, size: 18, color: Color(0xFF4EC8E8)),
                    SizedBox(width: 12),
                    Text(
                      'カバンを追加',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4EC8E8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    if (result != null) onBagChanged(result);
  }

  static Future<String?> _showAddBagDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('カバン名を入力'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'カバン名',
            hintText: '例：フィッシュアイバッグ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx, name);
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }
}

// ─── 保存済みテンプレートカード ──────────────────────────────────────────────

class _SavedTemplateCard extends StatelessWidget {
  const _SavedTemplateCard({
    required this.template,
    required this.onTap,
    required this.onLongPress,
  });
  final SavedTemplate template;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: 148,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE8F8FC)),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: const Color(0xFF4EC8E8)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        template.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF1A3A4A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${template.isWetSuit ? "ウェット" : "ドライ"} · '
                        '${template.isOvernight ? "宿泊" : "日帰り"}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF6B8FA0)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── テンプレート一覧画面 ─────────────────────────────────────────────────────

class _TemplateListScreen extends StatefulWidget {
  const _TemplateListScreen({
    required this.templates,
    required this.onDelete,
  });
  final List<SavedTemplate> templates;
  final void Function(SavedTemplate) onDelete;

  @override
  State<_TemplateListScreen> createState() => _TemplateListScreenState();
}

class _TemplateListScreenState extends State<_TemplateListScreen> {
  late List<SavedTemplate> _templates;

  @override
  void initState() {
    super.initState();
    _templates = List.from(widget.templates);
  }

  Future<void> _showDeleteDialog(SavedTemplate t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('テンプレートを削除'),
        content: Text('「${t.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _templates.removeWhere((e) => e.id == t.id));
    widget.onDelete(t);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('保存済みテンプレート')),
      body: _templates.isEmpty
          ? const Center(
              child: Text('テンプレートがありません',
                  style: TextStyle(color: Color(0xFF6B8FA0))),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _templates.length,
              itemBuilder: (_, i) {
                final t = _templates[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.fromLTRB(16, 10, 8, 10),
                    title: Text(
                      t.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${t.isWetSuit ? 'ウェット' : 'ドライ'} · '
                        '${t.isOvernight ? '宿泊' : '日帰り'} · '
                        '${t.isBoat ? 'ボート' : 'ビーチ'}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B8FA0)),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF4EC8E8),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10),
                          ),
                          onPressed: () => Navigator.pop(context, t),
                          child: const Text('編集',
                              style: TextStyle(fontSize: 13)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Color(0xFFFF5B5B)),
                          tooltip: '削除',
                          onPressed: () => _showDeleteDialog(t),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ─── トグルラベル ─────────────────────────────────────────────────────────────

class _ToggleLabel extends StatelessWidget {
  const _ToggleLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
