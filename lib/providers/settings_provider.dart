// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:js' as js;
import '../models/app_settings.dart';

class SettingsNotifier extends StateNotifier<AppSettings> {
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
      final enableNotifications = prefs.getBool(_keyEnableNotifications) ?? false;
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
      );

      // Restore screen wake lock if it was enabled
      if (keepScreenOn && kIsWeb) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            js.context.callMethod('requestScreenWakeLock');
          } catch (_) {}
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
  }

  Future<void> setLocationMode(LocationMode mode) async {
    state = state.copyWith(locationMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLocationMode, mode.index);
  }

  Future<void> setSelectedCity(String city) async {
    state = state.copyWith(selectedCity: city);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedCity, city);
  }

  Future<void> setCustomCoordinates(double lat, double lng) async {
    state = state.copyWith(customLatitude: lat, customLongitude: lng);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyCustomLat, lat);
    await prefs.setDouble(_keyCustomLng, lng);
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
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyGpsLat, lat);
    await prefs.setDouble(_keyGpsLng, lng);
    await prefs.setDouble(_keyGpsAlt, alt);
    await prefs.setString(_keyGpsLocName, locName);
  }

  Future<void> fetchGpsLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Layanan GPS dinonaktifkan di perangkat Anda.';
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Izin akses lokasi ditolak oleh pengguna.';
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw 'Izin lokasi diblokir permanen. Aktifkan lewat setelan browser/sistem.';
    } 

    // Retrieve position with high-precision settings
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    // Call OpenStreetMap Nominatim reverse geocoding API to resolve the address name
    String addressName = 'Lokasi GPS';
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=jsonv2&zoom=10'
      );
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'Al-Waqt-Islamic-Prayer-App/1.0 (Contact: rasyidkurniawan@gmail.com)'
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['address'] != null) {
          final address = data['address'];
          final city = address['city'] ?? address['town'] ?? address['municipality'] ?? address['suburb'] ?? address['county'];
          final stateName = address['state'] ?? address['region'];
          if (city != null && stateName != null) {
            addressName = '$city, $stateName';
          } else if (city != null) {
            addressName = city.toString();
          } else if (stateName != null) {
            addressName = stateName.toString();
          } else if (data['display_name'] != null) {
            addressName = data['display_name'].toString().split(',').take(2).join(',');
          }
        }
      }
    } catch (_) {
      // Fallback to default name on connection or timeout error
    }
    
    await setGpsData(
      lat: position.latitude,
      lng: position.longitude,
      alt: position.altitude,
      locName: addressName,
    );
  }

  Future<void> setUseIhtiyati(bool value) async {
    state = state.copyWith(useIhtiyati: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseIhtiyati, value);
  }

  Future<void> setDarkMode(bool value) async {
    state = state.copyWith(isDarkMode: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsDarkMode, value);
  }

  Future<void> setEnableNotifications(bool value) async {
    if (value && kIsWeb) {
      try {
        final permission = await js.context.callMethod('requestNotificationPermission');
        if (permission != 'granted') {
          // If denied, keep setting as false
          state = state.copyWith(enableNotifications: false);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_keyEnableNotifications, false);
          return;
        }
      } catch (e) {
        // Fallback on error
      }
    }
    state = state.copyWith(enableNotifications: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnableNotifications, value);
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
  }

  Future<List<Map<String, dynamic>>> searchOsmCities(String query) async {
    if (query.isEmpty || query.length < 3) return [];
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=5&countrycodes=id'
      );
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'Al-Waqt-Islamic-Prayer-App/1.0 (Contact: rasyidkurniawan@gmail.com)'
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) {
          final lat = double.tryParse(item['lat'].toString()) ?? 0.0;
          final lon = double.tryParse(item['lon'].toString()) ?? 0.0;
          
          String displayName = item['display_name'].toString();
          final address = item['address'];
          if (address != null) {
            final city = address['city'] ?? address['town'] ?? address['municipality'] ?? address['suburb'] ?? address['county'];
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
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
