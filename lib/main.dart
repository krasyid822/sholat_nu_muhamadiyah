// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:js' as js;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'config/app_env.dart';
import 'widgets/dashboard_tab.dart';
import 'widgets/calendar_tab.dart';
import 'widgets/hilal_tab.dart';
import 'widgets/settings_tab.dart';
import 'widgets/qibla_tab.dart';
import 'widgets/adsense_tab.dart';

void main() async {
  // Ensure Flutter engine and localizations are initialized
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);

  // Initialize Firebase — required for FCM and all Firebase services
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const ProviderScope(child: MyApp()));

  // Configure Web Push Messaging in the background without blocking the loading screen
  _configureWebPushMessaging();
}

Future<void> _configureWebPushMessaging() async {
  if (!kIsWeb) return;

  try {
    // Check if browser notification permission is blocked
    final htmlPermission = js.context['Notification']?['permission'];
    if (htmlPermission == 'denied') {
      debugPrint(
        'Web push setup skipped: Notification permission blocked by browser.',
      );
      return;
    }

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      return;
    }

    try {
      js.context.callMethod('getFcmTokenWithMainSW', [
        AppEnv.firebaseWebVapidKey,
      ]);

      // On Android Chrome PWA, service worker registration and FCM token
      // retrieval can take significantly longer (up to 30s) due to:
      // - First-time PWA install registering the Firebase SW
      // - IndexedDB initialization for token storage
      // - Network latency on mobile connections
      int elapsedMs = 0;
      const int maxWaitMs = 30000;
      while (js.context['fcmTokenReady'] != true && elapsedMs < maxWaitMs) {
        await Future.delayed(const Duration(milliseconds: 200));
        elapsedMs += 200;
      }

      if (js.context['fcmTokenReady'] == true) {
        final error = js.context['fcmTokenError'];
        if (error != null) {
          debugPrint('Error getting token via JS helper: $error');
          await FirebaseMessaging.instance.getToken(
            vapidKey: AppEnv.firebaseWebVapidKey,
          );
        }
      } else {
        debugPrint('Timeout getting token via JS helper after ${maxWaitMs}ms');
        await FirebaseMessaging.instance.getToken(
          vapidKey: AppEnv.firebaseWebVapidKey,
        );
      }
    } catch (e) {
      debugPrint('Error calling JS helper: $e');
      await FirebaseMessaging.instance.getToken(
        vapidKey: AppEnv.firebaseWebVapidKey,
      );
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Keep a foreground listener alive so web PWA receives data while open.
      final notification = message.notification;
      final title = notification?.title ?? message.data['title'] ?? 'Al-Waqt';
      final body =
          notification?.body ?? message.data['body'] ?? 'Ada notifikasi baru.';
      debugPrint('[FCM Foreground] $title - $body');

      // NOTE: The actual system notification for foreground messages is now
      // handled directly in JavaScript via messaging.onMessage() in index.html.
      // This is more reliable on Android Chrome PWA because it uses the
      // service worker registration directly without going through Dart-JS interop.
      //
      // We still play the notification sound from Dart since the JavaScript
      // onMessage handler only shows the visual notification.

      // Determine sound type (Adzan for simulated/real prayer time notifications, Beep for others)
      String soundType = 'beep';
      final lowercaseTitle = title.toLowerCase();
      final lowercaseBody = body.toLowerCase();

      final isPrayerTime =
          lowercaseTitle.contains('waktu') &&
          (lowercaseTitle.contains('subuh') ||
              lowercaseTitle.contains('dzuhur') ||
              lowercaseTitle.contains('ashar') ||
              lowercaseTitle.contains('maghrib') ||
              lowercaseTitle.contains('isya') ||
              lowercaseBody.contains('shalat') ||
              lowercaseBody.contains('sholat'));

      if (isPrayerTime) {
        soundType = 'adzan';
      }

      // Play notification sound (handled from Dart since audio context needs user gesture)
      try {
        js.context.callMethod('playNotificationSound', [soundType]);
      } catch (e) {
        debugPrint('Failed to play notification sound: $e');
      }
    });
  } catch (e) {
    debugPrint('Web push setup failed: $e');
  }
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
        scaffoldBackgroundColor: const Color(
          0xFF05120C,
        ), // Deep black-emerald canvas
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

  List<Widget> _buildTabs() {
    return const <Widget>[
      DashboardTab(),
      CalendarTab(),
      HilalTab(),
      QiblaTab(),
      AdsenseTab(),
      SettingsTab(),
    ];
  }

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
              ),
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
        child: _buildTabs()[_currentIndex],
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
          items: _buildNavItems(),
        ),
      ),
    );
  }

  List<BottomNavigationBarItem> _buildNavItems() {
    return const <BottomNavigationBarItem>[
      BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
      BottomNavigationBarItem(
        icon: Icon(Icons.calendar_today),
        label: 'Calendar',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.nightlight_round),
        label: 'Hilal',
      ),
      BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Kiblat'),
      BottomNavigationBarItem(
        icon: Icon(Icons.monetization_on),
        label: 'AdSense',
      ),
      BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
    ];
  }
}
