// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/settings_provider.dart';
import '../models/app_settings.dart';
import '../data/cities.dart';
import '../utils/hijri_converter.dart';
import '../config/app_version.dart';

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  late TextEditingController _latController;
  late TextEditingController _lngController;
  final TextEditingController _osmSearchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _osmSearchResults = [];
  bool _isSearchingOsm = false;
  String? _osmSearchError;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _latController = TextEditingController(text: settings.customLatitude.toString());
    _lngController = TextEditingController(text: settings.customLongitude.toString());
    
    // Automatically trigger GPS fetch if GPS is selected as mode but coordinates are null
    if (settings.locationMode == LocationMode.gps && settings.gpsLatitude == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerGpsFetch();
      });
    }
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _osmSearchController.dispose();
    super.dispose();
  }

  bool _isLoadingGps = false;
  String? _gpsError;

  Future<void> _triggerGpsFetch() async {
    setState(() {
      _isLoadingGps = true;
      _gpsError = null;
    });

    try {
      await ref.read(settingsProvider.notifier).fetchGpsLocation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lokasi GPS presisi tinggi berhasil didapatkan!',
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF0F5A3E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _gpsError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGps = false;
        });
      }
    }
  }

  void _saveCustomCoords() {
    if (_formKey.currentState!.validate()) {
      final lat = double.parse(_latController.text);
      final lng = double.parse(_lngController.text);
      ref.read(settingsProvider.notifier).setCustomCoordinates(lat, lng);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Koordinat kustom berhasil disimpan!',
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF0F5A3E),
        ),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isMuhammadiyah = settings.calcMethod == CalcMethod.muhammadiyah;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pengaturan Jadwal Sholat',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Kelola metode hisab dan kustomisasi koordinat untuk mendapatkan hasil presisi.',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white60,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),

              // CARD 1: METODE PERHITUNGAN
              _buildSettingsCard(
                title: 'Metode Perhitungan',
                icon: Icons.auto_awesome_outlined,
                child: RadioGroup<CalcMethod>(
                  groupValue: settings.calcMethod,
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(settingsProvider.notifier).setCalcMethod(val);
                    }
                  },
                  child: Column(
                    children: [
                      RadioListTile<CalcMethod>(
                        title: Text(
                          'Kementerian Agama RI (NU)',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Sudut Shubuh -20°  |  Isya -18°',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 11),
                        ),
                        value: CalcMethod.kemenag,
                        activeColor: const Color(0xFFD4AF37),
                      ),
                      Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                      RadioListTile<CalcMethod>(
                        title: Text(
                          'Muhammadiyah (Tarjih)',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Sudut Shubuh -18°  |  Isya -18°',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 11),
                        ),
                        value: CalcMethod.muhammadiyah,
                        activeColor: const Color(0xFFD4AF37),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // CARD 2: PENGAMAN SHOLAT (IHTIYATI)
              _buildSettingsCard(
                title: 'Faktor Pengaman (Ihtiyati)',
                icon: Icons.shield_outlined,
                child: SwitchListTile(
                  title: Text(
                    'Tambah Waktu Ihtiyati (+2 Menit)',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Standardisasi Kemenag untuk keamanan fiqih masuk waktu shalat.',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                  value: settings.useIhtiyati,
                  activeThumbColor: const Color(0xFFD4AF37),
                  activeTrackColor: const Color(0xFF0F5A3E),
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).setUseIhtiyati(val);
                  },
                ),
              ),
              const SizedBox(height: 20),

              // CARD 2B: KOREKSI KALENDER HIJRIAH (Sidang Isbat)
              if (settings.calcMethod == CalcMethod.kemenag) ...[
                _buildSettingsCard(
                  title: 'Koreksi Kalender Hijriah (Sidang Isbat)',
                  icon: Icons.calendar_month_outlined,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Pemerintah RI menetapkan awal bulan Hijriah secara resmi melalui Sidang Isbat yang diberitakan dalam tanggal Masehi. Masukkan tanggal keputusan di bawah ini untuk menyesuaikan kalender.',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white38,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Date selector field
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final initialDate = settings.isbatDateStr != null
                                      ? DateTime.tryParse(settings.isbatDateStr!) ?? DateTime.now()
                                      : DateTime.now();
                                  final selected = await showDatePicker(
                                    context: context,
                                    initialDate: initialDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: const ColorScheme.dark(
                                            primary: Color(0xFFD4AF37),
                                            onPrimary: Colors.black,
                                            surface: Color(0xFF051C15),
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
                                  if (selected != null) {
                                    final formatted = DateFormat('yyyy-MM-dd').format(selected);
                                    await ref.read(settingsProvider.notifier).setIsbatDate(formatted);
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: settings.isbatDateStr != null
                                          ? const Color(0xFFD4AF37).withValues(alpha: 0.4)
                                          : Colors.white.withValues(alpha: 0.05),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.date_range_outlined, color: Color(0xFFD4AF37), size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Tanggal Keputusan / Berita (Masehi)',
                                              style: GoogleFonts.plusJakartaSans(
                                                color: Colors.white60,
                                                fontSize: 10,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              settings.isbatDateStr != null
                                                  ? DateFormat('d MMMM yyyy', 'id_ID').format(DateTime.parse(settings.isbatDateStr!))
                                                  : 'Pilih Tanggal Keputusan...',
                                              style: GoogleFonts.plusJakartaSans(
                                                color: settings.isbatDateStr != null ? Colors.white : Colors.white30,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (settings.isbatDateStr == null)
                                        const Icon(Icons.arrow_drop_down, color: Colors.white30),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (settings.isbatDateStr != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.clear_rounded, color: Colors.white70, size: 20),
                                tooltip: 'Hapus Koreksi',
                                onPressed: () {
                                  ref.read(settingsProvider.notifier).setIsbatDate(null);
                                  ref.read(settingsProvider.notifier).setHijriOffset(0);
                                },
                              ),
                            ],
                          ],
                        ),
                        if (settings.isbatDateStr != null) ...[
                Text(
                  'Tanggal tersebut bertepatan dengan: ${HijriConverter.fromGregorian(DateTime.parse(settings.isbatDateStr!), settings.calcMethod).formatted}',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),

                        if (settings.isbatDateStr != null) ...[
                          Text(
                            'Koreksi Kalender untuk bulan Hijriah di atas:',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _buildOffsetChip(context, -1, '-1 Hari'),
                              _buildOffsetChip(context, 0, 'Ya, benar'),
                              _buildOffsetChip(context, 1, '+1 Hari'),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Official announcement Link button (sleek and gold)
                        OutlinedButton.icon(
                          onPressed: () {
                            ref.read(settingsProvider.notifier).openUrl(
                              'https://www.google.com/search?q=hasil+sidang+isbat+kemenag+terbaru'
                            );
                          },
                          icon: const Icon(Icons.search_outlined, color: Color(0xFFD4AF37), size: 16),
                          label: Text(
                            'Cari Pengumuman Sidang Isbat Kemenag',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFD4AF37),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: const Color(0xFFD4AF37).withValues(alpha: 0.02),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // CARD 3: LOKASI
              _buildSettingsCard(
                title: 'Lokasi & Koordinat',
                icon: Icons.location_on_outlined,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Toggle Location Mode
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: Center(
                                child: Text(
                                  'Daftar Kota',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: settings.locationMode == LocationMode.preset ? Colors.black : Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              selected: settings.locationMode == LocationMode.preset,
                              selectedColor: const Color(0xFFD4AF37),
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              onSelected: (selected) {
                                if (selected) {
                                  ref.read(settingsProvider.notifier).setLocationMode(LocationMode.preset);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: Center(
                                child: Text(
                                  'Kustom',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: settings.locationMode == LocationMode.custom ? Colors.black : Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              selected: settings.locationMode == LocationMode.custom,
                              selectedColor: const Color(0xFFD4AF37),
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              onSelected: (selected) {
                                if (selected) {
                                  ref.read(settingsProvider.notifier).setLocationMode(LocationMode.custom);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: Center(
                                child: Text(
                                  'Auto GPS',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: settings.locationMode == LocationMode.gps ? Colors.black : Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              selected: settings.locationMode == LocationMode.gps,
                              selectedColor: const Color(0xFFD4AF37),
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              onSelected: (selected) {
                                if (selected) {
                                  ref.read(settingsProvider.notifier).setLocationMode(LocationMode.gps);
                                  _triggerGpsFetch();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Mode 1: DYNAMIC CITY SELECTOR (OSM Search & Presets combined!)
                      if (settings.locationMode == LocationMode.preset)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Current Active City Display
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4AF37).withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_city_outlined, color: Color(0xFFD4AF37), size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Kota / Wilayah Aktif',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: const Color(0xFFD4AF37),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          settings.selectedCity,
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // OSM City Search Bar
                            TextFormField(
                              controller: _osmSearchController,
                              style: GoogleFonts.plusJakartaSans(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Cari Kota / Wilayah di Indonesia...',
                                labelStyle: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 13),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.03),
                                prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37)),
                                suffixIcon: _isSearchingOsm
                                    ? const Padding(
                                        padding: EdgeInsets.all(12.0),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                                          ),
                                        ),
                                      )
                                    : _osmSearchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, color: Colors.white30, size: 18),
                                            onPressed: () {
                                              _osmSearchController.clear();
                                              setState(() {
                                                _osmSearchResults = [];
                                              });
                                            },
                                          )
                                        : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                                ),
                              ),
                              onChanged: (query) async {
                                if (query.length >= 3) {
                                  setState(() {
                                    _isSearchingOsm = true;
                                    _osmSearchError = null;
                                  });
                                  try {
                                    final results = await ref
                                        .read(settingsProvider.notifier)
                                        .searchOsmCities(query);
                                    setState(() {
                                      _osmSearchResults = results;
                                      _isSearchingOsm = false;
                                    });
                                  } catch (e) {
                                    setState(() {
                                      _isSearchingOsm = false;
                                      _osmSearchError = 'Gagal mencari lokasi. Periksa koneksi internet Anda.';
                                    });
                                  }
                                } else {
                                  setState(() {
                                    _osmSearchResults = [];
                                  });
                                }
                              },
                            ),

                            // OSM Search Results Dropdown List
                            if (_osmSearchResults.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161E1A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _osmSearchResults.length,
                                  separatorBuilder: (context, index) => Divider(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    height: 1,
                                  ),
                                  itemBuilder: (context, index) {
                                    final place = _osmSearchResults[index];
                                    return ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.pin_drop_outlined, color: Color(0xFFD4AF37), size: 16),
                                      title: Text(
                                        place['name'] ?? '',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Lintang: ${place['latitude']?.toStringAsFixed(4)}, Bujur: ${place['longitude']?.toStringAsFixed(4)}',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                      onTap: () async {
                                        await ref.read(settingsProvider.notifier).setOsmSelectedCity(
                                              cityName: place['name'] ?? '',
                                              latitude: place['latitude'] ?? 0.0,
                                              longitude: place['longitude'] ?? 0.0,
                                            );
                                        _osmSearchController.clear();
                                        setState(() {
                                          _osmSearchResults = [];
                                        });
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              backgroundColor: const Color(0xFF0C3C2C),
                                              content: Text(
                                                'Lokasi berhasil diatur ke ${place['name']}',
                                                style: GoogleFonts.plusJakartaSans(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                            
                            if (_osmSearchError != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _osmSearchError!,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.redAccent,
                                  fontSize: 11,
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),
                            
                            // Preset Divider option
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.05))),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                  child: Text(
                                    'Atau pilih kota preset cepat',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white30,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.05))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // Quick Dropdown preset fallback
                            DropdownButtonFormField<String>(
                              initialValue: presetCities.any((c) => c.name == settings.selectedCity) 
                                  ? settings.selectedCity 
                                  : null,
                              hint: Text(
                                'Pilih Kota Cepat...',
                                style: GoogleFonts.plusJakartaSans(color: Colors.white30, fontSize: 13),
                              ),
                              dropdownColor: const Color(0xFF161E1A),
                              decoration: InputDecoration(
                                labelText: 'Kota Preset Cepat',
                                labelStyle: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 13),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.03),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                                ),
                              ),
                              items: presetCities.map((city) {
                                return DropdownMenuItem<String>(
                                  value: city.name,
                                  child: Text(
                                    '${city.name} (GMT+${city.timezone.toInt()})',
                                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
                                  ),
                                );
                              }).toList(),
                              onChanged: (city) {
                                if (city != null) {
                                  final selectedPreset = presetCities.firstWhere((c) => c.name == city);
                                  ref.read(settingsProvider.notifier).setOsmSelectedCity(
                                    cityName: selectedPreset.name,
                                    latitude: selectedPreset.latitude,
                                    longitude: selectedPreset.longitude,
                                  );
                                }
                              },
                            ),
                          ],
                        ),

                      // Mode 2: CUSTOM COORDINATE INPUTS
                      if (settings.locationMode == LocationMode.custom)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                // Latitude Input
                                Expanded(
                                  child: TextFormField(
                                    controller: _latController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: GoogleFonts.outfit(color: Colors.white),
                                    decoration: _buildInputDecoration('Lintang (Latitude)'),
                                    validator: (val) {
                                      if (val == null || val.isEmpty) return 'Harus diisi';
                                      final num = double.tryParse(val);
                                      if (num == null) return 'Angka tidak valid';
                                      if (num < -90 || num > 90) return '-90 s/d 90';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Longitude Input
                                Expanded(
                                  child: TextFormField(
                                    controller: _lngController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: GoogleFonts.outfit(color: Colors.white),
                                    decoration: _buildInputDecoration('Bujur (Longitude)'),
                                    validator: (val) {
                                      if (val == null || val.isEmpty) return 'Harus diisi';
                                      final num = double.tryParse(val);
                                      if (num == null) return 'Angka tidak valid';
                                      if (num < -180 || num > 180) return '-180 s/d 180';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _saveCustomCoords,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F5A3E),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                                ),
                              ),
                              child: Text(
                                'Terapkan Koordinat',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),

                      // Mode 3: AUTO GPS DISPLAY & CONTROLS
                      if (settings.locationMode == LocationMode.gps)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.02),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                              ),
                              child: Column(
                                children: [
                                  if (settings.gpsLatitude != null && settings.gpsLongitude != null) ...[
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Nama Lokasi',
                                          style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 13),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            settings.gpsLocationName ?? 'GPS Terdeteksi',
                                            style: GoogleFonts.plusJakartaSans(color: const Color(0xFFE6C575), fontSize: 14, fontWeight: FontWeight.bold),
                                            textAlign: TextAlign.end,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Lintang GPS',
                                          style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 13),
                                        ),
                                        Text(
                                          '${settings.gpsLatitude!.toStringAsFixed(6)}°',
                                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Bujur GPS',
                                          style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 13),
                                        ),
                                        Text(
                                          '${settings.gpsLongitude!.toStringAsFixed(6)}°',
                                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Ketinggian (Altitude)',
                                          style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 13),
                                        ),
                                        Text(
                                          '${settings.gpsAltitude?.toStringAsFixed(1) ?? '0.0'} m',
                                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ] else if (_isLoadingGps) ...[
                                    const Center(
                                      child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Menghubungkan ke sensor GPS...',
                                      style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12),
                                    ),
                                  ] else ...[
                                    Text(
                                      'Sensor GPS belum diakses. Silakan klik tombol di bawah.',
                                      style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 12),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                  if (_gpsError != null) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      _gpsError!,
                                      style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                             ElevatedButton.icon(
                              onPressed: _isLoadingGps ? null : _triggerGpsFetch,
                              icon: _isLoadingGps 
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.gps_fixed_rounded, size: 18),
                              label: Text(
                                _isLoadingGps 
                                    ? 'Mendeteksi GPS...' 
                                    : (settings.gpsLatitude != null && settings.gpsLongitude != null)
                                        ? 'Perbarui Lokasi via GPS'
                                        : 'Dapatkan Lokasi via GPS',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F5A3E),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // CARD 4: FITUR PWA & LAYAR
              _buildSettingsCard(
                title: 'Fitur PWA & Layar',
                icon: Icons.cell_tower_outlined,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(
                        'Notifikasi Jadwal Sholat',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Dapatkan notifikasi lokal saat waktu Imsak dan Sholat tiba.',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                      value: settings.enableNotifications,
                      activeThumbColor: const Color(0xFFD4AF37),
                      activeTrackColor: const Color(0xFF0F5A3E),
                      onChanged: (val) {
                        ref.read(settingsProvider.notifier).setEnableNotifications(val);
                      },
                    ),
                    Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                    SwitchListTile(
                      title: Text(
                        'Jaga Layar Tetap Menyala',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Mencegah layar redup/mati (sangat berguna untuk HP dengan timeout rendah).',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                      value: settings.keepScreenOn,
                      activeThumbColor: const Color(0xFFD4AF37),
                      activeTrackColor: const Color(0xFF0F5A3E),
                      onChanged: (val) {
                        ref.read(settingsProvider.notifier).setKeepScreenOn(val);
                      },
                    ),

                  ],
                ),
              ),
              const SizedBox(height: 20),

              // CARD 5: DISPLAY ACTIVE CONFIG INFO
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0C2A1E).withValues(alpha: 0.3),
                      const Color(0xFF061811).withValues(alpha: 0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rangkuman Konfigurasi Aktif',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFE6C575),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow(
                      'Sistem Fiqih',
                      isMuhammadiyah 
                          ? 'Muhammadiyah (Shubuh -18°, KHGT)' 
                          : 'Kemenag RI / NU (Shubuh -20°, MABIMS)',
                    ),
                     _buildSummaryRow(
                      'Penyelaras Waktu',
                      settings.useIhtiyati ? 'Ihtiyati (+2 Menit) Aktif' : 'Tanpa Ihtiyati (0 Menit)',
                    ),
                    _buildSummaryRow(
                      'Kalkulator Lokasi',
                      settings.locationMode == LocationMode.preset
                          ? 'Kota ${settings.selectedCity}'
                          : settings.locationMode == LocationMode.gps
                              ? (settings.gpsLatitude != null
                                  ? 'Auto GPS - ${settings.gpsLocationName ?? "GPS Terdeteksi"}'
                                  : 'Auto GPS (Menunggu Sensor...)')
                              : 'Koordinat Kustom',
                    ),
                    if (settings.locationMode == LocationMode.gps && settings.gpsLatitude != null) ...[
                      _buildSummaryRow(
                        'Koordinat GPS',
                        '${settings.gpsLatitude!.toStringAsFixed(6)}°, ${settings.gpsLongitude!.toStringAsFixed(6)}°',
                      ),
                      _buildSummaryRow(
                        'Ketinggian (Alt)',
                        '${settings.gpsAltitude?.toStringAsFixed(1) ?? "0.0"} mdpl',
                      ),
                    ] else if (settings.locationMode == LocationMode.custom) ...[
                      _buildSummaryRow(
                        'Koordinat Kustom',
                        '${settings.customLatitude.toStringAsFixed(6)}°, ${settings.customLongitude.toStringAsFixed(6)}°',
                      ),
                    ],
                    _buildSummaryRow(
                      'Notifikasi Adzan',
                      settings.enableNotifications ? 'Aktif' : 'Nonaktif',
                    ),
                    _buildSummaryRow(
                      'Wake Lock Layar',
                      settings.keepScreenOn ? 'Mencegah Layar Redup' : 'Default Sistem',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Center(
                  child: Text(
                    'Al-Waqt v$kAppVersion',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white24,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildSettingsCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFFD4AF37), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
          Material(
            color: Colors.transparent,
            child: child,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildOffsetChip(BuildContext context, int offsetValue, String label) {
    final settings = ref.watch(settingsProvider);
    final isSelected = settings.hijriOffset == offsetValue;
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: isSelected ? Colors.black : Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFFD4AF37),
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      onSelected: (selected) {
        if (selected) {
          ref.read(settingsProvider.notifier).setHijriOffset(offsetValue);
        }
      },
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 12),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.03),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD4AF37)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      errorStyle: GoogleFonts.plusJakartaSans(fontSize: 10),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
