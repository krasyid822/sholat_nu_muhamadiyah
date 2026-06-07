// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:js' as js;
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/app_settings.dart';
import '../data/cities.dart';
import '../config/app_env.dart';

class SettingsNotifier extends StateNotifier<AppSettings> {
  Timer? _gpsAutoUpdateTimer;

  SettingsNotifier() : super(AppSettings.initial()) {
    _loadSettings();
  }

  static const String _keyCalcMethod = 'calc_method';
  static const String _keyLocationMode = 'location_mode';
  static const String _keySelectedCity = 'selected_city';
  static const String _keyCustomLat = 'custom_lat';
  static const String _keyCustomLng = 'custom_lng';
  static const String _keyGpsLat = 'gps_lat';
  static const String _keyGpsLng = 'gps_lng';
  static const String _keyGpsAlt = 'gps_alt';
  static const String _keyGpsLocName = 'gps_loc_name';
  static const String _keyUseIhtiyati = 'use_ihtiyati';
  static const String _keyIsDarkMode = 'is_dark_mode';
  static const String _keyEnableNotifications = 'enable_notifications';
  static const String _keyKeepScreenOn = 'keep_screen_on';
  static const String _keyHijriOffset = 'hijri_offset';
  static const String _keyIsbatDate = 'isbat_date';

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final calcMethodIndex = prefs.getInt(_keyCalcMethod);
      final locationModeIndex = prefs.getInt(_keyLocationMode);
      final selectedCity = prefs.getString(_keySelectedCity);
      final customLat = prefs.getDouble(_keyCustomLat);
      final customLng = prefs.getDouble(_keyCustomLng);
      final gpsLat = prefs.getDouble(_keyGpsLat);
      final gpsLng = prefs.getDouble(_keyGpsLng);
      final gpsAlt = prefs.getDouble(_keyGpsAlt);
      final gpsLocName = prefs.getString(_keyGpsLocName);
      final useIhtiyati = prefs.getBool(_keyUseIhtiyati);
      final isDarkMode = prefs.getBool(_keyIsDarkMode);
      final enableNotifications =
          prefs.getBool(_keyEnableNotifications) ?? false;
      final keepScreenOn = prefs.getBool(_keyKeepScreenOn) ?? false;
      final hijriOffset = prefs.getInt(_keyHijriOffset) ?? 0;
      final isbatDateStr = prefs.getString(_keyIsbatDate);

      state = AppSettings(
        calcMethod: calcMethodIndex != null
            ? CalcMethod.values[calcMethodIndex]
            : CalcMethod.kemenag,
        locationMode: locationModeIndex != null
            ? LocationMode.values[locationModeIndex]
            : LocationMode.gps,
        selectedCity: selectedCity ?? 'Jakarta',
        customLatitude: customLat ?? -6.2088,
        customLongitude: customLng ?? 106.8456,
        gpsLatitude: gpsLat,
        gpsLongitude: gpsLng,
        gpsAltitude: gpsAlt,
        gpsLocationName: gpsLocName,
        useIhtiyati: useIhtiyati ?? true,
        isDarkMode: isDarkMode ?? true,
        enableNotifications: enableNotifications,
        keepScreenOn: keepScreenOn,
        hijriOffset: hijriOffset,
        isbatDateStr: isbatDateStr,
        isGpsLoading:
            (locationModeIndex == null ||
                LocationMode.values[locationModeIndex] == LocationMode.gps) &&
            gpsLat == null,
      );

      // Restore screen wake lock if it was enabled
      if (keepScreenOn && kIsWeb) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            js.context.callMethod('requestScreenWakeLock');
          } catch (_) {}
        });
      }

      // Sync FCM topics on load
      if (kIsWeb) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _syncFcmTopics();
        });
      }

      // If location mode is GPS, automatically update GPS location in the background on startup
      if (state.locationMode == LocationMode.gps) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _autoUpdateGpsLocation();
        });
      }
    } catch (e) {
      // Keep initial defaults on error
    }
  }

  Future<void> setCalcMethod(CalcMethod method) async {
    state = state.copyWith(calcMethod: method);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCalcMethod, method.index);
    await _syncFcmTopics();
  }

  Future<void> setLocationMode(LocationMode mode) async {
    state = state.copyWith(
      locationMode: mode,
      isGpsLoading: mode == LocationMode.gps && state.gpsLatitude == null,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLocationMode, mode.index);
    await _syncFcmTopics();

    if (mode == LocationMode.gps) {
      _autoUpdateGpsLocation();
    } else {
      _gpsAutoUpdateTimer?.cancel();
    }
  }

  Future<void> setSelectedCity(String city) async {
    state = state.copyWith(selectedCity: city);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedCity, city);
    await _syncFcmTopics();
  }

  Future<void> setCustomCoordinates(double lat, double lng) async {
    state = state.copyWith(customLatitude: lat, customLongitude: lng);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyCustomLat, lat);
    await prefs.setDouble(_keyCustomLng, lng);
    await _syncFcmTopics();
  }

  Future<void> setGpsData({
    required double lat,
    required double lng,
    required double alt,
    required String locName,
  }) async {
    state = state.copyWith(
      gpsLatitude: lat,
      gpsLongitude: lng,
      gpsAltitude: alt,
      gpsLocationName: locName,
      isGpsLoading: false,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyGpsLat, lat);
    await prefs.setDouble(_keyGpsLng, lng);
    await prefs.setDouble(_keyGpsAlt, alt);
    await prefs.setString(_keyGpsLocName, locName);
    await _syncFcmTopics();
  }

  Future<void> fetchGpsLocation() async {
    if (state.locationMode == LocationMode.gps && state.gpsLatitude == null) {
      state = state.copyWith(isGpsLoading: true);
    }
    double latitude;
    double longitude;
    double altitude = 0.0;

    if (kIsWeb) {
      try {
        // Natively request and get position on web to bypass mobile-only permission checks that throw on desktop
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).timeout(const Duration(seconds: 10));

        latitude = position.latitude;
        longitude = position.longitude;
        altitude = position.altitude;
      } catch (e) {
        state = state.copyWith(isGpsLoading: false);
        final errStr = e.toString();
        if (errStr.contains('denied') || errStr.contains('Permission')) {
          throw 'Izin lokasi ditolak. Aktifkan akses lokasi di pengaturan browser Anda.';
        } else {
          throw 'Gagal mendapatkan lokasi GPS: $errStr';
        }
      }
    } else {
      // Mobile-native checks and updates
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          state = state.copyWith(isGpsLoading: false);
          throw 'Layanan GPS dinonaktifkan di perangkat Anda.';
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            state = state.copyWith(isGpsLoading: false);
            throw 'Izin akses lokasi ditolak oleh pengguna.';
          }
        }

        if (permission == LocationPermission.deniedForever) {
          state = state.copyWith(isGpsLoading: false);
          throw 'Izin lokasi diblokir permanen. Aktifkan lewat setelan sistem.';
        }

        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );

        latitude = position.latitude;
        longitude = position.longitude;
        altitude = position.altitude;
      } catch (e) {
        state = state.copyWith(isGpsLoading: false);
        rethrow;
      }
    }

    // Call OpenStreetMap Nominatim reverse geocoding API to resolve the address name
    String addressName = 'Lokasi GPS';
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$latitude&lon=$longitude&format=jsonv2&zoom=10',
      );
      final response = await http
          .get(
            url,
            headers: {
              'User-Agent':
                  'Al-Waqt-Islamic-Prayer-App/1.0 (Contact: rasyidkurniawan@gmail.com)',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['address'] != null) {
          final address = data['address'];
          final city =
              address['city'] ??
              address['town'] ??
              address['municipality'] ??
              address['suburb'] ??
              address['county'];
          final stateName = address['state'] ?? address['region'];
          if (city != null && stateName != null) {
            addressName = '$city, $stateName';
          } else if (city != null) {
            addressName = city.toString();
          } else if (stateName != null) {
            addressName = stateName.toString();
          } else if (data['display_name'] != null) {
            addressName = data['display_name']
                .toString()
                .split(',')
                .take(2)
                .join(',');
          }
        }
      }
    } catch (_) {
      // Fallback to default name on connection or timeout error
    }

    await setGpsData(
      lat: latitude,
      lng: longitude,
      alt: altitude,
      locName: addressName,
    );
  }

  Future<void> setUseIhtiyati(bool value) async {
    state = state.copyWith(useIhtiyati: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseIhtiyati, value);
    await _syncFcmTopics();
  }

  Future<void> setDarkMode(bool value) async {
    state = state.copyWith(isDarkMode: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsDarkMode, value);
  }

  Future<void> setEnableNotifications(bool value) async {
    if (value) {
      bool granted = false;
      if (kIsWeb) {
        try {
          final permissionStatus = js.context['Notification']?['permission'];
          if (permissionStatus == 'denied') {
            throw 'Notification permission blocked';
          }
          final permission = await FirebaseMessaging.instance
              .requestPermission();
          granted =
              permission.authorizationStatus == AuthorizationStatus.authorized;
        } catch (_) {
          granted = false;
        }
      } else {
        final status = await Permission.notification.request();
        granted = status == PermissionStatus.granted;
      }
      if (!granted) {
        state = state.copyWith(enableNotifications: false);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyEnableNotifications, false);
        await _syncFcmTopics();
        return;
      }
    }
    state = state.copyWith(enableNotifications: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnableNotifications, value);
    await _syncFcmTopics();
  }

  Future<void> setKeepScreenOn(bool value) async {
    if (kIsWeb) {
      try {
        if (value) {
          await js.context.callMethod('requestScreenWakeLock');
        } else {
          await js.context.callMethod('releaseScreenWakeLock');
        }
      } catch (e) {
        // Fallback on error
      }
    }
    state = state.copyWith(keepScreenOn: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyKeepScreenOn, value);
  }

  Future<void> setHijriOffset(int value) async {
    state = state.copyWith(hijriOffset: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHijriOffset, value);
  }

  Future<void> setIsbatDate(String? value) async {
    state = AppSettings(
      calcMethod: state.calcMethod,
      locationMode: state.locationMode,
      selectedCity: state.selectedCity,
      customLatitude: state.customLatitude,
      customLongitude: state.customLongitude,
      gpsLatitude: state.gpsLatitude,
      gpsLongitude: state.gpsLongitude,
      gpsAltitude: state.gpsAltitude,
      gpsLocationName: state.gpsLocationName,
      useIhtiyati: state.useIhtiyati,
      isDarkMode: state.isDarkMode,
      enableNotifications: state.enableNotifications,
      keepScreenOn: state.keepScreenOn,
      hijriOffset: state.hijriOffset,
      isbatDateStr: value,
    );
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_keyIsbatDate);
    } else {
      await prefs.setString(_keyIsbatDate, value);
    }
  }

  void openUrl(String url) {
    if (kIsWeb) {
      try {
        js.context.callMethod('open', [url, '_blank']);
      } catch (_) {}
    }
  }

  Future<void> setOsmSelectedCity({
    required String cityName,
    required double latitude,
    required double longitude,
  }) async {
    state = state.copyWith(
      selectedCity: cityName,
      customLatitude: latitude,
      customLongitude: longitude,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedCity, cityName);
    await prefs.setDouble(_keyCustomLat, latitude);
    await prefs.setDouble(_keyCustomLng, longitude);
    await _syncFcmTopics();
  }

  Future<List<Map<String, dynamic>>> searchOsmCities(String query) async {
    if (query.isEmpty || query.length < 3) return [];
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=5&countrycodes=id',
      );
      final response = await http
          .get(
            url,
            headers: {
              'User-Agent':
                  'Al-Waqt-Islamic-Prayer-App/1.0 (Contact: rasyidkurniawan@gmail.com)',
            },
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) {
          final lat = double.tryParse(item['lat'].toString()) ?? 0.0;
          final lon = double.tryParse(item['lon'].toString()) ?? 0.0;

          String displayName = item['display_name'].toString();
          final address = item['address'];
          if (address != null) {
            final city =
                address['city'] ??
                address['town'] ??
                address['municipality'] ??
                address['suburb'] ??
                address['county'];
            final stateName = address['state'] ?? address['region'];
            if (city != null && stateName != null) {
              displayName = '$city, $stateName';
            } else if (city != null) {
              displayName = city.toString();
            } else if (stateName != null) {
              displayName = stateName.toString();
            }
          }

          return {
            'name': displayName,
            'latitude': lat,
            'longitude': lon,
            'display_name': item['display_name'],
          };
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  String getFcmTopic() {
    double latitude;
    double longitude;

    if (state.locationMode == LocationMode.preset) {
      final hasPreset = presetCities.any((c) => c.name == state.selectedCity);
      if (hasPreset) {
        final city = presetCities.firstWhere(
          (c) => c.name == state.selectedCity,
        );
        latitude = city.latitude;
        longitude = city.longitude;
      } else {
        latitude = state.customLatitude;
        longitude = state.customLongitude;
      }
    } else if (state.locationMode == LocationMode.gps) {
      latitude = state.gpsLatitude ?? state.customLatitude;
      longitude = state.gpsLongitude ?? state.customLongitude;
    } else {
      latitude = state.customLatitude;
      longitude = state.customLongitude;
    }

    // Round to 1 decimal place
    final latRounded = (latitude * 10).round() / 10;
    final lonRounded = (longitude * 10).round() / 10;

    // Convert decimal to string with underscore instead of dot
    final latStr = latRounded.abs().toStringAsFixed(1).replaceAll('.', '_');
    final lonStr = lonRounded.abs().toStringAsFixed(1).replaceAll('.', '_');

    final latSign = latRounded >= 0 ? 'pos' : 'neg';
    final lonSign = lonRounded >= 0 ? 'pos' : 'neg';

    final method = state.calcMethod == CalcMethod.kemenag
        ? 'kemenag'
        : 'muhammadiyah';
    final ihtiyati = state.useIhtiyati ? 'yes' : 'no';

    return 'adzan_lat_$latSign${latStr}_lon_$lonSign${lonStr}_${method}_$ihtiyati';
  }

  bool get _isOnline {
    if (!kIsWeb) return true;
    try {
      return js.context['navigator']?['onLine'] as bool? ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<String?> _getFcmToken() async {
    if (!kIsWeb) {
      return FirebaseMessaging.instance.getToken();
    }

    // Check if the JS side invalidated the token (e.g., SW controller changed,
    // push subscription rotated). If so, clear the cached token and force a
    // fresh request to match the new push subscription encryption keys.
    try {
      final invalidated = js.context['_fcmTokenInvalidated'];
      if (invalidated == true) {
        debugPrint('[FCM] Token invalidated by SW change, clearing cached token');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('fcm_token');
        js.context['_fcmTokenInvalidated'] = false;
        // Fall through to request fresh token below
      }
    } catch (e) {
      debugPrint('[FCM] Error checking token invalidation flag: $e');
    }

    // Check cached token first to avoid unnecessary re-registrations
    // on Android Chrome PWA where token retrieval can be slow.
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedToken = prefs.getString('fcm_token');
      if (cachedToken != null && cachedToken.isNotEmpty) {
        debugPrint(
          '[FCM] Using cached token from SharedPreferences (${cachedToken.substring(0, cachedToken.length > 20 ? 20 : cachedToken.length)}...)',
        );
        return cachedToken;
      }
    } catch (e) {
      debugPrint('[FCM] Error reading cached token: $e');
    }

    debugPrint('[FCM] No cached token, requesting new one via JS helper...');
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

      String? token;
      if (js.context['fcmTokenReady'] == true) {
        final error = js.context['fcmTokenError'];
        if (error != null) {
          debugPrint('[FCM] Error getting token via JS helper: $error');
          debugPrint(
            '[FCM] Falling back to Flutter FirebaseMessaging.getToken()',
          );
          token = await FirebaseMessaging.instance.getToken(
            vapidKey: AppEnv.firebaseWebVapidKey,
          );
        } else {
          token = js.context['lastFcmToken'] as String?;
          debugPrint(
            '[FCM] Token obtained via JS helper: ${token?.substring(0, token.length > 20 ? 20 : token.length)}...',
          );
        }
      } else {
        debugPrint(
          '[FCM] Timeout getting token via JS helper after ${maxWaitMs}ms',
        );
        debugPrint(
          '[FCM] Falling back to Flutter FirebaseMessaging.getToken()',
        );
        token = await FirebaseMessaging.instance.getToken(
          vapidKey: AppEnv.firebaseWebVapidKey,
        );
      }

      // Cache the token in SharedPreferences for faster subsequent access
      if (token != null && token.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('fcm_token', token);
          debugPrint('[FCM] Token cached in SharedPreferences');
        } catch (e) {
          debugPrint('[FCM] Error caching token: $e');
        }
      } else {
        debugPrint('[FCM] Token is null or empty after all attempts');
      }

      return token;
    } catch (e) {
      debugPrint('[FCM] Error calling JS helper: $e');
      try {
        debugPrint(
          '[FCM] Final fallback: Flutter FirebaseMessaging.getToken()',
        );
        final token = await FirebaseMessaging.instance.getToken(
          vapidKey: AppEnv.firebaseWebVapidKey,
        );
        if (token != null && token.isNotEmpty) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('fcm_token', token);
          } catch (_) {}
        }
        return token;
      } catch (e2) {
        debugPrint('[FCM] Final fallback also failed: $e2');
        // Last resort: return cached token even if potentially expired
        try {
          final prefs = await SharedPreferences.getInstance();
          final cached = prefs.getString('fcm_token');
          debugPrint(
            '[FCM] Returning cached token as last resort: ${cached != null}',
          );
          return cached;
        } catch (_) {
          return null;
        }
      }
    }
  }

  /// Force-refresh the FCM token by clearing the Firebase IndexedDB
  /// and re-initializing. Call this when the token is invalid or expired.
  Future<String?> refreshFcmToken() async {
    if (!kIsWeb) {
      return FirebaseMessaging.instance.getToken();
    }

    debugPrint('[FCM] Force-refreshing FCM token...');

    // Clear cached token first
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fcm_token');
      debugPrint('[FCM] Cleared cached token from SharedPreferences');
    } catch (e) {
      debugPrint('[FCM] Error clearing cached token: $e');
    }

    // Call JS force-refresh function
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

      String? token;
      if (js.context['fcmTokenReady'] == true) {
        final error = js.context['fcmTokenError'];
        if (error != null) {
          debugPrint('[FCM] Force-refresh error: $error');
          token = await FirebaseMessaging.instance.getToken(
            vapidKey: AppEnv.firebaseWebVapidKey,
          );
        } else {
          token = js.context['lastFcmToken'] as String?;
          debugPrint(
            '[FCM] Force-refresh succeeded: ${token?.substring(0, token.length > 20 ? 20 : token.length)}...',
          );
        }
      } else {
        debugPrint('[FCM] Force-refresh timeout');
        token = await FirebaseMessaging.instance.getToken(
          vapidKey: AppEnv.firebaseWebVapidKey,
        );
      }

      if (token != null && token.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('fcm_token', token);
        } catch (_) {}
      }

      return token;
    } catch (e) {
      debugPrint('[FCM] Force-refresh JS call failed: $e');
      return await FirebaseMessaging.instance.getToken(
        vapidKey: AppEnv.firebaseWebVapidKey,
      );
    }
  }

  Future<void> _syncFcmTopics() async {
    if (!kIsWeb) return;

    // If completely offline, skip all FCM network topic sync operations
    // to prevent Firebase Token requests from hanging indefinitely.
    if (!_isOnline) {
      debugPrint('[FCM] _syncFcmTopics: offline, skipping');
      return;
    }

    debugPrint('[FCM] _syncFcmTopics: starting sync...');
    debugPrint('[FCM]   enableNotifications=${state.enableNotifications}');

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTopic = prefs.getString('last_subscribed_fcm_topic');
      debugPrint('[FCM]   lastTopic=$lastTopic');

      // If notifications are disabled in settings, clean up topic via Cloud Function
      if (!state.enableNotifications) {
        if (lastTopic != null && lastTopic.isNotEmpty) {
          debugPrint(
            '[FCM] Notifications disabled, cleaning up topic: $lastTopic',
          );
          try {
            final unsubscribeUrl = Uri.parse(
              'https://unsubscribefromtopic-ebadp63kua-uc.a.run.app',
            );
            
            // Try to get token if granted, otherwise call with null token to clean up Firestore
            String? token;
            final permission = js.context['Notification']?['permission'];
            if (permission == 'granted') {
              token = await _getFcmToken();
            }
            
            final unsubResponse = await http
                .post(
                  unsubscribeUrl,
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({'token': token, 'topic': lastTopic}),
                )
                .timeout(const Duration(seconds: 5));
            debugPrint(
              '[FCM] Clean up via CF response: ${unsubResponse.statusCode} ${unsubResponse.body}',
            );
          } catch (e) {
            debugPrint('[FCM] Error during cleanup: $e');
          }
          await prefs.remove('last_subscribed_fcm_topic');
          debugPrint('[FCM] Cleared last_subscribed_fcm_topic from prefs');
        } else {
          debugPrint(
            '[FCM] Notifications disabled, no previous topic to clean up',
          );
        }
        return;
      }

      // If notifications are enabled, check browser permission status.
      // - 'denied': User permanently blocked notifications — disable the setting.
      // - 'default': User hasn't responded yet — this is normal on first visit
      //   or after cache clear. We should NOT disable the setting; instead,
      //   the permission request will happen when user toggles the switch.
      // - 'granted': All good, proceed with topic sync.
      final permission = js.context['Notification']?['permission'];
      debugPrint('[FCM]   Notification.permission=$permission');
      if (permission == 'denied') {
        debugPrint(
          '[FCM] Notification permission is denied by user. Disabling notifications.',
        );
        state = state.copyWith(enableNotifications: false);
        await prefs.setBool(_keyEnableNotifications, false);
        return;
      }
      // If 'default' (not yet requested), we still try to get token and subscribe.
      // The permission request was already handled in setEnableNotifications().

      debugPrint('[FCM] Getting FCM token...');
      final token = await _getFcmToken();
      final hasToken = token != null && token.isNotEmpty;
      debugPrint(
        '[FCM]   hasToken=$hasToken token=${token?.substring(0, token.length > 20 ? 20 : token.length)}...',
      );

      // If we don't have an active token even though permission is granted, skip subscribing.
      if (!hasToken) {
        debugPrint('[FCM] No FCM token available, skipping subscription');
        return;
      }

      // Compute new topic
      final newTopic = getFcmTopic();
      debugPrint('[FCM]   newTopic=$newTopic');

      if (lastTopic == newTopic) {
        debugPrint(
          '[FCM] Already subscribed to correct topic, refreshing Firestore entry',
        );
        // Already subscribed to correct topic, make sure registered in Firestore via Cloud Function
        try {
          final subscribeUrl = Uri.parse(
            'https://subscribetotopic-ebadp63kua-uc.a.run.app',
          );
          final subResponse = await http
              .post(
                subscribeUrl,
                headers: {'Content-Type': 'application/json'},
                body: json.encode({'token': token, 'topic': newTopic}),
              )
              .timeout(const Duration(seconds: 5));
          debugPrint(
            '[FCM] Firestore refresh via CF response: ${subResponse.statusCode}',
          );
        } catch (e) {
          debugPrint('[FCM] Error refreshing Firestore entry: $e');
        }
        return;
      }

      // Different topic: clean up old one first
      if (lastTopic != null && lastTopic.isNotEmpty) {
        debugPrint('[FCM] Unsubscribing from old topic: $lastTopic');
        try {
          final unsubscribeUrl = Uri.parse(
            'https://unsubscribefromtopic-ebadp63kua-uc.a.run.app',
          );
          final unsubResponse = await http
              .post(
                unsubscribeUrl,
                headers: {'Content-Type': 'application/json'},
                body: json.encode({'token': token, 'topic': lastTopic}),
              )
              .timeout(const Duration(seconds: 5));
          debugPrint(
            '[FCM] Unsubscribe response: ${unsubResponse.statusCode} ${unsubResponse.body}',
          );
        } catch (e) {
          debugPrint('[FCM] Error unsubscribing from old topic: $e');
        }
      }

      // Subscribe to new one
      debugPrint('[FCM] Subscribing to new topic: $newTopic');
      try {
        final subscribeUrl = Uri.parse(
          'https://subscribetotopic-ebadp63kua-uc.a.run.app',
        );
        final subResponse = await http
            .post(
              subscribeUrl,
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'token': token, 'topic': newTopic}),
            )
            .timeout(const Duration(seconds: 5));
        debugPrint(
          '[FCM] Subscribe response: ${subResponse.statusCode} ${subResponse.body}',
        );

        if (subResponse.statusCode == 200) {
          await prefs.setString('last_subscribed_fcm_topic', newTopic);
          debugPrint(
            '[FCM] Successfully subscribed and saved topic: $newTopic',
          );
        } else {
          debugPrint(
            '[FCM] Subscribe failed with status: ${subResponse.statusCode}',
          );
        }
      } catch (e) {
        debugPrint('[FCM] Error subscribing to new topic: $e');
      }
    } catch (e) {
      debugPrint('[FCM] Error in _syncFcmTopics: $e');
    }
  }

  Future<void> _autoUpdateGpsLocation() async {
    _gpsAutoUpdateTimer?.cancel();

    // Silently fetch GPS location immediately on call
    try {
      await fetchGpsLocation();
    } catch (_) {}

    // Set up a periodic background sync every 15 minutes to keep coordinates and prayer times fresh
    _gpsAutoUpdateTimer = Timer.periodic(const Duration(minutes: 15), (
      timer,
    ) async {
      if (state.locationMode == LocationMode.gps) {
        try {
          await fetchGpsLocation();
        } catch (_) {}
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _gpsAutoUpdateTimer?.cancel();
    super.dispose();
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  return SettingsNotifier();
});
