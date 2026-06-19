import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/travel_screen.dart';
import 'screens/template_screen.dart';
import 'screens/marine_life_screen.dart';
import 'screens/equipment_screen.dart';
import 'screens/cost_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('ja_JP', null);
  await _migrateFromSharedPrefs();
  runApp(const DivingPrepApp());
}

// ─── SharedPreferences → Firestore 一回限りの移行 ─────────────────────────────

Future<void> _migrateFromSharedPrefs() async {
  final db = FirebaseFirestore.instance;

  // 移行済みチェック
  try {
    final migDoc = await db.collection('metadata').doc('migration').get();
    if (migDoc.exists) return;
  } catch (_) {
    return; // Firestore 接続エラーの場合はスキップ
  }

  final prefs = await SharedPreferences.getInstance();
  final batch = db.batch();

  // ── 旅行 ──
  final tripsRaw = prefs.getString('saved_trips');
  if (tripsRaw != null) {
    try {
      final trips = jsonDecode(tripsRaw) as List;
      for (final t in trips) {
        final tripMap = t as Map<String, dynamic>;
        final id = tripMap['id'] as String;
        batch.set(db.collection('trips').doc(id), tripMap);

        final costRaw = prefs.getString('trip_${id}_cost');
        if (costRaw != null) {
          try {
            batch.set(db.collection('costs').doc(id),
                jsonDecode(costRaw) as Map<String, dynamic>);
          } catch (_) {}
        }

        final checksRaw = prefs.getString('trip_${id}_checks');
        if (checksRaw != null) {
          try {
            batch.set(db.collection('checks').doc(id),
                {'data': jsonDecode(checksRaw) as Map<String, dynamic>});
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  // ── テンプレート ──
  final templatesRaw = prefs.getString('saved_templates');
  if (templatesRaw != null) {
    try {
      final templates = jsonDecode(templatesRaw) as List;
      for (final t in templates) {
        final tmplMap = t as Map<String, dynamic>;
        final id = tmplMap['id'] as String;
        batch.set(db.collection('templates').doc(id), tmplMap);
      }
    } catch (_) {}
  }

  // ── 履歴 ──
  final locsRaw = prefs.getString('saved_locations');
  if (locsRaw != null) {
    try {
      batch.set(db.collection('history').doc('locations'),
          {'items': jsonDecode(locsRaw) as List});
    } catch (_) {}
  }
  final shopsRaw = prefs.getString('saved_shops');
  if (shopsRaw != null) {
    try {
      batch.set(db.collection('history').doc('shops'),
          {'items': jsonDecode(shopsRaw) as List});
    } catch (_) {}
  }

  // ── 見たい生物 ──
  final mlStateRaw = prefs.getString('marine_life_state');
  if (mlStateRaw != null) {
    try {
      batch.set(db.collection('marineLife').doc('state'),
          {'data': jsonDecode(mlStateRaw) as Map<String, dynamic>});
    } catch (_) {}
  }
  final mlCustomRaw = prefs.getString('marine_life_custom');
  if (mlCustomRaw != null) {
    try {
      batch.set(db.collection('marineLife').doc('custom'),
          {'items': jsonDecode(mlCustomRaw) as List});
    } catch (_) {}
  }

  // ── 器材 ──
  final equipRaw = prefs.getString('equipment_list');
  if (equipRaw != null) {
    try {
      final equipList = jsonDecode(equipRaw) as List;
      for (final e in equipList) {
        final equipMap = e as Map<String, dynamic>;
        final id = equipMap['id'] as String;
        batch.set(db.collection('equipment').doc(id), equipMap);
      }
    } catch (_) {}
  }

  // ── 準備リストカスタム項目 ──
  final tiCustomRaw = prefs.getString('diving_prep_custom_items');
  if (tiCustomRaw != null) {
    try {
      batch.set(db.collection('templateItems').doc('custom'),
          {'items': jsonDecode(tiCustomRaw) as List});
    } catch (_) {}
  }

  // 移行完了マーク
  batch.set(db.collection('metadata').doc('migration'), {'done': true});

  try {
    await batch.commit();
  } catch (_) {}
}

// ─── アプリ ───────────────────────────────────────────────────────────────────

class DivingPrepApp extends StatelessWidget {
  const DivingPrepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ダイビング準備アプリ',
      locale: const Locale('ja', 'JP'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', 'JP'),
      ],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0077B6),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF48CAE4),
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  int _equipmentRefreshKey = 0;
  int _costRefreshKey = 0;

  // EquipmentScreen・CostScreen はタブを開くたびに再構築して最新データを取得する
  static const _fixedScreens = [
    TravelScreen(),
    TemplateScreen(),
    MarineLifeScreen(),
  ];

  void _onItemTapped(int index) {
    if (index == 3) _equipmentRefreshKey++;
    if (index == 4) _costRefreshKey++;
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFCAF0F8), Color(0xFFD8F3DC)],
          ),
        ),
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            ..._fixedScreens,
            EquipmentScreen(key: ValueKey(_equipmentRefreshKey)),
            CostScreen(key: ValueKey(_costRefreshKey)),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF0077B6),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_rounded),
            label: '旅行準備',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.playlist_add),
            label: '準備リスト',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.phishing),
            label: '見たい生物',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.backpack),
            label: 'マイ器材',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'コスト',
          ),
        ],
      ),
    );
  }
}
