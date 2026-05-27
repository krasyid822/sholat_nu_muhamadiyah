import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'widgets/dashboard_tab.dart';
import 'widgets/calendar_tab.dart';
import 'widgets/hilal_tab.dart';
import 'widgets/settings_tab.dart';

void main() async {
  // Ensure Flutter engine and localizations are initialized
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sholat NU & Muhammadiyah',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF05120C), // Deep black-emerald canvas
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD4AF37), // Islamic Gold
          secondary: Color(0xFF0F5A3E), // Deep Emerald
          surface: Color(0xFF0C1913),
        ),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const DashboardTab(),
    const CalendarTab(),
    const HilalTab(),
    const SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1913),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'AL-WAQT',
          style: GoogleFonts.outfit(
            color: const Color(0xFFD4AF37),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 4.0,
            shadows: [
              Shadow(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                blurRadius: 10,
              )
            ],
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
            height: 1,
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _tabs[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: const Color(0xFF0C1913),
          selectedItemColor: const Color(0xFFD4AF37),
          unselectedItemColor: Colors.white38,
          selectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.alarm_rounded),
              activeIcon: Icon(Icons.alarm_on_rounded),
              label: 'Jadwal',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month_rounded),
              label: 'Kalender',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.visibility_outlined),
              activeIcon: Icon(Icons.visibility_rounded),
              label: 'Hilal',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: 'Pengaturan',
            ),
          ],
        ),
      ),
    );
  }
}
