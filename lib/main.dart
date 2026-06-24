import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'screens/travel_screen.dart';
import 'screens/template_screen.dart';
import 'screens/marine_life_screen.dart';
import 'screens/equipment_screen.dart';
import 'screens/cost_screen.dart';
import 'services/equipment_alert_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('ja_JP', null);
  runApp(const DivingPrepApp());
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
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: equipmentAlertNotifier,
        builder: (context, hasAlert, _) {
          return DecoratedBox(
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
                BottomNavigationBarItem(
                  label: '器材',
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset('assets/icons/mask-solid-full.svg', width: 24, height: 24,
                            colorFilter: const ColorFilter.mode(Color(0xFFB0CDD5), BlendMode.srcIn)),
                          const SizedBox(height: 3),
                        ],
                      ),
                      if (hasAlert)
                        Positioned(
                          top: -2,
                          right: -4,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF5B5B),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  activeIcon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset('assets/icons/mask-solid-full.svg', width: 24, height: 24,
                            colorFilter: const ColorFilter.mode(Color(0xFF4EC8E8), BlendMode.srcIn)),
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
                      if (hasAlert)
                        Positioned(
                          top: -2,
                          right: -4,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF5B5B),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _navItem('assets/icons/fish-solid-full.svg', 'クエスト'),
                _navItem('assets/icons/chart-simple-solid-full.svg', 'レポート'),
                _navItem('assets/icons/gear-solid-full.svg', 'テンプレ'),
              ],
            ),
          );
        },
      ),
    );
  }
}
