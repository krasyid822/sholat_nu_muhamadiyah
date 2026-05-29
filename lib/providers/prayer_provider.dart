// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:js' as js;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/legacy.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import '../models/app_settings.dart';
import '../data/cities.dart';
import 'settings_provider.dart';

class PrayerState {
  final PrayerTimes todayPrayers;
  final PrayerTimes tomorrowPrayers;
  final DateTime imsakTime;
  final Prayer currentPrayer;
  final Prayer nextPrayer;
  final DateTime nextPrayerTime;
  final Duration timeRemaining;
  final String formattedRemaining;
  final String nextCountdownLabel;

  const PrayerState({
    required this.todayPrayers,
    required this.tomorrowPrayers,
    required this.imsakTime,
    required this.currentPrayer,
    required this.nextPrayer,
    required this.nextPrayerTime,
    required this.timeRemaining,
    required this.formattedRemaining,
    required this.nextCountdownLabel,
  });
}

class PrayerNotifier extends StateNotifier<PrayerState?> {
  final AppSettings settings;
  Timer? _timer;
  String? _lastNotifiedTimeKey;

  PrayerNotifier(this.settings) : super(null) {
    _startTimer();
  }

  void _startTimer() {
    _updatePrayerState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updatePrayerState();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _prayerLabel(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr:
        return 'Subuh';
      case Prayer.sunrise:
        return 'Syuruq';
      case Prayer.dhuhr:
        return 'Dzuhur';
      case Prayer.asr:
        return 'Ashar';
      case Prayer.maghrib:
        return 'Maghrib';
      case Prayer.isha:
        return 'Isya';
      default:
        return 'Waktu Sholat';
    }
  }

  void _triggerNotification(String name, String time) {
    if (!kIsWeb) return;
    try {
      final title = 'Waktu $name Telah Tiba ($time)';
      final body = name == 'Imsak' 
          ? 'Waktu Imsak ($time) telah masuk. Silakan bersiap-siap untuk berpuasa.'
          : 'Waktunya menunaikan ibadah shalat $name ($time) untuk wilayah Anda.';
      
      js.context.callMethod('showLocalNotification', [title, body]);

      // Play custom adzan sound for prayer times, or a beep for Imsak/Syuruq
      final soundType = (name == 'Imsak' || name == 'Syuruq') ? 'beep' : 'adzan';
      js.context.callMethod('playNotificationSound', [soundType]);
    } catch (_) {}
  }

  void _updatePrayerState() {
    // If we are actively waiting for GPS location to load (not yet obtained or timed out/failed),
    // do not perform calculations, set state = null, and return to keep showing the loading indicator.
    if (settings.locationMode == LocationMode.gps && settings.isGpsLoading) {
      state = null;
      return;
    }

    // 1. Get current latitude and longitude
    double latitude;
    double longitude;

    if (settings.locationMode == LocationMode.preset) {
      final hasPreset = presetCities.any((c) => c.name == settings.selectedCity);
      if (hasPreset) {
        final city = presetCities.firstWhere((c) => c.name == settings.selectedCity);
        latitude = city.latitude;
        longitude = city.longitude;
      } else {
        latitude = settings.customLatitude;
        longitude = settings.customLongitude;
      }
    } else if (settings.locationMode == LocationMode.gps) {
      latitude = settings.gpsLatitude ?? settings.customLatitude;
      longitude = settings.gpsLongitude ?? settings.customLongitude;
    } else {
      latitude = settings.customLatitude;
      longitude = settings.customLongitude;
    }

    final coordinates = Coordinates(latitude, longitude);
    final now = DateTime.now();

    // 2. Setup calculation parameters based on Settings
    CalculationParameters params;
    if (settings.calcMethod == CalcMethod.kemenag) {
      // Kemenag (MABIMS standard daily parameters: Fajr 20, Isha 18)
      params = CalculationMethod.singapore.getParameters();
    } else {
      // Muhammadiyah (Pasca Munas 2020: Fajr 18, Isha 18)
      params = CalculationMethod.muslim_world_league.getParameters();
      params.fajrAngle = 18.0;
      params.ishaAngle = 18.0;
    }
    
    params.madhab = Madhab.shafi;

    // Apply Ihtiyati (+2 minutes)
    if (settings.useIhtiyati) {
      params.adjustments.fajr = 2;
      params.adjustments.dhuhr = 2;
      params.adjustments.asr = 2;
      params.adjustments.maghrib = 2;
      params.adjustments.isha = 2;
    } else {
      params.adjustments.fajr = 0;
      params.adjustments.dhuhr = 0;
      params.adjustments.asr = 0;
      params.adjustments.maghrib = 0;
      params.adjustments.isha = 0;
    }

    // 3. Compute today's and tomorrow's prayer times
    final todayDate = DateComponents.from(now);
    final tomorrowDate = DateComponents.from(now.add(const Duration(days: 1)));

    final todayPrayers = PrayerTimes(coordinates, todayDate, params);
    final tomorrowPrayers = PrayerTimes(coordinates, tomorrowDate, params);

    // Imsak = 10 menit sebelum Subuh (standar Kemenag RI)
    final imsakTime = todayPrayers.fajr.subtract(const Duration(minutes: 10));
    final tomorrowImsakTime = tomorrowPrayers.fajr.subtract(const Duration(minutes: 10));

    // 4. Determine current and next prayer, with Imsak-aware countdown
    Prayer currentPrayer = todayPrayers.currentPrayer();
    Prayer nextPrayer = todayPrayers.nextPrayer();
    DateTime countdownTarget;
    String countdownLabel;

    if (nextPrayer == Prayer.none) {
      // After Isha — check if tomorrow's Imsak comes first
      countdownTarget = tomorrowImsakTime;
      countdownLabel = 'Imsak';
    } else if (nextPrayer == Prayer.fajr && now.isBefore(imsakTime)) {
      // Before Imsak today — countdown to Imsak
      countdownTarget = imsakTime;
      countdownLabel = 'Imsak';
    } else {
      countdownTarget = todayPrayers.timeForPrayer(nextPrayer)!;
      countdownLabel = _prayerLabel(nextPrayer);
    }

    final timeRemaining = countdownTarget.difference(now);
    
    // Format duration as hh:mm:ss
    final hours = timeRemaining.inHours.toString().padLeft(2, '0');
    final minutes = (timeRemaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (timeRemaining.inSeconds % 60).toString().padLeft(2, '0');
    final formattedRemaining = '$hours:$minutes:$seconds';

    // Check for notification triggers if enabled
    if (settings.enableNotifications && kIsWeb) {
      final nowFormatted = DateFormat('yyyy-MM-dd').format(now);
      final currentHourMin = DateFormat('HH:mm').format(now);

      final Map<String, DateTime> timesToCheck = {
        'Imsak': imsakTime,
        'Subuh': todayPrayers.fajr,
        'Syuruq': todayPrayers.sunrise,
        'Dzuhur': todayPrayers.dhuhr,
        'Ashar': todayPrayers.asr,
        'Maghrib': todayPrayers.maghrib,
        'Isya': todayPrayers.isha,
      };

      for (final entry in timesToCheck.entries) {
        final prayerTimeFormatted = DateFormat('HH:mm').format(entry.value);
        if (currentHourMin == prayerTimeFormatted) {
          final notifyKey = '${nowFormatted}_${entry.key}';
          if (_lastNotifiedTimeKey != notifyKey) {
            _lastNotifiedTimeKey = notifyKey;
            _triggerNotification(entry.key, prayerTimeFormatted);
          }
        }
      }
    }

    state = PrayerState(
      todayPrayers: todayPrayers,
      tomorrowPrayers: tomorrowPrayers,
      imsakTime: imsakTime,
      currentPrayer: currentPrayer,
      nextPrayer: nextPrayer,
      nextPrayerTime: countdownTarget,
      timeRemaining: timeRemaining,
      formattedRemaining: formattedRemaining,
      nextCountdownLabel: countdownLabel,
    );
  }
}

// Keep the notifier updated whenever settings change
final prayerProvider = StateNotifierProvider<PrayerNotifier, PrayerState?>((ref) {
  final settings = ref.watch(settingsProvider);
  return PrayerNotifier(settings);
});
