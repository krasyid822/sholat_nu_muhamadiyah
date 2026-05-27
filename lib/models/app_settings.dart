enum CalcMethod {
  kemenag, // Kemenag RI (NU) - Shubuh -20 degrees
  muhammadiyah // Muhammadiyah - Shubuh -18 degrees
}

enum LocationMode {
  preset,
  custom,
  gps
}

class AppSettings {
  final CalcMethod calcMethod;
  final LocationMode locationMode;
  final String selectedCity;
  final double customLatitude;
  final double customLongitude;
  final double? gpsLatitude;
  final double? gpsLongitude;
  final bool useIhtiyati;
  final bool isDarkMode;

  const AppSettings({
    required this.calcMethod,
    required this.locationMode,
    required this.selectedCity,
    required this.customLatitude,
    required this.customLongitude,
    this.gpsLatitude,
    this.gpsLongitude,
    required this.useIhtiyati,
    required this.isDarkMode,
  });

  AppSettings copyWith({
    CalcMethod? calcMethod,
    LocationMode? locationMode,
    String? selectedCity,
    double? customLatitude,
    double? customLongitude,
    double? gpsLatitude,
    double? gpsLongitude,
    bool? useIhtiyati,
    bool? isDarkMode,
  }) {
    return AppSettings(
      calcMethod: calcMethod ?? this.calcMethod,
      locationMode: locationMode ?? this.locationMode,
      selectedCity: selectedCity ?? this.selectedCity,
      customLatitude: customLatitude ?? this.customLatitude,
      customLongitude: customLongitude ?? this.customLongitude,
      gpsLatitude: gpsLatitude ?? this.gpsLatitude,
      gpsLongitude: gpsLongitude ?? this.gpsLongitude,
      useIhtiyati: useIhtiyati ?? this.useIhtiyati,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }

  // Initial default settings
  factory AppSettings.initial() {
    return const AppSettings(
      calcMethod: CalcMethod.kemenag,
      locationMode: LocationMode.preset,
      selectedCity: 'Jakarta',
      customLatitude: -6.2088,
      customLongitude: 106.8456,
      gpsLatitude: null,
      gpsLongitude: null,
      useIhtiyati: true,
      isDarkMode: true,
    );
  }
}
