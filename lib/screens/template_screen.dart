import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/template_item.dart';
import '../utils/checklist_data.dart';

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

  @override
  void initState() {
    super.initState();
    _genreItems = createInitialGenreItems();
    _loadCustomItems();
    _loadSavedTemplates();
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
            child: ListView(
              children: [
                Container(
                  color: Colors.blue[50],
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Text(
                    '自分用の準備リストをカスタマイズできます。\n'
                    'チェックを入れた項目が準備リストに表示されます。\n'
                    '複数の準備リストを保存でき、旅行準備タブで呼び出して使えます。',
                    style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                  ),
                ),

                if (_savedTemplates.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Text(
                      '保存済みテンプレート',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 68,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _savedTemplates.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => _SavedTemplateCard(
                        template: _savedTemplates[i],
                        onTap: () => _loadTemplate(_savedTemplates[i]),
                        onLongPress: () =>
                            _showDeleteConfirmDialog(_savedTemplates[i]),
                      ),
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
                                    ? const Color(0xFF0077B6)
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
                                    ? const Color(0xFF0077B6)
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
                                    ? const Color(0xFF0077B6)
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
                        allDone
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 14,
                        color: allDone ? Colors.green[700] : Colors.grey[500],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$totalChk / $totalReq 項目チェック済み',
                        style: TextStyle(
                          fontSize: 13,
                          color: allDone ? Colors.green[700] : Colors.grey[600],
                          fontWeight: allDone ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 8),

                ...genreOrder.map(_buildGenreSection),
              ],
            ),
          ),

          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _showSaveDialog,
                icon: const Icon(Icons.save_outlined),
                label: const Text('このテンプレートを保存'),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreSection(String genre) {
    final items   = _genreItems[genre] ?? [];
    final color   = genreColor(genre);
    final reqList = items
        .where((e) => e.isNaturallyActive(_isWetSuit, _isOvernight, _isBoat))
        .toList();
    final checked = reqList.where((e) => e.isChecked).length;
    final allDone = reqList.isNotEmpty && checked == reqList.length;
    final totalCount = items.length;

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
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (oldIdx, newIdx) => _reorder(genre, oldIdx, newIdx),
          children: [
            for (int i = 0; i < items.length; i++)
              _ItemRow(
                key: ValueKey(items[i].id),
                item: items[i],
                index: i,
                isGreyed: _isGreyed(items[i]),
                color: color,
                onToggle: () => _toggle(items[i]),
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
  }) : super(key: key);

  final TemplateItem item;
  final int          index;
  final bool         isGreyed;
  final Color        color;
  final VoidCallback onToggle;

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
      subtitle: item.bagName.isNotEmpty
          ? Text(
              item.bagName,
              style: const TextStyle(fontSize: 11, color: Color(0xFFBDBDBD)),
            )
          : null,
      trailing: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle,
            color: Color(0xFFBDBDBD), size: 20),
      ),
    );
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
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.25),
          border: Border.all(color: primary.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  template.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.touch_app, size: 11, color: primary.withValues(alpha: 0.5)),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '${template.isWetSuit ? "ウェット" : "ドライ"} · '
              '${template.isOvernight ? "宿泊" : "日帰り"} · '
              '${template.isBoat ? "ボート" : "ビーチ"}',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
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
