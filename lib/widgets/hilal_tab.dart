import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../providers/settings_provider.dart';
import '../models/app_settings.dart';
import '../utils/hijri_converter.dart';
import '../data/cities.dart';
import 'gps_loading_view.dart';

class HilalTab extends ConsumerStatefulWidget {
  const HilalTab({super.key});

  @override
  ConsumerState<HilalTab> createState() => _HilalTabState();
}

class _HilalTabState extends ConsumerState<HilalTab> {
  bool _firstRun = true;
  DateTime? _selectedDate;
  double _simAltitude = 3.5;
  double _simElongation = 6.8;

  // Calculate moon parameters for selected date and update the state
  void _updateParametersForDate(DateTime date, AppSettings settings) {
    double latitude;

    if (settings.locationMode == LocationMode.preset) {
      final hasPreset = presetCities.any((c) => c.name == settings.selectedCity);
      if (hasPreset) {
        final city = presetCities.firstWhere((c) => c.name == settings.selectedCity);
        latitude = city.latitude;
      } else {
        latitude = settings.customLatitude;
      }
    } else if (settings.locationMode == LocationMode.gps) {
      latitude = settings.gpsLatitude ?? settings.customLatitude;
    } else {
      latitude = settings.customLatitude;
    }

    final double age = HijriConverter.getMoonAge(date);
    
    // Elongation calculation
    double elongationVal = (age / 29.530588853) * 360.0;
    if (elongationVal > 180) elongationVal = 360.0 - elongationVal;
    
    // Altitude at sunset based on moon age and latitude
    double latitudeRad = latitude * math.pi / 180.0;
    double latFactor = math.cos(latitudeRad).abs();
    double altitudeVal;
    
    if (age <= 14.765) {
      if (age < 3.0) {
        altitudeVal = age * 4.0 * latFactor;
      } else {
        altitudeVal = (12.0 + (age - 3.0) * 0.5) * latFactor;
      }
    } else {
      double ageDiff = 29.530588853 - age;
      if (ageDiff < 3.0) {
        altitudeVal = -ageDiff * 4.0 * latFactor;
      } else {
        altitudeVal = -(12.0 + (ageDiff - 3.0) * 0.5) * latFactor;
      }
    }

    // Adapt to slider boundaries
    if (altitudeVal > 15.0) altitudeVal = 15.0;
    if (altitudeVal < -10.0) altitudeVal = -10.0;
    if (elongationVal > 20.0) elongationVal = 20.0;
    if (elongationVal < 0.0) elongationVal = 0.0;

    _simAltitude = altitudeVal;
    _simElongation = elongationVal;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    
    if (settings.locationMode == LocationMode.gps && settings.isGpsLoading) {
      return const GpsLoadingView();
    }

    final now = DateTime.now();

    if (_firstRun) {
      _firstRun = false;
      _selectedDate = now;
      _updateParametersForDate(_selectedDate!, settings);
    }

    // Determine current location parameters for display
    String locationName;
    if (settings.locationMode == LocationMode.preset) {
      locationName = 'Kab/Kota: ${settings.selectedCity}';
    } else if (settings.locationMode == LocationMode.gps) {
      locationName = settings.gpsLocationName ?? 'Lokasi GPS';
    } else {
      locationName = 'Kustom Koordinat';
    }

    final double age = HijriConverter.getMoonAge(_selectedDate ?? now);
    final meetsMabims = _simAltitude >= 3.0 && _simElongation >= 6.4;
    final meetsKhgt = _simAltitude >= 5.0 && _simElongation >= 8.0;

    // Calculations for the visual crescent representation
    final double moonBottomOffset = 40 + (_simAltitude * 12);
    final double moonMaskOffset = 35 - (_simElongation * 2.2);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title & Concept
            Text(
              'Pelacak & Simulator Hilal',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pilih tanggal untuk memuat posisi hilal asli, lalu gunakan slider jika ingin melakukan simulasi kustom.',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white60,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 20),

            // 📅 Date Selector Card (Premium Glassmorphism)
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
                  // Selected Date Label
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TANGGAL PEMANTAUAN',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white38,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedDate != null
                              ? DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_selectedDate!)
                              : '',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // Action Buttons
                  Row(
                    children: [
                      // Reset to Today
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _selectedDate = DateTime.now();
                            _updateParametersForDate(_selectedDate!, settings);
                          });
                        },
                        icon: const Icon(Icons.today, color: Color(0xFFD4AF37), size: 20),
                        tooltip: 'Kembali ke Hari Ini',
                      ),
                      const SizedBox(width: 4),
                      // Date Picker Button
                      ElevatedButton.icon(
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate ?? now,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: Color(0xFFD4AF37), // gold
                                    onPrimary: Color(0xFF051C15), // deep emerald
                                    surface: Color(0xFF0C3C2C),
                                    onSurface: Colors.white,
                                  ),
                                  dialogTheme: const DialogThemeData(
                                    backgroundColor: Color(0xFF051C15),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null && picked != _selectedDate) {
                            setState(() {
                              _selectedDate = picked;
                              _updateParametersForDate(_selectedDate!, settings);
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                          foregroundColor: const Color(0xFFE6C575),
                          side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.calendar_month, size: 14),
                        label: Text(
                          'Pilih Kalender',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Twilight Sky Canvas with Dynamic Moon
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0F1A30), // Deep twilight
                    Color(0xFF1E3A5F), // Dusky blue
                    Color(0xFF8D532B), // Sunset orange
                    Color(0xFFD36F30), // Golden horizon
                  ],
                  stops: [0.0, 0.4, 0.8, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Sunset Horizon glow line
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 6,
                        color: const Color(0xFFE6C575).withValues(alpha: 0.4),
                      ),
                    ),
                    // Horizon label
                    Positioned(
                      bottom: 10,
                      left: 15,
                      child: Text(
                        'UFUK (HORIZON)',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    
                    // Dynamic Moon Sighting representation
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      bottom: moonBottomOffset,
                      left: MediaQuery.of(context).size.width * 0.4,
                      child: Stack(
                        children: [
                          // Base circle (glowing yellow moon body)
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFFE082),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFB300).withValues(alpha: 0.3),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          // Overlapping blue mask to create a crescent shape
                          // Mask shifts right/left based on elongation to make it thicker/thinner
                          Positioned(
                            left: moonMaskOffset,
                            top: 0,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF1E3A5F), // Matches the dusky blue sky layer
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Live indicators overlaid on the Sky Canvas
                    Positioned(
                      top: 15,
                      right: 15,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Tinggi: ${_simAltitude.toStringAsFixed(1)}°  |  Elongasi: ${_simElongation.toStringAsFixed(1)}°',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Controls and Real-time Moon Details Combined Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location metadata header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: Color(0xFFD4AF37), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            locationName,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _selectedDate != null ? DateFormat('dd/MM/yyyy').format(_selectedDate!) : '',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFD4AF37),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  
                  // Moon age & phase info boxes
                  Row(
                    children: [
                      Expanded(
                        child: _buildMoonDataBox(
                          'Estimasi Umur Bulan',
                          '${age.toStringAsFixed(2)} Hari',
                          _getMoonPhaseName(age),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMoonDataBox(
                          'Status Ufuk Barat',
                          _simAltitude > 0 ? 'DI ATAS UFUK' : 'DI BAWAH UFUK',
                          _simAltitude > 0 ? 'Potensi Terlihat' : 'Tidak Terlihat',
                          valueColor: _simAltitude > 0 ? const Color(0xFF81C784) : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                  const SizedBox(height: 16),

                  // Altitude Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Simulasi Tinggi Hilal',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_simAltitude.toStringAsFixed(2)}°',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFD4AF37),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _simAltitude,
                    min: -10.0,
                    max: 15.0,
                    divisions: 250,
                    activeColor: const Color(0xFFD4AF37),
                    inactiveColor: Colors.white12,
                    onChanged: (val) {
                      setState(() {
                        _simAltitude = val;
                      });
                    },
                  ),
                  const SizedBox(height: 10),

                  // Elongation Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Simulasi Elongasi Hilal',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_simElongation.toStringAsFixed(2)}°',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFD4AF37),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _simElongation,
                    min: 0.0,
                    max: 20.0,
                    divisions: 200,
                    activeColor: const Color(0xFFD4AF37),
                    inactiveColor: Colors.white12,
                    onChanged: (val) {
                      setState(() {
                        _simElongation = val;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Live Decision Cards (Kemenag vs Muhammadiyah)
            Row(
              children: [
                // KEMENAG / NU (MABIMS) Decision Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    height: 165,
                    decoration: BoxDecoration(
                      color: meetsMabims 
                          ? const Color(0xFF0F5A3E).withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: meetsMabims 
                            ? const Color(0xFF16A06B).withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.05),
                        width: meetsMabims ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kemenag / NU',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Kriteria MABIMS',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white38,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        // Requirements checklist
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildReqItem('Tinggi ≥ 3°', _simAltitude >= 3.0),
                            _buildReqItem('Elongasi ≥ 6.4°', _simElongation >= 6.4),
                          ],
                        ),
                        // Decision badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: meetsMabims
                                ? const Color(0xFF16A06B).withValues(alpha: 0.2)
                                : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                meetsMabims ? Icons.check_circle : Icons.cancel,
                                size: 12,
                                color: meetsMabims ? const Color(0xFF81C784) : Colors.redAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                meetsMabims ? 'BULAN BARU' : 'BELUM MASUK',
                                style: GoogleFonts.plusJakartaSans(
                                  color: meetsMabims ? const Color(0xFF81C784) : Colors.redAccent,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // MUHAMMADIYAH (KHGT) Decision Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    height: 165,
                    decoration: BoxDecoration(
                      color: meetsKhgt 
                          ? const Color(0xFF1E3A5F).withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: meetsKhgt 
                            ? const Color(0xFF5B92E5).withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.05),
                        width: meetsKhgt ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Muhammadiyah',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Kriteria KHGT',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white38,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        // Requirements checklist
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildReqItem('Tinggi ≥ 5°', _simAltitude >= 5.0),
                            _buildReqItem('Elongasi ≥ 8°', _simElongation >= 8.0),
                          ],
                        ),
                        // Decision badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: meetsKhgt
                                ? const Color(0xFF5B92E5).withValues(alpha: 0.2)
                                : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                meetsKhgt ? Icons.check_circle : Icons.cancel,
                                size: 12,
                                color: meetsKhgt ? const Color(0xFF90CAF9) : Colors.redAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                meetsKhgt ? 'BULAN BARU' : 'BELUM MASUK',
                                style: GoogleFonts.plusJakartaSans(
                                  color: meetsKhgt ? const Color(0xFF90CAF9) : Colors.redAccent,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Educational Description Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFD4AF37), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Mengapa Ada Perbedaan?',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildEdParagraph(
                    'Kriteria MABIMS (Kemenag & NU)',
                    'Digunakan secara regional di Brunei, Indonesia, Malaysia, dan Singapura. Mengedepankan integrasi hisab kontemporer dan pembuktian rukyat lapangan. Menetapkan awal bulan baru jika hilal terdeteksi minimal setinggi 3 derajat dengan elongasi 6,4 derajat di ufuk lokal.',
                  ),
                  const SizedBox(height: 16),
                  _buildEdParagraph(
                    'Kriteria KHGT (Muhammadiyah)',
                    'Mengadopsi kesepakatan Kongres Turki 2016 untuk mewujudkan Kalender Hijriah Global Tunggal (satu hari satu tanggal di seluruh dunia). Bulan baru dimulai secara global jika di bagian bumi mana pun terpenuhi kriteria tinggi hilal 5 derajat dan elongasi 8 derajat sebelum pukul 00:00 GMT.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReqItem(String label, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_rounded : Icons.close_rounded,
          size: 14,
          color: isMet ? Colors.green : Colors.white24,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isMet ? Colors.white : Colors.white38,
            fontSize: 12,
            fontWeight: isMet ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildEdParagraph(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFE6C575),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white60,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildMoonDataBox(String label, String value, String subtitle, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: valueColor ?? const Color(0xFFE6C575),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _getMoonPhaseName(double age) {
    if (age < 1.0) return 'Bulan Baru (New Moon)';
    if (age < 7.0) return 'Sabit Muda (Waxing Crescent)';
    if (age < 8.0) return 'Kuartal Pertama';
    if (age < 14.0) return 'Cembung Awal (Waxing Gibbous)';
    if (age < 15.5) return 'Purnama (Full Moon)';
    if (age < 22.0) return 'Cembung Akhir (Waning Gibbous)';
    if (age < 23.0) return 'Kuartal Ketiga';
    if (age < 28.5) return 'Sabit Tua (Waning Crescent)';
    return 'Bulan Mati (Dark Moon)';
  }
}
