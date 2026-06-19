import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/travel_screen.dart';
import 'screens/template_screen.dart';
import 'screens/marine_life_screen.dart';
import 'screens/equipment_screen.dart';
import 'screens/cost_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ja_JP', null);
  runApp(const DivingPrepApp());
}

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF005F8A),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
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
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          ..._fixedScreens,
          EquipmentScreen(key: ValueKey(_equipmentRefreshKey)),
          CostScreen(key: ValueKey(_costRefreshKey)),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF005F8A),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            // TODO: Flaticon SVG に差し替える場合は Icon(...) を SvgPicture.asset('assets/icons/travel.svg') に変更
            icon: Icon(Icons.shopping_bag_rounded),
            label: '旅行準備',
          ),
          BottomNavigationBarItem(
            // TODO: Flaticon SVG に差し替える場合は Icon(...) を SvgPicture.asset('assets/icons/checklist.svg') に変更
            icon: Icon(Icons.playlist_add),
            label: '準備リストの設定',
          ),
          BottomNavigationBarItem(
            // TODO: Flaticon SVG に差し替える場合は Icon(...) を SvgPicture.asset('assets/icons/fish.svg') に変更
            icon: Icon(Icons.phishing),
            label: '見たい生物',
          ),
          BottomNavigationBarItem(
            // TODO: Flaticon SVG に差し替える場合は Icon(...) を SvgPicture.asset('assets/icons/equipment.svg') に変更
            icon: Icon(Icons.backpack),
            label: 'マイ器材',
          ),
          BottomNavigationBarItem(
            // TODO: Flaticon SVG に差し替える場合は Icon(...) を SvgPicture.asset('assets/icons/cost.svg') に変更
            icon: Icon(Icons.bar_chart),
            label: 'コストレポート',
          ),
        ],
      ),
    );
  }
}
