import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:adhan/adhan.dart';
import '../providers/prayer_provider.dart';
import '../providers/settings_provider.dart';
import '../models/app_settings.dart';
import '../utils/hijri_converter.dart';

import 'gps_loading_view.dart';

class DashboardTab extends ConsumerWidget {
  const DashboardTab({super.key});

  String _getPrayerName(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr:
        return 'Subuh';
      case Prayer.sunrise:
        return 'Syuruq (Terbit)';
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

  IconData _getPrayerIcon(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr:
        return Icons.wb_twilight_rounded;
      case Prayer.sunrise:
        return Icons.wb_sunny_outlined;
      case Prayer.dhuhr:
        return Icons.wb_sunny_rounded;
      case Prayer.asr:
        return Icons.filter_drama_rounded;
      case Prayer.maghrib:
        return Icons.nights_stay_rounded;
      case Prayer.isha:
        return Icons.brightness_3_rounded;
      default:
        return Icons.alarm;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayerState = ref.watch(prayerProvider);
    final settings = ref.watch(settingsProvider);

    if (prayerState == null) {
      if (settings.locationMode == LocationMode.gps && settings.isGpsLoading) {
        return const GpsLoadingView();
      }
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFD4AF37),
        ),
      );
    }

    final today = prayerState.todayPrayers;
    final now = DateTime.now();
    final timeFormatter = DateFormat('HH:mm');
    final dateFormatter = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
    
    // Formatted date
    String formattedDate = '';
    try {
      formattedDate = dateFormatter.format(now);
    } catch (_) {
      formattedDate = DateFormat('EEEE, d MMMM yyyy').format(now);
    }

    // Precise Hijri calculation using the Tabular Islamic Calendar with Fiqih settings & offset
    final hijriDate = HijriConverter.fromGregorian(now, settings.calcMethod, settings.hijriOffset, settings.isbatDateStr);
    final String hijriString = hijriDate.formatted;

    final List<Map<String, dynamic>> prayerItems = [
      {'prayer': 'imsak', 'name': 'Imsak', 'time': prayerState.imsakTime, 'icon': Icons.restaurant_outlined},
      {'prayer': Prayer.fajr, 'time': today.fajr},
      {'prayer': Prayer.sunrise, 'time': today.sunrise},
      {'prayer': Prayer.dhuhr, 'time': today.dhuhr},
      {'prayer': Prayer.asr, 'time': today.asr},
      {'prayer': Prayer.maghrib, 'time': today.maghrib},
      {'prayer': Prayer.isha, 'time': today.isha},
    ];

    final nextPrayerName = prayerState.nextCountdownLabel;
    final isMuhammadiyah = settings.calcMethod == CalcMethod.muhammadiyah;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date and Header Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          size: 16,
                          color: Color(0xFFD4AF37),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          hijriString,
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFE6C575),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Method Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isMuhammadiyah 
                        ? const Color(0xFF1E3A5F).withValues(alpha: 0.3)
                        : const Color(0xFF0F5A3E).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isMuhammadiyah 
                          ? const Color(0xFF5B92E5).withValues(alpha: 0.3)
                          : const Color(0xFF16A06B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    isMuhammadiyah ? 'Muhammadiyah' : 'Kemenag (NU)',
                    style: GoogleFonts.plusJakartaSans(
                      color: isMuhammadiyah ? const Color(0xFF90CAF9) : const Color(0xFF81C784),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 24),

            // Premium Glassmorphic Countdown Card
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0C3C2C).withValues(alpha: 0.85),
                    const Color(0xFF051C15).withValues(alpha: 0.95),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0C3C2C).withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'HITUNG MUNDUR KE ${nextPrayerName.toUpperCase()}',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFE6C575),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Large Countdown Text
                  Text(
                    prayerState.formattedRemaining,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        settings.locationMode == LocationMode.preset
                            ? settings.selectedCity
                            : settings.locationMode == LocationMode.gps
                                ? (settings.gpsLocationName ?? (settings.gpsLatitude != null ? 'Auto GPS' : 'Izin GPS Ditolak / Gagal'))
                                : 'Kustom Koordinat',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time_outlined,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Next: ${timeFormatter.format(prayerState.nextPrayerTime)} WIB',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Warning Banner for blocked GPS permission
            if (settings.locationMode == LocationMode.gps && settings.gpsLatitude == null && !settings.isGpsLoading) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C0F0F).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_off_outlined,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Izin Lokasi GPS Ditolak / Gagal',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.redAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Aplikasi menggunakan lokasi default (DKI Jakarta). Silakan aktifkan izin lokasi di browser atau pilih lokasi manual di tab Setelan.',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 28),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Jadwal Sholat Hari Ini',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  isMuhammadiyah ? 'Subuh -18°' : 'Subuh -20°',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Prayer List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: prayerItems.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = prayerItems[index];
                final prayerTime = item['time'] as DateTime;
                final isImsak = item['prayer'] is String && item['prayer'] == 'imsak';
                
                final String prayerName;
                final IconData icon;
                final bool isCurrent;
                final bool isNext;

                if (isImsak) {
                  prayerName = item['name'] as String;
                  icon = item['icon'] as IconData;
                  isCurrent = false;
                  isNext = false;
                } else {
                  final prayer = item['prayer'] as Prayer;
                  prayerName = _getPrayerName(prayer);
                  icon = _getPrayerIcon(prayer);
                  isCurrent = prayerState.currentPrayer == prayer;
                  isNext = prayerState.nextPrayer == prayer;
                }

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: isImsak
                        ? LinearGradient(
                            colors: [
                              const Color(0xFF4A2E0B).withValues(alpha: 0.35),
                              const Color(0xFF2A1A06).withValues(alpha: 0.45),
                            ],
                          )
                        : isCurrent
                            ? LinearGradient(
                                colors: [
                                  const Color(0xFF0F5A3E).withValues(alpha: 0.85),
                                  const Color(0xFF063323).withValues(alpha: 0.95),
                                ],
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.04),
                                  Colors.white.withValues(alpha: 0.02),
                                ],
                              ),
                    border: Border.all(
                      color: isImsak
                          ? const Color(0xFFD4AF37).withValues(alpha: 0.25)
                          : isCurrent
                              ? const Color(0xFFD4AF37).withValues(alpha: 0.4)
                              : isNext 
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.05),
                      width: isCurrent ? 1.5 : 1.0,
                    ),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: const Color(0xFF0F5A3E).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Active indicator glowing dot
                      if (isImsak)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6C575).withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                        )
                      else if (isCurrent)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD4AF37),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFD4AF37),
                                blurRadius: 6,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        )
                      else if (isNext)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(width: 8),
                      const SizedBox(width: 16),

                      // Icon
                      Icon(
                        icon,
                        color: isImsak
                            ? const Color(0xFFE6C575)
                            : isCurrent ? const Color(0xFFD4AF37) : Colors.white60,
                        size: 22,
                      ),
                      const SizedBox(width: 16),

                      // Name
                      Text(
                        prayerName,
                        style: GoogleFonts.plusJakartaSans(
                          color: isImsak
                              ? const Color(0xFFE6C575)
                              : isCurrent ? Colors.white : Colors.white70,
                          fontSize: isImsak ? 14 : 16,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                          fontStyle: isImsak ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                      if (isImsak) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '-10 min',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFE6C575).withValues(alpha: 0.7),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),

                      // Time
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            timeFormatter.format(prayerTime),
                            style: GoogleFonts.outfit(
                              color: isImsak
                                  ? const Color(0xFFE6C575)
                                  : isCurrent ? const Color(0xFFD4AF37) : Colors.white,
                              fontSize: isImsak ? 16 : 18,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                          // Distance preview
                          Text(
                            (() {
                              final diff = prayerTime.difference(now);
                              if (diff.isNegative) {
                                final d = diff.abs();
                                return '-${d.inHours}h ${d.inMinutes % 60}m';
                              } else {
                                return '+${diff.inHours}h ${diff.inMinutes % 60}m';
                              }
                            })(),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            
            // Ihtiyati Info Card
            if (settings.useIhtiyati)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: Color(0xFFE6C575),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pengaman waktu shalat (Ihtiyati +2 menit) aktif untuk akurasi fiqih.',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
