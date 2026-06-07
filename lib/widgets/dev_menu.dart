// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:js' as js;
import 'dart:async';
import 'package:intl/intl.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_env.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

class DevMenu extends StatefulWidget {
  const DevMenu({super.key});

  @override
  State<DevMenu> createState() => _DevMenuState();
}

class _DevMenuState extends State<DevMenu> {
  String? _token;
  String _permissionStatus = 'Checking...';
  String _lastMessage = '';
  bool _isLoading = false;
  String _selectedSimulatedPrayer = 'Subuh';
  String _serverTime = 'Belum dimuat...';
  Timer? _serverTimeTimer;
  int? _serverTimeOffsetMs;

  @override
  void initState() {
    super.initState();
    _loadToken();
    _checkPermission();
    _listenForMessages();
    _fetchServerTime();
  }

  @override
  void dispose() {
    _serverTimeTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadToken() async {
    setState(() => _isLoading = true);
    try {
      if (kIsWeb) {
        final permission = js.context['Notification']?['permission'];
        if (permission != 'granted') {
          debugPrint(
            '[DevMenu] Notification permission is $permission (not granted), but still trying to get token',
          );
        }
      }

      String? token;
      if (kIsWeb) {
        try {
          js.context.callMethod('getFcmTokenWithMainSW', [
            AppEnv.firebaseWebVapidKey,
          ]);

          // On Android Chrome PWA, token retrieval can take up to 30s
          // due to service worker registration and IndexedDB initialization.
          int elapsedMs = 0;
          const int maxWaitMs = 30000;
          while (js.context['fcmTokenReady'] != true && elapsedMs < maxWaitMs) {
            await Future.delayed(const Duration(milliseconds: 200));
            elapsedMs += 200;
          }

          if (js.context['fcmTokenReady'] == true) {
            final error = js.context['fcmTokenError'];
            if (error != null) {
              debugPrint('[DevMenu] Error getting token via JS helper: $error');
              debugPrint(
                '[DevMenu] Falling back to Flutter FirebaseMessaging.getToken()',
              );
              token = await FirebaseMessaging.instance.getToken(
                vapidKey: AppEnv.firebaseWebVapidKey,
              );
            } else {
              token = js.context['lastFcmToken'] as String?;
              debugPrint(
                '[DevMenu] Token obtained via JS helper: ${token?.substring(0, token.length > 20 ? 20 : token.length)}...',
              );
            }
          } else {
            debugPrint(
              '[DevMenu] Timeout getting token via JS helper after ${maxWaitMs}ms',
            );
            debugPrint(
              '[DevMenu] Falling back to Flutter FirebaseMessaging.getToken()',
            );
            token = await FirebaseMessaging.instance.getToken(
              vapidKey: AppEnv.firebaseWebVapidKey,
            );
          }
        } catch (e) {
          debugPrint('[DevMenu] Error calling JS helper: $e');
          debugPrint(
            '[DevMenu] Falling back to Flutter FirebaseMessaging.getToken()',
          );
          token = await FirebaseMessaging.instance.getToken(
            vapidKey: AppEnv.firebaseWebVapidKey,
          );
        }
      } else {
        token = await FirebaseMessaging.instance.getToken();
      }

      if (mounted) {
        setState(() {
          _token = token;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _token = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _forceRefreshToken() async {
    setState(() => _isLoading = true);
    try {
      String? token;
      if (kIsWeb) {
        try {
          js.context.callMethod('forceRefreshFcmToken', [
            AppEnv.firebaseWebVapidKey,
          ]);

          int elapsedMs = 0;
          const int maxWaitMs = 30000;
          while (js.context['fcmTokenReady'] != true && elapsedMs < maxWaitMs) {
            await Future.delayed(const Duration(milliseconds: 200));
            elapsedMs += 200;
          }

          if (js.context['fcmTokenReady'] == true) {
            final error = js.context['fcmTokenError'];
            if (error != null) {
              debugPrint('[DevMenu] Force-refresh error: $error');
              token = await FirebaseMessaging.instance.getToken(
                vapidKey: AppEnv.firebaseWebVapidKey,
              );
            } else {
              token = js.context['lastFcmToken'] as String?;
            }
          } else {
            debugPrint('[DevMenu] Force-refresh timeout');
            token = await FirebaseMessaging.instance.getToken(
              vapidKey: AppEnv.firebaseWebVapidKey,
            );
          }
        } catch (e) {
          debugPrint('[DevMenu] Force-refresh JS call failed: $e');
          token = await FirebaseMessaging.instance.getToken(
            vapidKey: AppEnv.firebaseWebVapidKey,
          );
        }
      } else {
        token = await FirebaseMessaging.instance.getToken();
      }

      if (mounted) {
        setState(() {
          _token = token;
          _isLoading = false;
        });
        if (token != null && token.isNotEmpty) {
          _showSnack('Token berhasil di-refresh!');
        } else {
          _showSnack('Gagal mendapatkan token setelah refresh');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _token = 'Error: $e';
          _isLoading = false;
        });
        _showSnack('Error: $e');
      }
    }
  }

  Future<void> _checkPermission() async {
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (mounted) {
        setState(() => _permissionStatus = settings.authorizationStatus.name);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _permissionStatus = 'Error: $e');
      }
    }
  }

  Future<void> _requestPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (mounted) {
        setState(() => _permissionStatus = settings.authorizationStatus.name);
        _showSnack('Permission: ${settings.authorizationStatus.name}');
      }
    } catch (e) {
      if (mounted) _showSnack('Error requesting permission: $e');
    }
  }

  void _listenForMessages() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (mounted) {
        setState(() {
          _lastMessage =
              '[Foreground] ${message.notification?.title ?? "No title"}: '
              '${message.notification?.body ?? "No body"}\n'
              'Data: ${message.data}';
        });
        _showSnack(
          '📩 Pesan diterima: ${message.notification?.title ?? "FCM Message"}',
        );
      }
    });

    // When user taps notification and app opens
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (mounted) {
        setState(() {
          _lastMessage =
              '[Opened] ${message.notification?.title ?? "No title"}: '
              '${message.notification?.body ?? "No body"}\n'
              'Data: ${message.data}';
        });
      }
    });
  }

  Future<void> _fetchServerTime() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final clientEpochBefore = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse(
        'https://getservertime-ebadp63kua-uc.a.run.app',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final serverEpoch = data['epoch'] as int;

        final clientEpochAfter = DateTime.now().millisecondsSinceEpoch;
        final clientEpochMidpoint = (clientEpochBefore + clientEpochAfter) ~/ 2;

        _serverTimeOffsetMs = serverEpoch - clientEpochMidpoint;
        _updateTickingServerTime();
        _startServerTimeTimer();
      } else {
        if (mounted) {
          setState(() {
            _serverTime = 'Gagal memuat: Kode ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _serverTime = 'Error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startServerTimeTimer() {
    _serverTimeTimer?.cancel();
    _serverTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTickingServerTime();
    });
  }

  void _updateTickingServerTime() {
    if (_serverTimeOffsetMs == null) return;
    final nowClient = DateTime.now().millisecondsSinceEpoch;
    final nowServerEpoch = nowClient + _serverTimeOffsetMs!;
    final nowServerDateTime = DateTime.fromMillisecondsSinceEpoch(
      nowServerEpoch,
    );

    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final formattedLocal = formatter.format(nowServerDateTime.toLocal());
    final formattedUtc = formatter.format(nowServerDateTime.toUtc());

    if (mounted) {
      setState(() {
        _serverTime = '$formattedLocal WIB/Lokal\n$formattedUtc UTC';
      });
    }
  }

  Future<void> _sendLocalTestNotification() async {
    if (kIsWeb) {
      try {
        js.context.callMethod('showLocalNotification', [
          '🕌 Tes Notifikasi Al-Waqt',
          'Ini adalah notifikasi percobaan dari Dev Menu. Waktu: ${DateTime.now().toLocal()}',
        ]);
        if (mounted) {
          _showSnack('✅ Notifikasi lokal dikirim!');
          setState(() {
            _lastMessage =
                '[Local Web] Notifikasi tes dikirim pada ${DateTime.now().toLocal()}';
          });
        }
      } catch (e) {
        if (mounted) _showSnack('❌ Gagal kirim notifikasi: $e');
      }
    } else {
      if (mounted) {
        _showSnack(
          'ℹ️ Local notification hanya tersedia di web (gunakan flutter_local_notifications untuk mobile)',
        );
      }
    }
  }

  Future<void> _sendAdhanTestNotification() async {
    if (kIsWeb) {
      try {
        js.context.callMethod('showLocalNotification', [
          '🕌 Waktu Sholat Maghrib',
          'Telah masuk waktu sholat Maghrib untuk wilayah Jakarta. Segera laksanakan sholat.',
        ]);
        if (mounted) {
          _showSnack('✅ Notifikasi adzan tes dikirim!');
          setState(() {
            _lastMessage =
                '[Adhan Test] Notifikasi adzan tes dikirim pada ${DateTime.now().toLocal()}';
          });
        }
      } catch (e) {
        if (mounted) _showSnack('❌ Gagal kirim notifikasi: $e');
      }
    } else {
      if (mounted) _showSnack('ℹ️ Hanya tersedia di web');
    }
  }

  Future<void> _sendServerPushNotification() async {
    if (_token == null || _token!.isEmpty || _token!.startsWith('Error')) {
      _showSnack('❌ FCM Token tidak valid atau belum dimuat');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Production region-based function URL for V2
      final functionUrl =
          'https://testpushnotification-ebadp63kua-uc.a.run.app';
      final fallbackUrl =
          'https://testpushnotification-ebadp63kua-uc.a.run.app';

      var targetUrl = functionUrl;

      // Let's perform POST request
      final response = await http
          .post(
            Uri.parse(targetUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'token': _token,
              'title': '🕌 Tes Push Server-Side',
              'body':
                  'Sukses! Ini adalah push notification asli dikirim langsung dari Firebase Cloud Functions.',
            }),
          )
          .timeout(const Duration(seconds: 5))
          .catchError((_) async {
            return await http
                .post(
                  Uri.parse(fallbackUrl),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    'token': _token,
                    'title': '🕌 Tes Push Server-Side',
                    'body':
                        'Sukses! Ini adalah push notification asli dikirim langsung dari Firebase Cloud Functions.',
                  }),
                )
                .timeout(const Duration(seconds: 5));
          });

      if (response.statusCode == 200) {
        _showSnack('✅ Server Push berhasil dikirim!');
        setState(() {
          _lastMessage =
              '[Server Push] Sukses mengirim push ke token pada ${DateTime.now().toLocal()}\nResponse: ${response.body}';
        });
      } else {
        _showSnack('❌ Server Push gagal: Kode ${response.statusCode}');
        setState(() {
          _lastMessage =
              '[Server Push] Gagal (Kode ${response.statusCode})\nDetail: ${response.body}';
        });
      }
    } catch (e) {
      _showSnack('❌ Hubungan ke server gagal: $e');
      setState(() {
        _lastMessage =
            '[Server Push] Gagal menghubungi Cloud Function.\nError: $e\n\nTips: Jika berjalan secara lokal di emulator, pastikan emulator functions sudah dinyalakan.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendSimulatedAdhanNotification(
    String prayerName,
    String topic,
  ) async {
    setState(() => _isLoading = true);

    try {
      final targetUrl = 'https://simulatescheduler-ebadp63kua-uc.a.run.app';
      final fallbackUrl =
          'https://simulatescheduler-ebadp63kua-uc.a.run.app';

      // Let's perform POST request
      final response = await http
          .post(
            Uri.parse(targetUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'topic': topic, 'prayerName': prayerName}),
          )
          .timeout(const Duration(seconds: 5))
          .catchError((_) async {
            return await http
                .post(
                  Uri.parse(fallbackUrl),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({'topic': topic, 'prayerName': prayerName}),
                )
                .timeout(const Duration(seconds: 5));
          });

      if (response.statusCode == 200) {
        _showSnack('✅ Simulasi $prayerName berhasil dikirim!');
        setState(() {
          _lastMessage =
              '[Simulasi $prayerName] Sukses dikirim ke topik $topic pada ${DateTime.now().toLocal()}\nResponse: ${response.body}';
        });
      } else {
        _showSnack('❌ Simulasi gagal: Kode ${response.statusCode}');
        setState(() {
          _lastMessage =
              '[Simulasi $prayerName] Gagal (Kode ${response.statusCode})\nDetail: ${response.body}';
        });
      }
    } catch (e) {
      _showSnack('❌ Hubungan ke server gagal: $e');
      setState(() {
        _lastMessage =
            '[Simulasi] Gagal menghubungi Cloud Function.\nError: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _subscribeToTopic(String topic) async {
    if (_token == null || _token!.isEmpty || _token!.startsWith('Error')) {
      _showSnack('❌ Token FCM kosong. Tidak bisa mendaftar topik.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
        'https://subscribetotopic-ebadp63kua-uc.a.run.app',
      );
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'token': _token, 'topic': topic}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        if (mounted) _showSnack('✅ Sukses mendaftar ke topik "$topic"');
        setState(() {
          _lastMessage =
              '[Subscribe Topic] Sukses mendaftar token ke topik "$topic" via Server.\nResponse: ${response.body}';
        });
      } else {
        if (mounted) {
          _showSnack('❌ Gagal daftar topik: Kode ${response.statusCode}');
        }
        setState(() {
          _lastMessage =
              '[Subscribe Topic] Gagal (Kode ${response.statusCode})\nDetail: ${response.body}';
        });
      }
    } catch (e) {
      if (mounted) _showSnack('❌ Gagal menghubungi server: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unsubscribeFromTopic(String topic) async {
    if (_token == null || _token!.isEmpty || _token!.startsWith('Error')) {
      _showSnack('❌ Token FCM kosong.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
        'https://unsubscribefromtopic-ebadp63kua-uc.a.run.app',
      );
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'token': _token, 'topic': topic}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        if (mounted) _showSnack('✅ Sukses keluar dari topik "$topic"');
        setState(() {
          _lastMessage =
              '[Unsubscribe Topic] Sukses menghapus token dari topik "$topic" via Server.\nResponse: ${response.body}';
        });
      } else {
        if (mounted) {
          _showSnack('❌ Gagal keluar topik: Kode ${response.statusCode}');
        }
        setState(() {
          _lastMessage =
              '[Unsubscribe Topic] Gagal (Kode ${response.statusCode})\nDetail: ${response.body}';
        });
      }
    } catch (e) {
      if (mounted) _showSnack('❌ Gagal menghubungi server: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyToken() {
    if (_token != null && _token!.isNotEmpty && !_token!.startsWith('Error')) {
      Clipboard.setData(ClipboardData(text: _token!));
      _showSnack('📋 Token disalin ke clipboard');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    const cardColor = Color(0xFF0C1913);
    const surfaceColor = Color(0xFF112A1E);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Row(
              children: [
                Icon(Icons.developer_mode, color: gold, size: 28),
                SizedBox(width: 10),
                Text(
                  'FCM Testing Tools',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: gold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // === Status Card ===
            _buildCard(
              title: '📡 Status',
              cardColor: cardColor,
              children: [
                _statusRow(
                  'Permission',
                  _permissionStatus,
                  _permissionStatus == 'authorized'
                      ? Colors.green
                      : Colors.orange,
                ),
                const Divider(color: Colors.white12),
                _statusRow(
                  'Firebase',
                  _token == null
                      ? 'Loading...'
                      : (_token!.startsWith('Error') ? 'Gagal' : 'Terhubung'),
                  _token != null && !_token!.startsWith('Error')
                      ? Colors.green
                      : Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // === Token Card ===
            _buildCard(
              title: '🔑 FCM Token',
              cardColor: cardColor,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: gold),
                        )
                      : SelectableText(
                          _token ?? 'Token tidak tersedia',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color:
                                _token != null && !_token!.startsWith('Error')
                                ? Colors.white70
                                : Colors.redAccent,
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        icon: Icons.copy,
                        label: 'Copy Token',
                        onPressed: _copyToken,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _actionButton(
                        icon: Icons.refresh,
                        label: 'Refresh',
                        onPressed: _loadToken,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: _actionButton(
                    icon: Icons.autorenew,
                    label: 'Force Refresh Token (Clear & Re-register)',
                    onPressed: _forceRefreshToken,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // === Permission Card ===
            _buildCard(
              title: '🔐 Permission',
              cardColor: cardColor,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: _actionButton(
                    icon: Icons.notifications_active,
                    label: 'Request Notification Permission',
                    onPressed: _requestPermission,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: _actionButton(
                    icon: Icons.cleaning_services_rounded,
                    label: 'Force Clear Cache & Update SW',
                    onPressed: () {
                      if (kIsWeb) {
                        js.context.callMethod('forceRefreshAppCache');
                      }
                    },
                    color: Colors.redAccent.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // === Test Notification Card ===
            _buildCard(
              title: '🔔 Tes Notifikasi',
              cardColor: cardColor,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: _actionButton(
                    icon: Icons.send,
                    label: 'Kirim Notifikasi Tes',
                    onPressed: _sendLocalTestNotification,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: _actionButton(
                    icon: Icons.mosque,
                    label: 'Tes Notifikasi Adzan',
                    onPressed: _sendAdhanTestNotification,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: _actionButton(
                    icon: Icons.cloud_upload_rounded,
                    label: 'Tes Push Server-Side (FCM)',
                    onPressed: _sendServerPushNotification,
                    color: Colors.deepOrange.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Catatan: Notifikasi lokal menggunakan Web Notification API. '
                  'Pastikan permission sudah diberikan.',
                  style: TextStyle(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // === Simulated Notification Card ===
            _buildCard(
              title: '🕌 Simulasi Jadwal Sholat (Server-Side)',
              cardColor: cardColor,
              children: [
                const Text(
                  'Menguji alur lengkap astronomi jadwal sholat & pengiriman push FCM server secara instan tanpa menunggu waktu sholat tiba.',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Consumer(
                  builder: (context, ref, child) {
                    ref.watch(settingsProvider);
                    final topic = ref
                        .read(settingsProvider.notifier)
                        .getFcmTopic();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: SelectableText(
                            'Topik Aktif: $topic',
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: Colors.white54,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          dropdownColor: cardColor,
                          decoration: InputDecoration(
                            labelText: 'Pilih Waktu Sholat',
                            labelStyle: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: surfaceColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          value: _selectedSimulatedPrayer,
                          items: const [
                            DropdownMenuItem(
                              value: 'Imsak',
                              child: Text(
                                'Imsak',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Subuh',
                              child: Text(
                                'Subuh',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Syuruq',
                              child: Text(
                                'Syuruq',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Dzuhur',
                              child: Text(
                                'Dzuhur',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Ashar',
                              child: Text(
                                'Ashar',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Maghrib',
                              child: Text(
                                'Maghrib',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Isya',
                              child: Text(
                                'Isya',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedSimulatedPrayer = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: _actionButton(
                            icon: Icons.play_arrow_rounded,
                            label: 'Kirim Simulasi Adzan Server',
                            onPressed: () => _sendSimulatedAdhanNotification(
                              _selectedSimulatedPrayer,
                              topic,
                            ),
                            color: Colors.indigo.shade800,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // === Topic Subscription Card ===
            _buildCard(
              title: '📬 Topic Subscription',
              cardColor: cardColor,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        icon: Icons.add_circle_outline,
                        label: 'Subscribe "test"',
                        onPressed: () => _subscribeToTopic('test'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _actionButton(
                        icon: Icons.remove_circle_outline,
                        label: 'Unsubscribe "test"',
                        onPressed: () => _unsubscribeFromTopic('test'),
                        color: Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        icon: Icons.add_circle_outline,
                        label: 'Subscribe "adzan"',
                        onPressed: () => _subscribeToTopic('adzan'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _actionButton(
                        icon: Icons.remove_circle_outline,
                        label: 'Unsubscribe "adzan"',
                        onPressed: () => _unsubscribeFromTopic('adzan'),
                        color: Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // === Server Time Card ===
            _buildCard(
              title: '⏰ Jam Server Firebase (WIB)',
              cardColor: cardColor,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _serverTime,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: _actionButton(
                    icon: Icons.access_time_rounded,
                    label: 'Perbarui Jam Server',
                    onPressed: _fetchServerTime,
                    color: Colors.blueGrey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // === Message Log Card ===
            _buildCard(
              title: '📋 Log Pesan Terakhir',
              cardColor: cardColor,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  constraints: const BoxConstraints(minHeight: 60),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _lastMessage.isEmpty
                        ? 'Belum ada pesan diterima...'
                        : _lastMessage,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: _lastMessage.isEmpty
                          ? Colors.white24
                          : Colors.greenAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required Color cardColor,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? const Color(0xFF1A3D2E),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
