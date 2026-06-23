import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
          seedColor: const Color(0xFF4EC8E8),
          primary: const Color(0xFF4EC8E8),
          onPrimary: Colors.white,
          secondary: const Color(0xFFFF9340),
          onSecondary: Colors.white,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF9FEFF),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A3A4A),
          elevation: 0,
          shadowColor: Colors.transparent,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF1A3A4A),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: Colors.black12,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF4EC8E8),
          unselectedItemColor: Color(0xFFB0CDD5),
          elevation: 0,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFF9340),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
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

  void _onItemTapped(int index) {
    if (index == 1) _equipmentRefreshKey++;
    if (index == 3) _costRefreshKey++;
    setState(() => _selectedIndex = index);
  }

  BottomNavigationBarItem _navItem(
    String svgPath,
    String label,
  ) {
    return BottomNavigationBarItem(
      label: label,
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(svgPath, width: 24, height: 24, colorFilter: const ColorFilter.mode(Color(0xFFB0CDD5), BlendMode.srcIn)),
          const SizedBox(height: 3),
        ],
      ),
      activeIcon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(svgPath, width: 24, height: 24, colorFilter: const ColorFilter.mode(Color(0xFF4EC8E8), BlendMode.srcIn)),
          Container(
            margin: const EdgeInsets.only(top: 3),
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFF4EC8E8),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const TravelScreen(),
          EquipmentScreen(key: ValueKey(_equipmentRefreshKey)),
          const MarineLifeScreen(),
          CostScreen(key: ValueKey(_costRefreshKey)),
          const TemplateScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
              top: BorderSide(color: Color(0xFFE8F8FC), width: 1.5)),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: [
            _navItem('assets/icons/sailboat-solid-full.svg', '旅行準備'),
            _navItem('assets/icons/mask-solid-full.svg', '器材'),
            _navItem('assets/icons/fish-solid-full.svg', 'クエスト'),
            _navItem('assets/icons/chart-simple-solid-full.svg', 'コスト'),
            _navItem('assets/icons/gear-solid-full.svg', 'テンプレート'),
          ],
        ),
      ),
    );
  }
}
