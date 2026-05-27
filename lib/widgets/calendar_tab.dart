import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:adhan/adhan.dart';
import '../utils/hijri_converter.dart';
import '../providers/settings_provider.dart';
import '../models/app_settings.dart';
import '../data/cities.dart';

class CalendarTab extends ConsumerStatefulWidget {
  const CalendarTab({super.key});

  @override
  ConsumerState<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends ConsumerState<CalendarTab> {
  late DateTime _currentMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _selectedDate = now;
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _currentMonth = DateTime(now.year, now.month, 1);
      _selectedDate = now;
    });
  }

  /// Calculate prayer times for a given date using current settings
  Map<String, DateTime> _getPrayerTimesForDate(DateTime date, AppSettings settings) {
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

    CalculationParameters params;
    if (settings.calcMethod == CalcMethod.kemenag) {
      params = CalculationMethod.singapore.getParameters();
    } else {
      params = CalculationMethod.muslim_world_league.getParameters();
      params.fajrAngle = 18.0;
      params.ishaAngle = 18.0;
    }
    params.madhab = Madhab.shafi;

    if (settings.useIhtiyati) {
      params.adjustments.fajr = 2;
      params.adjustments.dhuhr = 2;
      params.adjustments.asr = 2;
      params.adjustments.maghrib = 2;
      params.adjustments.isha = 2;
    }

    final dateComponents = DateComponents.from(date);
    final prayerTimes = PrayerTimes(coordinates, dateComponents, params);

    final imsak = prayerTimes.fajr.subtract(const Duration(minutes: 10));

    return {
      'Imsak': imsak,
      'Subuh': prayerTimes.fajr,
      'Syuruq': prayerTimes.sunrise,
      'Dzuhur': prayerTimes.dhuhr,
      'Ashar': prayerTimes.asr,
      'Maghrib': prayerTimes.maghrib,
      'Isya': prayerTimes.isha,
    };
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Determine first and last day of the month
    final firstDayOfMonth = _currentMonth;
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;

    // Determine which weekday the month starts on (Monday = 0)
    int startWeekday = firstDayOfMonth.weekday - 1; // Monday = 0

    // Hijri date for the 1st of the displayed month with Fiqih settings & offset
    final hijriFirstDay = HijriConverter.fromGregorian(firstDayOfMonth, settings.calcMethod, settings.hijriOffset, settings.isbatDateStr);

    // Month/Year header text
    final monthYearText = DateFormat('MMMM yyyy', 'id_ID').format(_currentMonth);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ═══════════════════════════════════════════════════
            // MONTH NAVIGATION HEADER
            // ═══════════════════════════════════════════════════
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0C3C2C).withValues(alpha: 0.6),
                    const Color(0xFF051C15).withValues(alpha: 0.8),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Previous month arrow
                  IconButton(
                    onPressed: _previousMonth,
                    icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFFD4AF37)),
                    splashRadius: 20,
                  ),
                  // Month title + Hijri subtitle
                  Expanded(
                    child: GestureDetector(
                      onTap: _goToToday,
                      child: Column(
                        children: [
                          Text(
                            monthYearText,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${hijriFirstDay.monthName} ${hijriFirstDay.year} H',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFE6C575),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Next month arrow
                  IconButton(
                    onPressed: _nextMonth,
                    icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFFD4AF37)),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ═══════════════════════════════════════════════════
            // DAY-OF-WEEK HEADER ROW
            // ═══════════════════════════════════════════════════
            Row(
              children: ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'].map((day) {
                final isWeekend = day == 'Sab' || day == 'Min';
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: GoogleFonts.plusJakartaSans(
                        color: isWeekend
                            ? const Color(0xFFE6C575).withValues(alpha: 0.6)
                            : Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),

            // ═══════════════════════════════════════════════════
            // CALENDAR GRID
            // ═══════════════════════════════════════════════════
            _buildCalendarGrid(
              daysInMonth: daysInMonth,
              startWeekday: startWeekday,
              today: today,
              firstDayOfMonth: firstDayOfMonth,
            ),
            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════════
            // SELECTED DATE DETAIL CARD
            // ═══════════════════════════════════════════════════
            if (_selectedDate != null) _buildSelectedDateCard(settings, today),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid({
    required int daysInMonth,
    required int startWeekday,
    required DateTime today,
    required DateTime firstDayOfMonth,
  }) {
    final settings = ref.read(settingsProvider);
    // Calculate total cells needed (previous month filler + current month)
    final totalCells = startWeekday + daysInMonth;
    final rowCount = ((totalCells) / 7).ceil();

    return Column(
      children: List.generate(rowCount, (rowIndex) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: List.generate(7, (colIndex) {
              final cellIndex = rowIndex * 7 + colIndex;
              final dayNumber = cellIndex - startWeekday + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                // Empty cell for days outside this month
                return Expanded(child: SizedBox(height: 62));
              }

              final cellDate = DateTime(firstDayOfMonth.year, firstDayOfMonth.month, dayNumber);
              final isToday = cellDate.isAtSameMomentAs(today);
              final isSelected = _selectedDate != null &&
                  cellDate.year == _selectedDate!.year &&
                  cellDate.month == _selectedDate!.month &&
                  cellDate.day == _selectedDate!.day;
              final hijri = HijriConverter.fromGregorian(cellDate, settings.calcMethod, settings.hijriOffset, settings.isbatDateStr);
              final isSpecial = hijri.isSpecialDay;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = cellDate;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 62,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: isSelected
                          ? const Color(0xFFD4AF37).withValues(alpha: 0.2)
                          : isToday
                              ? const Color(0xFF0F5A3E).withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.02),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFD4AF37).withValues(alpha: 0.6)
                            : isToday
                                ? const Color(0xFF16A06B).withValues(alpha: 0.5)
                                : isSpecial
                                    ? const Color(0xFFE6C575).withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.04),
                        width: isSelected || isToday ? 1.5 : 0.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Gregorian day
                        Text(
                          '$dayNumber',
                          style: GoogleFonts.outfit(
                            color: isSelected
                                ? const Color(0xFFD4AF37)
                                : isToday
                                    ? Colors.white
                                    : Colors.white70,
                            fontSize: 15,
                            fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Hijri day
                        Text(
                          '${hijri.day}',
                          style: GoogleFonts.plusJakartaSans(
                            color: isSpecial
                                ? const Color(0xFFE6C575)
                                : const Color(0xFF81C784).withValues(alpha: 0.6),
                            fontSize: 9,
                            fontWeight: isSpecial ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                        // Special day dot indicator
                        if (isSpecial)
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.only(top: 1),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE6C575),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildSelectedDateCard(AppSettings settings, DateTime today) {
    final selectedDate = _selectedDate!;
    final hijri = HijriConverter.fromGregorian(selectedDate, settings.calcMethod, settings.hijriOffset, settings.isbatDateStr);
    final isToday = selectedDate.isAtSameMomentAs(today);

    String formattedDate;
    try {
      formattedDate = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(selectedDate);
    } catch (_) {
      formattedDate = DateFormat('EEEE, d MMMM yyyy').format(selectedDate);
    }

    final prayerTimes = _getPrayerTimesForDate(selectedDate, settings);
    final timeFormatter = DateFormat('HH:mm');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0C3C2C).withValues(alpha: 0.7),
            const Color(0xFF051C15).withValues(alpha: 0.9),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0C3C2C).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header
          Row(
            children: [
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    'HARI INI',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFD4AF37),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hijri.formatted,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFE6C575),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Islamic event badge
          if (hijri.isSpecialDay) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFD4AF37).withValues(alpha: 0.15),
                    const Color(0xFFD4AF37).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFE6C575).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFE6C575)),
                  const SizedBox(width: 8),
                  Text(
                    hijri.islamicEvent!,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFE6C575),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
          const SizedBox(height: 16),

          // Section title with location metadata
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'JADWAL SHOLAT',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              Expanded(
                child: Text(
                  (settings.locationMode == LocationMode.preset
                      ? settings.selectedCity
                      : settings.locationMode == LocationMode.gps
                          ? (settings.gpsLocationName ?? 'Auto GPS')
                          : 'Kustom Koordinat').toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFE6C575).withValues(alpha: 0.8),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Prayer times grid (2 columns)
          ...prayerTimes.entries.map((entry) {
            final isImsak = entry.key == 'Imsak';
            final isSunrise = entry.key == 'Syuruq';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    _getPrayerIcon(entry.key),
                    size: 16,
                    color: isImsak
                        ? const Color(0xFFE6C575).withValues(alpha: 0.7)
                        : isSunrise
                            ? Colors.orangeAccent.withValues(alpha: 0.7)
                            : Colors.white54,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: GoogleFonts.plusJakartaSans(
                        color: isImsak
                            ? const Color(0xFFE6C575).withValues(alpha: 0.8)
                            : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontStyle: isImsak ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ),
                  Text(
                    timeFormatter.format(entry.value),
                    style: GoogleFonts.outfit(
                      color: isImsak
                          ? const Color(0xFFE6C575).withValues(alpha: 0.8)
                          : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  IconData _getPrayerIcon(String name) {
    switch (name) {
      case 'Imsak':
        return Icons.restaurant_outlined;
      case 'Subuh':
        return Icons.wb_twilight_rounded;
      case 'Syuruq':
        return Icons.wb_sunny_outlined;
      case 'Dzuhur':
        return Icons.wb_sunny_rounded;
      case 'Ashar':
        return Icons.filter_drama_rounded;
      case 'Maghrib':
        return Icons.nights_stay_rounded;
      case 'Isya':
        return Icons.brightness_3_rounded;
      default:
        return Icons.alarm;
    }
  }
}
