import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../models/app_settings.dart';

class GpsLoadingView extends ConsumerStatefulWidget {
  const GpsLoadingView({super.key});

  @override
  ConsumerState<GpsLoadingView> createState() => _GpsLoadingViewState();
}

class _GpsLoadingViewState extends ConsumerState<GpsLoadingView> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    const deepGreen = Color(0xFF0F5A3E);
    
    return Scaffold(
      backgroundColor: const Color(0xFF05120C), // Deep black-emerald canvas
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(30.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0C1913).withValues(alpha: 0.95),
                  const Color(0xFF05120C).withValues(alpha: 0.98),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: gold.withValues(alpha: 0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsing GPS Glowing Icon
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: deepGreen.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: gold.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: gold.withValues(alpha: 0.1),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: gold,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                
                // Loading Header Text
                Text(
                  'MENCARI LOKASI GPS',
                  style: GoogleFonts.outfit(
                    color: gold,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                
                // Loader Subtitle Info
                Text(
                  'Al-Waqt memerlukan koordinat GPS presisi untuk menghitung waktu sholat, arah kiblat, dan visibilitas hilal secara akurat di titik lokasi Anda berada.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.6,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Linear Progress Indicator
                Container(
                  width: 180,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                  child: const ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    child: LinearProgressIndicator(
                      color: gold,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Helper timeout text
                Text(
                  'Mencari sinyal satelit... (Maksimum 10 detik)',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // Quick Bypass Button
                ElevatedButton(
                  onPressed: () {
                    // Set location mode to preset (which defaults to Jakarta) to instantly bypass GPS wait
                    ref.read(settingsProvider.notifier).setLocationMode(LocationMode.preset);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold.withValues(alpha: 0.1),
                    foregroundColor: const Color(0xFFE6C575),
                    side: const BorderSide(color: gold, width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.skip_next_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Lewati & Gunakan Jakarta',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
