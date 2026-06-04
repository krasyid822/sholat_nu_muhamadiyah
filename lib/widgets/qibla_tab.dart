// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, uri_does_not_exist
import 'dart:async';
import 'dart:math' as math;
import 'dart:js' as js;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:web_compass/web_compass.dart';
import '../providers/settings_provider.dart';
import '../models/app_settings.dart';
import '../data/cities.dart';
import 'web_ar_view.dart';
import 'gps_loading_view.dart';

class QiblaTab extends ConsumerStatefulWidget {
  const QiblaTab({super.key});

  @override
  ConsumerState<QiblaTab> createState() => _QiblaTabState();
}

class _QiblaTabState extends ConsumerState<QiblaTab> with SingleTickerProviderStateMixin {
  bool _sensorsInitialized = false;
  bool _arViewVisible = false;
  bool _autoArActivationTriggered = false;
  double _currentHeading = 0.0;
  double _deviceTilt = 0.0;
  bool _isVerticalMode = false;
  double _qiblaBearing = 0.0;
  double _distanceToMecca = 0.0;
  String? _sensorError;
  double _rawPitch = 75.0;
  StreamSubscription<CompassEvent>? _compassSubscription;

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
      if (!_autoArActivationTriggered) {
        _autoArActivationTriggered = true;
        _startQiblaFinder();
      }
    });
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _glowController.dispose();
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
        _arViewVisible = true;
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

      final permissionGranted = await WebCompass.requestPermission();
      if (permissionGranted) {
        if (mounted) {
          setState(() {
            _sensorsInitialized = true;
            _sensorError = null;
          });
        }
        _startSensorListening();
      } else {
        if (mounted) {
          setState(() {
            _sensorError = 'Izin sensor kompas ditolak. Silakan aktifkan di pengaturan browser Anda.';
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

      if (!WebCompass.isSupported) {
        return 'Browser/perangkat ini tidak menyediakan DeviceOrientationEvent (sensor kompas tidak tersedia).';
      }
    } catch (_) {
      return 'Gagal memvalidasi prasyarat sensor kompas web.';
    }
    return null;
  }

  void _startSensorListening() {
    _compassSubscription?.cancel();
    _compassSubscription = WebCompass.onOrientationChanged.listen((event) {
      if (!mounted) return;
      
      final double val = event.heading;
      final double pitch = event.pitch;
      final double roll = event.roll;
      final double rawTilt = math.max(pitch.abs(), roll.abs());
      
      // Apply low-pass filter to make compass rotation buttery smooth
      final double diff = val - _currentHeading;
      // Handle 360-degree wrap around
      final double filteredDiff = math.atan2(math.sin(diff * math.pi / 180.0), math.cos(diff * math.pi / 180.0)) * 180.0 / math.pi;
      
      final bool nextVertical = _isVerticalMode
          ? rawTilt > 35.0
          : rawTilt > 45.0;

      setState(() {
        _currentHeading = (_currentHeading + filteredDiff * 0.25) % 360.0;
        _deviceTilt = (_deviceTilt * 0.7) + (rawTilt * 0.3);
        _isVerticalMode = nextVertical;
        _rawPitch = pitch;
      });

      // If phone is aligned within +/- 5 degrees of Qibla, trigger a haptic vibration
      final double diffToQibla = (_currentHeading - _qiblaBearing).abs();
      if (diffToQibla < 5.0 || diffToQibla > 355.0) {
        _triggerHapticFeedback();
      }
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
    
    if (settings.locationMode == LocationMode.gps && settings.isGpsLoading) {
      return const GpsLoadingView();
    }
    
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
          if (_arViewVisible)
            const Positioned.fill(
              child: WebARView(),
            ),

          // 1. Deepest obsidian-emerald canvas background
          if (!_sensorsInitialized)
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
                                : _buildAdaptiveArHud(screenWidth, relativeQiblaAngle, isAligned),
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
  Widget _buildAdaptiveArHud(double width, double relativeQibla, bool isAligned) {
    if (!_isVerticalMode) {
      return _buildCompassHud(width, relativeQibla, isAligned);
    }

    // 1. Calculate horizontal difference mapped to -180 to 180 degrees
    double diff = relativeQibla;
    if (diff > 180) {
      diff = diff - 360;
    }

    // 2. Define horizontal field of view (FOV) in degrees
    const double horizontalFOV = 50.0;
    final bool isVisible = diff.abs() <= (horizontalFOV / 2.0);

    // 3. Pitch calculation for vertical tracking (horizon)
    final double rawPitch = _rawPitch;
    final double pitchDiff = (rawPitch - 75.0).clamp(-25.0, 25.0);
    final double dy = pitchDiff * 8.0; // Corrected sign to fix reversed tilt!

    return LayoutBuilder(
      builder: (context, constraints) {
        final double height = constraints.maxHeight;
        final double centerX = width / 2.0;
        final double centerY = height * 0.45; // exact projection horizon center

        // Path coordinates pointing to where the Kaaba is in virtual space.
        // When off-screen, dx continues to grow large, which draws the line extending off-screen to guide the user!
        final double dx = (diff / (horizontalFOV / 2.0)) * (width / 2.0);

        final Offset startPoint = Offset(centerX, height * 0.82);
        final Offset endPoint = Offset(centerX + dx, centerY + dy);

        return Stack(
          children: [
            // 1. Dynamic holographic pathway tether line (Always visible!)
            Positioned.fill(
              child: CustomPaint(
                painter: PathwayLinePainter(
                  start: startPoint,
                  end: endPoint,
                  isAligned: isAligned,
                ),
              ),
            ),

            // 2. 3D Projected AR Horizon & Kaaba Layer (Visible only when in FOV)
            if (isVisible)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: Builder(
                    builder: (context) {
                      final double progress = diff.abs() / (horizontalFOV / 2.0); // 0.0 at center, 1.0 at edge
                      final double opacity = (1.0 - progress).clamp(0.0, 1.0);
                      final double scale = 0.65 + 0.35 * (1.0 - progress);
                      final double yaw = (diff / (horizontalFOV / 2.0)) * 0.5;

                      return Opacity(
                        opacity: opacity,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0012) // Perspective projection
                            ..translate(dx, dy, 0.0) // Position in 3D space
                            ..rotateY(-yaw) // Yaw rotation
                            ..scale(scale), // Depth scaling
                          child: _buildKaaba3DObject(isAligned),
                        ),
                      );
                    },
                  ),
                ),
              )
            else
              // If not in view, show a beautiful golden pointer pointing left/right to guide user!
              Positioned(
                left: 0,
                right: 0,
                top: height * 0.32,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _sensorsInitialized ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C1913).withOpacity(0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            diff > 0 ? Icons.arrow_circle_right_outlined : Icons.arrow_circle_left_outlined,
                            color: const Color(0xFFD4AF37),
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Putar perangkat Anda ke ${diff > 0 ? "kanan" : "kiri"} ${diff.abs().toStringAsFixed(0)}°',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            Positioned(
              top: 12,
              right: 12,
              child: _buildMiniCompassCorner(relativeQibla, isAligned),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Text(
                'Mode AR Vertikal aktif (tilt ${_deviceTilt.toStringAsFixed(0)}°)',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMiniCompassCorner(double relativeQibla, bool isAligned) {
    const double miniSize = 132;
    return Container(
      width: miniSize,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xCC0C1913),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAligned ? const Color(0xFFD4AF37) : Colors.white24,
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            width: miniSize - 24,
            height: miniSize - 24,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: -_currentHeading * math.pi / 180.0,
                  child: CustomPaint(
                    size: const Size(miniSize - 24, miniSize - 24),
                    painter: CompassDialPainter(
                      qiblaBearing: _qiblaBearing,
                      isAligned: isAligned,
                    ),
                  ),
                ),
                const Icon(Icons.navigation, color: Color(0xFFD4AF37), size: 18),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_currentHeading.toStringAsFixed(0)}°',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFD4AF37),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKaaba3DObject(bool isAligned) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF141414), Color(0xFF050505)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFD4AF37), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: (isAligned ? const Color(0xFFD4AF37) : Colors.black)
                .withOpacity(isAligned ? 0.35 : 0.45),
            blurRadius: isAligned ? 25 : 16,
            spreadRadius: isAligned ? 3 : 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x66D4AF37)),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 48,
            child: Container(
              height: 14,
              color: const Color(0xFFD4AF37).withOpacity(0.9),
              child: Center(
                child: Container(
                  height: 1,
                  color: const Color(0xFFFFE082),
                ),
              ),
            ),
          ),
          const Center(
            child: Icon(Icons.mosque, size: 60, color: Color(0xFFD4AF37)),
          ),
        ],
      ),
    );
  }

  // Circular rotating Compass Dial
  Widget _buildCompassHud(double width, double relativeQibla, bool isAligned) {
    final double compassSize = math.min(width * 0.72, 320.0);

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
              
              // Rotating Compass Plate
              Transform.rotate(
                angle: -_currentHeading * math.pi / 180.0,
                child: SizedBox(
                  width: compassSize,
                  height: compassSize,
                  child: CustomPaint(
                    painter: CompassDialPainter(
                      qiblaBearing: _qiblaBearing,
                      isAligned: isAligned,
                    ),
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

              // Central Dome Mosque Icon
              Positioned(
                child: Center(
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 300),
                    scale: isAligned ? 1.25 : 1.0,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF05120C),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isAligned ? const Color(0xFFD4AF37) : const Color(0xFFD4AF37).withOpacity(0.2),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isAligned ? const Color(0xFFD4AF37).withOpacity(0.4) : Colors.black45,
                            blurRadius: 15,
                          )
                        ],
                      ),
                      child: Icon(
                        Icons.mosque,
                        size: 32,
                        color: isAligned ? const Color(0xFFD4AF37) : const Color(0xFFD4AF37).withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),

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
        center.dx + (innerRadius - 8) * math.cos(angleRad) - textPainter.width / 2,
        center.dy + (innerRadius - 8) * math.sin(angleRad) - textPainter.height / 2,
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
      center.dx + (innerRadius - 12) * math.cos(qiblaRad),
      center.dy + (innerRadius - 12) * math.sin(qiblaRad),
    );

    final needlePaint = Paint()
      ..color = isAligned ? const Color(0xFFD4AF37) : const Color(0xFF81C784)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, meccaPos, needlePaint);

    final domePath = Path();
    domePath.moveTo(meccaPos.dx, meccaPos.dy - 12);
    domePath.quadraticBezierTo(meccaPos.dx - 8, meccaPos.dy, meccaPos.dx, meccaPos.dy + 4);
    domePath.quadraticBezierTo(meccaPos.dx + 8, meccaPos.dy, meccaPos.dx, meccaPos.dy - 12);
    domePath.close();

    canvas.drawPath(
      domePath, 
      Paint()
        ..color = const Color(0xFFD4AF37)
        ..style = PaintingStyle.fill
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

// 3. Pathway Line Painter for AR mode dynamic target tether
class PathwayLinePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final bool isAligned;

  PathwayLinePainter({
    required this.start,
    required this.end,
    required this.isAligned,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final gradient = ui.Gradient.linear(
      start,
      end,
      [
        const Color(0xFFD4AF37).withOpacity(0.0), // Fades out at screen bottom
        isAligned ? const Color(0xFFD4AF37) : const Color(0xFF81C784), // Becomes solid at Kaaba
      ],
    );

    paint.shader = gradient;
    canvas.drawLine(start, end, paint);

    // Dynamic blur/glow backdrop under the line
    final glowPaint = Paint()
      ..strokeWidth = 7.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..imageFilter = ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0);

    final glowGradient = ui.Gradient.linear(
      start,
      end,
      [
        const Color(0xFFD4AF37).withOpacity(0.0),
        (isAligned ? const Color(0xFFD4AF37) : const Color(0xFF81C784)).withOpacity(0.35),
      ],
    );
    glowPaint.shader = glowGradient;
    canvas.drawLine(start, end, glowPaint);
  }

  @override
  bool shouldRepaint(covariant PathwayLinePainter oldDelegate) {
    return oldDelegate.start != start ||
        oldDelegate.end != end ||
        oldDelegate.isAligned != isAligned;
  }
}
