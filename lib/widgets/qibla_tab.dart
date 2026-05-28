// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, uri_does_not_exist
import 'dart:async';
import 'dart:math' as math;
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/settings_provider.dart';
import '../models/app_settings.dart';
import '../data/cities.dart';

class QiblaTab extends ConsumerStatefulWidget {
  const QiblaTab({super.key});

  @override
  ConsumerState<QiblaTab> createState() => _QiblaTabState();
}

class _QiblaTabState extends ConsumerState<QiblaTab> with SingleTickerProviderStateMixin {
  bool _sensorsInitialized = false;
  double _currentHeading = 0.0;
  double _qiblaBearing = 0.0;
  double _distanceToMecca = 0.0;
  Timer? _sensorTimer;
  String? _sensorError;

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.1, end: 0.5).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Automatically calculate bearings on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateQiblaData();
    });
  }

  @override
  void dispose() {
    _sensorTimer?.cancel();
    _glowController.dispose();
    try {
      js.context.callMethod('stopOrientationUpdates');
    } catch (_) {}
    super.dispose();
  }

  // Calculate bearing to Mecca (Kaaba: 21.422524, 39.826206) and distance
  void _calculateQiblaData() {
    if (!mounted) return;
    final settings = ref.read(settingsProvider);
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

    // Standard Qibla Bearing calculation
    const double meccaLat = 21.422524;
    const double meccaLon = 39.826206;

    final double phi = latitude * math.pi / 180.0;
    final double lambda = longitude * math.pi / 180.0;
    final double phiK = meccaLat * math.pi / 180.0;
    final double lambdaK = meccaLon * math.pi / 180.0;

    final double deltaLambda = lambdaK - lambda;

    final double y = math.sin(deltaLambda);
    final double x = math.cos(phi) * math.tan(phiK) - math.sin(phi) * math.cos(deltaLambda);

    double qiblaRad = math.atan2(y, x);
    double qiblaDeg = qiblaRad * 180.0 / math.pi;

    // Haversine Distance to Mecca
    const double earthRadiusKm = 6371.0;
    final double dLat = (meccaLat - latitude) * math.pi / 180.0;
    final double dLon = (meccaLon - longitude) * math.pi / 180.0;

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(latitude * math.pi / 180.0) * math.cos(meccaLat * math.pi / 180.0) *
        math.sin(dLon / 2) * math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    if (mounted) {
      setState(() {
        _qiblaBearing = (qiblaDeg + 360.0) % 360.0;
        _distanceToMecca = earthRadiusKm * c;
      });
    }
  }

  // Request browser orientation sensors triggered by a user gesture
  Future<void> _startQiblaFinder() async {
    if (mounted) {
      setState(() {
        _sensorError = null;
      });
    }

    try {
      final prerequisiteError = _validateWebCompassPrerequisites();
      if (prerequisiteError != null) {
        if (mounted) {
          setState(() {
            _sensorError = prerequisiteError;
          });
        }
        return;
      }

      bool hasPermission = false;

      // Defensive check: if startOrientationUpdates JS function is not defined
      if (js.context['startOrientationUpdates'] != null) {
        final result = js.context.callMethod('startOrientationUpdates');
        
        if (result != null) {
          bool isPromise = false;
          try {
            if (result is! String && result is! bool && result is! num) {
              isPromise = js_util.hasProperty(result, 'then') == true;
            }
          } catch (_) {}

          if (isPromise) {
            try {
              final Future<dynamic> promiseFuture = js_util.promiseToFuture(result);
              final permission = await promiseFuture;
              hasPermission = (permission.toString() == 'granted');
            } catch (_) {
              hasPermission = (result.toString() == 'granted');
            }
          } else {
            hasPermission = (result.toString() == 'granted');
          }
        }
      } else {
        hasPermission = true;
      }
      
      if (hasPermission) {
        if (mounted) {
          setState(() {
            _sensorsInitialized = true;
          });
        }
        _startSensorPolling();
      } else {
        if (mounted) {
          setState(() {
            _sensorError = 'Izin kompas sensor perangkat ditolak. Pastikan sensor orientasi aktif.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sensorError = 'Browser tidak mendukung sensor kompas web: ${e.toString()}';
        });
      }
    }
  }

  String? _validateWebCompassPrerequisites() {
    try {
      final isSecureContext = js.context['isSecureContext'] == true;
      final protocol = js.context['location']?['protocol']?.toString() ?? '';

      // Browser sensor APIs are restricted to secure contexts, except localhost.
      if (!isSecureContext && protocol != 'http:') {
        return 'Akses sensor kompas diblokir karena halaman tidak berjalan pada konteks aman (HTTPS).';
      }

      final host = js.context['location']?['hostname']?.toString() ?? '';
      final isLocalhost = host == 'localhost' || host == '127.0.0.1';
      if (!isSecureContext && protocol == 'http:' && !isLocalhost) {
        return 'Gunakan HTTPS agar browser mengizinkan akses sensor orientasi/kompas.';
      }

      if (js.context['DeviceOrientationEvent'] == null) {
        return 'Browser/perangkat ini tidak menyediakan DeviceOrientationEvent (sensor kompas tidak tersedia).';
      }
    } catch (_) {
      return 'Gagal memvalidasi prasyarat sensor kompas web.';
    }
    return null;
  }

  void _startSensorPolling() {
    _sensorTimer?.cancel();
    _sensorTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) return;
      try {
        final heading = js.context['qiblaHeading'];
        if (heading != null) {
          final double val = double.tryParse(heading.toString()) ?? 0.0;
          
          // Apply low-pass filter to make compass rotation buttery smooth
          final double diff = val - _currentHeading;
          // Handle 360-degree wrap around
          final double filteredDiff = math.atan2(math.sin(diff * math.pi / 180.0), math.cos(diff * math.pi / 180.0)) * 180.0 / math.pi;
          
          if (mounted) {
            setState(() {
              _currentHeading = (_currentHeading + filteredDiff * 0.25) % 360.0;
            });
          }

          // If phone is aligned within +/- 5 degrees of Qibla, trigger a haptic vibration
          final double diffToQibla = (_currentHeading - _qiblaBearing).abs();
          if (diffToQibla < 5.0 || diffToQibla > 355.0) {
            _triggerHapticFeedback();
          }
        }
      } catch (_) {}
    });
  }

  void _triggerHapticFeedback() {
    try {
      if (js.context['navigator'] != null) {
        js.context['navigator'].callMethod('vibrate', [50]); // 50ms quick pulse
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    
    // Determine location name display
    String displayLoc = 'Lokasi Tidak Diketahui';
    if (settings.locationMode == LocationMode.preset) {
      displayLoc = settings.selectedCity;
    } else if (settings.locationMode == LocationMode.gps) {
      displayLoc = settings.gpsLocationName ?? 'GPS Koordinat';
    } else {
      displayLoc = 'Koordinat Kustom (${settings.customLatitude.toStringAsFixed(3)}, ${settings.customLongitude.toStringAsFixed(3)})';
    }

    // Relative angle from current phone heading to Qibla
    final double relativeQiblaAngle = (_qiblaBearing - _currentHeading + 360.0) % 360.0;
    
    // Check alignment with Kaaba (within 5 degrees tolerance)
    final bool isAligned = relativeQiblaAngle < 5.0 || relativeQiblaAngle > 355.0;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Deepest obsidian-emerald canvas background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF05120C), // Obsidian Emerald
                    Color(0xFF0C1D15),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // 2. Glowing Golden Pulse borders when aligned with Mecca
          if (isAligned && _sensorsInitialized)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withOpacity(_glowAnimation.value),
                        width: 15,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withOpacity(_glowAnimation.value * 0.4),
                          blurRadius: 40,
                        )
                      ],
                    ),
                  );
                },
              ),
            ),

          // 3. Main HUD UI Layer
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double screenWidth = constraints.maxWidth;

                return Column(
                  children: [
                    // Header Card
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C1913).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isAligned ? const Color(0xFFD4AF37) : const Color(0xFFD4AF37).withOpacity(0.15),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isAligned ? const Color(0xFFD4AF37).withOpacity(0.1) : Colors.black26,
                              blurRadius: 10,
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF05120C),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                              ),
                              child: const Icon(Icons.explore, color: Color(0xFFD4AF37), size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayLoc,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Kiblat: ${_qiblaBearing.toStringAsFixed(1)}° • Jarak: ${NumberFormat("#,###", "id_ID").format(_distanceToMecca.round())} km ke Ka\'bah',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF81C784),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Main Compass HUD / Onboarding Gate / Error Screen
                    Expanded(
                      child: Center(
                        child: _sensorError != null
                            ? _buildErrorScreen()
                            : !_sensorsInitialized
                                ? _buildOnboardingScreen(screenWidth)
                                : _buildCompassHud(screenWidth, relativeQiblaAngle, isAligned),
                      ),
                    ),

                    // Bottom Calibration Info Action
                    if (_sensorsInitialized)
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: InkWell(
                          onTap: _showCalibrationGuide,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C1913).withOpacity(0.6),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.help_outline, color: Color(0xFFD4AF37), size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  'Kalibrasi Kompas',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFFD4AF37),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 1. Onboarding Screen Gate (Creates Required User Gesture Context)
  Widget _buildOnboardingScreen(double width) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          padding: const EdgeInsets.all(28.0),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1913).withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.2), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 20,
                offset: Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Spinning Elegant Golden Logo
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(seconds: 2),
                builder: (context, val, child) {
                  return Transform.rotate(
                    angle: val * math.pi * 2,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [Color(0xFFFFE082), Color(0xFFD4AF37)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD4AF37).withOpacity(0.4),
                            blurRadius: 25,
                          )
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.explore,
                          size: 55,
                          color: Color(0xFF05120C),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'KOMPAS KIBLAT AL-WAQT',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFD4AF37),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: 2.0,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Al-Waqt menghadirkan sensor kompas 3D presisi tinggi. Tekan tombol di bawah untuk mengaktifkan sensor arah mata angin pada perangkat Anda.',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Device capability tip
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF05120C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF81C784).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF81C784), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pastikan browser Anda diizinkan untuk mengakses sensor arah/kompas HP.',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF81C784),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A1A08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFD4AF37), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Akurasi heading di browser dapat berbeda-beda antar perangkat dan kalibrasi OS.',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFE6C575),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              
              // Start Button (User Gesture)
              ElevatedButton(
                onPressed: _startQiblaFinder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: const Color(0xFF05120C),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 5,
                  shadowColor: const Color(0xFFD4AF37).withOpacity(0.3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Aktifkan Sensor Kompas',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Circular rotating Compass Dial
  Widget _buildCompassHud(double width, double relativeQibla, bool isAligned) {
    final double compassSize = math.min(width * 0.82, 360.0);

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Glow Backdrop for alignment
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: compassSize + 40,
                height: compassSize + 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: isAligned
                          ? const Color(0xFFD4AF37).withOpacity(0.2)
                          : const Color(0xFF0F5A3E).withOpacity(0.05),
                      blurRadius: 40,
                      spreadRadius: 10,
                    )
                  ],
                ),
              ),
              
              // Rotating Compass Plate with Ka'bah icon at qibla corner
              Transform.rotate(
                angle: -_currentHeading * math.pi / 180.0,
                child: SizedBox(
                  width: compassSize,
                  height: compassSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size(compassSize, compassSize),
                        painter: CompassDialPainter(
                          qiblaBearing: _qiblaBearing,
                          isAligned: isAligned,
                        ),
                      ),
                      Builder(builder: (context) {
                        final double qiblaRad = (_qiblaBearing - 90.0) * math.pi / 180.0;
                        final double iconDist = compassSize / 2 - 35;
                        return Transform.translate(
                          offset: Offset(
                            iconDist * math.cos(qiblaRad),
                            iconDist * math.sin(qiblaRad),
                          ),
                          child: Transform.rotate(
                            angle: _currentHeading * math.pi / 180.0,
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 300),
                              scale: isAligned ? 1.2 : 1.0,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF05120C),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFD4AF37),
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFD4AF37).withOpacity(isAligned ? 0.6 : 0.3),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    )
                                  ],
                                ),
                                child: const Icon(
                                  Icons.mosque,
                                  size: 22,
                                  color: Color(0xFFD4AF37),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // Stationary Premium HUD Overlays
              Container(
                width: compassSize - 4,
                height: compassSize - 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isAligned ? const Color(0xFFD4AF37) : Colors.white10,
                    width: 2,
                  ),
                ),
              ),

              // Fixed Top Pointer
              Positioned(
                top: 2,
                child: Column(
                  children: [
                    CustomPaint(
                      size: const Size(16, 12),
                      painter: TrianglePointerPainter(color: isAligned ? const Color(0xFFD4AF37) : Colors.white60),
                    ),
                    Container(
                      width: 2,
                      height: 18,
                      color: isAligned ? const Color(0xFFD4AF37) : Colors.white24,
                    )
                  ],
                ),
              ),

              // Center crosshair dot
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF05120C),
                  border: Border.all(
                    color: isAligned ? const Color(0xFFD4AF37) : const Color(0xFFD4AF37).withOpacity(0.5),
                    width: 2,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 36),

          // Guidance status text
          _buildGuidanceLabel(relativeQibla, isAligned),
          const SizedBox(height: 10),
          Text(
            'Akurasi kompas web dapat bervariasi. Lakukan kalibrasi jika arah terasa meleset.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Guidance status label under the compass/HUD
  Widget _buildGuidanceLabel(double relativeQibla, bool isAligned) {
    if (isAligned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F5A3E).withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4AF37).withOpacity(0.2),
              blurRadius: 15,
            )
          ],
        ),
        child: Column(
          children: [
            Text(
              '✓ MENGHADAP KA\'BAH',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: const Color(0xFFD4AF37),
                fontSize: 14,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Arah kiblat presisi terkonfirmasi',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            )
          ],
        ),
      );
    }

    final bool turnLeft = relativeQibla > 180.0;
    final double degreesToTurn = turnLeft ? 360.0 - relativeQibla : relativeQibla;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1913).withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        'Putar perangkat Anda ke ${turnLeft ? "kiri" : "kanan"} ${degreesToTurn.toStringAsFixed(0)}°',
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white70,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  // Error screen if device lacks sensors
  Widget _buildErrorScreen() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
            const SizedBox(height: 16),
            Text(
              'Sensor Tidak Dapat Diakses',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _sensorError ?? 'Sensor orientasi kompas tidak didukung di perangkat atau browser Anda.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: Colors.white70,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _sensorError = null;
                  _sensorsInitialized = false;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white12,
                foregroundColor: Colors.white,
              ),
              child: const Text('Coba Lagi'),
            )
          ],
        ),
      ),
    );
  }

  // Compass Calibration Guide Modal
  void _showCalibrationGuide() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0C1913),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.3), width: 1),
          ),
          title: Text(
            'Panduan Kalibrasi Kompas',
            style: GoogleFonts.outfit(
              color: const Color(0xFFD4AF37),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(seconds: 4),
                builder: (context, val, child) {
                  return Transform.rotate(
                    angle: val * math.pi * 2,
                    child: const Icon(
                      Icons.all_inclusive,
                      size: 60,
                      color: Color(0xFFD4AF37),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Agar sensor kompas bekerja akurat dan presisi:',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              _buildGuideStep('1', 'Pegang HP Anda dengan posisi datar mendatar (sejajar dengan tanah/lantai).'),
              _buildGuideStep('2', 'Gerakkan HP Anda membentuk pola angka delapan (∞) di udara sebanyak 2-3 kali.'),
              _buildGuideStep('3', 'Jauhkan HP dari benda-benda logam keras, magnet, atau perangkat elektronik yang memancarkan medan magnet kuat (seperti laptop atau speaker besar).'),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD4AF37),
              ),
              child: const Text('Mengerti'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGuideStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFF05120C),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFD4AF37),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// CUSTOM PAINTERS
// =========================================================================

// 1. Compass Dial Painter for the 2D Circular rotating plate
class CompassDialPainter extends CustomPainter {
  final double qiblaBearing;
  final bool isAligned;

  CompassDialPainter({
    required this.qiblaBearing,
    required this.isAligned,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(radius, radius);
    final double innerRadius = radius - 15;

    // Paints
    final dialPaint = Paint()
      ..color = const Color(0xFF0C1913)
      ..style = PaintingStyle.fill;

    final goldPaint = Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final goldThinPaint = Paint()
      ..color = const Color(0xFFD4AF37).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 1. Draw outer circle
    canvas.drawCircle(center, radius, dialPaint);
    canvas.drawCircle(center, radius - 4, goldPaint);
    canvas.drawCircle(center, innerRadius - 20, goldThinPaint);

    // 2. Draw Islamic Mandala inner decorative pattern
    final mandalaPaint = Paint()
      ..color = const Color(0xFF0F5A3E).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    for (int i = 0; i < 8; i++) {
      final double angle = i * math.pi / 4;
      final Offset end = Offset(
        center.dx + (innerRadius - 40) * math.cos(angle),
        center.dy + (innerRadius - 40) * math.sin(angle),
      );
      canvas.drawCircle(center, (innerRadius - 40) / 2, mandalaPaint);
      canvas.drawLine(center, end, goldThinPaint);
    }

    // 3. Draw Compass Ticks (Every 10 degrees)
    for (int i = 0; i < 360; i += 10) {
      final double angle = i * math.pi / 180.0;
      final bool isMajor = i % 30 == 0;
      final double length = isMajor ? 12.0 : 6.0;

      final Offset p1 = Offset(
        center.dx + (radius - 4) * math.cos(angle),
        center.dy + (radius - 4) * math.sin(angle),
      );
      final Offset p2 = Offset(
        center.dx + (radius - 4 - length) * math.cos(angle),
        center.dy + (radius - 4 - length) * math.sin(angle),
      );

      canvas.drawLine(p1, p2, isMajor ? goldPaint : goldThinPaint);
    }

    // 4. Draw Cardinal Directions
    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
    );

    final List<Map<String, dynamic>> cardinals = [
      {'label': 'U', 'angle': 270.0, 'color': Colors.redAccent}, // North
      {'label': 'T', 'angle': 0.0, 'color': Colors.white},       // East
      {'label': 'S', 'angle': 90.0, 'color': Colors.white},      // South
      {'label': 'B', 'angle': 180.0, 'color': Colors.white},     // West
    ];

    for (var card in cardinals) {
      final double angleRad = card['angle'] * math.pi / 180.0;
      final String label = card['label'];
      final Color color = card['color'];

      textPainter.text = TextSpan(
        text: label,
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      );

      textPainter.layout();
      final Offset textOffset = Offset(
        center.dx + (innerRadius - 22) * math.cos(angleRad) - textPainter.width / 2,
        center.dy + (innerRadius - 22) * math.sin(angleRad) - textPainter.height / 2,
      );

      canvas.save();
      canvas.translate(textOffset.dx + textPainter.width / 2, textOffset.dy + textPainter.height / 2);
      canvas.drawCircle(Offset.zero, 11, Paint()..color = const Color(0xFF05120C));
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }

    // 5. Draw the Dynamic Qibla Arrow Pointer pointing to Mecca
    final double qiblaRad = (qiblaBearing - 90.0) * math.pi / 180.0;

    final Offset meccaPos = Offset(
      center.dx + (innerRadius - 50) * math.cos(qiblaRad),
      center.dy + (innerRadius - 50) * math.sin(qiblaRad),
    );

    // Glow effect behind the needle for emphasis
    final glowPaint = Paint()
      ..color = (isAligned ? const Color(0xFFD4AF37) : const Color(0xFF81C784)).withOpacity(0.25)
      ..strokeWidth = 10.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawLine(center, meccaPos, glowPaint);

    // Main needle - thicker and more prominent
    final needlePaint = Paint()
      ..color = isAligned ? const Color(0xFFD4AF37) : const Color(0xFF81C784)
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, meccaPos, needlePaint);

    // Arrowhead at the needle tip
    final double arrowSize = 14.0;
    final Offset arrowLeft = Offset(
      meccaPos.dx - arrowSize * math.cos(qiblaRad - 0.45),
      meccaPos.dy - arrowSize * math.sin(qiblaRad - 0.45),
    );
    final Offset arrowRight = Offset(
      meccaPos.dx - arrowSize * math.cos(qiblaRad + 0.45),
      meccaPos.dy - arrowSize * math.sin(qiblaRad + 0.45),
    );
    final arrowPath = Path()
      ..moveTo(meccaPos.dx, meccaPos.dy)
      ..lineTo(arrowLeft.dx, arrowLeft.dy)
      ..lineTo(arrowRight.dx, arrowRight.dy)
      ..close();
    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = isAligned ? const Color(0xFFD4AF37) : const Color(0xFF81C784)
        ..style = PaintingStyle.fill,
    );

    // Dim opposite line for compass balance
    final Offset oppositePos = Offset(
      center.dx - (innerRadius - 60) * math.cos(qiblaRad),
      center.dy - (innerRadius - 60) * math.sin(qiblaRad),
    );
    canvas.drawLine(
      center,
      oppositePos,
      Paint()
        ..color = Colors.white.withOpacity(0.08)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CompassDialPainter oldDelegate) {
    return oldDelegate.qiblaBearing != qiblaBearing || oldDelegate.isAligned != isAligned;
  }
}

// 2. Triangle Pointer Painter
class TrianglePointerPainter extends CustomPainter {
  final Color color;
  TrianglePointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant TrianglePointerPainter oldDelegate) => oldDelegate.color != color;
}
