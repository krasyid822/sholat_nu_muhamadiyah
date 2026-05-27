import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
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
  static const String _keyUseIhtiyati = 'use_ihtiyati';
  static const String _keyIsDarkMode = 'is_dark_mode';

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
      final useIhtiyati = prefs.getBool(_keyUseIhtiyati);
      final isDarkMode = prefs.getBool(_keyIsDarkMode);

      state = AppSettings(
        calcMethod: calcMethodIndex != null 
            ? CalcMethod.values[calcMethodIndex] 
            : CalcMethod.kemenag,
        locationMode: locationModeIndex != null 
            ? LocationMode.values[locationModeIndex] 
            : LocationMode.preset,
        selectedCity: selectedCity ?? 'Jakarta',
        customLatitude: customLat ?? -6.2088,
        customLongitude: customLng ?? 106.8456,
        gpsLatitude: gpsLat,
        gpsLongitude: gpsLng,
        useIhtiyati: useIhtiyati ?? true,
        isDarkMode: isDarkMode ?? true,
      );
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

  Future<void> setGpsCoordinates(double lat, double lng) async {
    state = state.copyWith(gpsLatitude: lat, gpsLongitude: lng);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyGpsLat, lat);
    await prefs.setDouble(_keyGpsLng, lng);
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
    
    await setGpsCoordinates(position.latitude, position.longitude);
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
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
