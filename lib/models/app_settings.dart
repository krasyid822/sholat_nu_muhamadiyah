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
  final double? gpsAltitude;
  final String? gpsLocationName;
  final bool useIhtiyati;
  final bool isDarkMode;
  final bool enableNotifications;
  final bool keepScreenOn;
  final int? _hijriOffset; // Manual calendar correction offset (-1, 0, +1 day)
  int get hijriOffset => _hijriOffset ?? 0;
  final String? isbatDateStr; // Gregorian date of Sidang Isbat, e.g. '2026-05-27'

  // ignore: prefer_initializing_formals
  const AppSettings({
    required this.calcMethod,
    required this.locationMode,
    required this.selectedCity,
    required this.customLatitude,
    required this.customLongitude,
    this.gpsLatitude,
    this.gpsLongitude,
    this.gpsAltitude,
    this.gpsLocationName,
    required this.useIhtiyati,
    required this.isDarkMode,
    required this.enableNotifications,
    required this.keepScreenOn,
    int? hijriOffset,
    this.isbatDateStr,
    // ignore: prefer_initializing_formals
  }) : _hijriOffset = hijriOffset;

  AppSettings copyWith({
    CalcMethod? calcMethod,
    LocationMode? locationMode,
    String? selectedCity,
    double? customLatitude,
    double? customLongitude,
    double? gpsLatitude,
    double? gpsLongitude,
    double? gpsAltitude,
    String? gpsLocationName,
    bool? useIhtiyati,
    bool? isDarkMode,
    bool? enableNotifications,
    bool? keepScreenOn,
    int? hijriOffset,
    String? isbatDateStr,
  }) {
    return AppSettings(
      calcMethod: calcMethod ?? this.calcMethod,
      locationMode: locationMode ?? this.locationMode,
      selectedCity: selectedCity ?? this.selectedCity,
      customLatitude: customLatitude ?? this.customLatitude,
      customLongitude: customLongitude ?? this.customLongitude,
      gpsLatitude: gpsLatitude ?? this.gpsLatitude,
      gpsLongitude: gpsLongitude ?? this.gpsLongitude,
      gpsAltitude: gpsAltitude ?? this.gpsAltitude,
      gpsLocationName: gpsLocationName ?? this.gpsLocationName,
      useIhtiyati: useIhtiyati ?? this.useIhtiyati,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      hijriOffset: hijriOffset ?? this.hijriOffset,
      isbatDateStr: isbatDateStr ?? this.isbatDateStr,
    );
  }

  // Initial default settings
  factory AppSettings.initial() {
    return const AppSettings(
      calcMethod: CalcMethod.kemenag,
      locationMode: LocationMode.gps,
      selectedCity: 'Jakarta',
      customLatitude: -6.2088,
      customLongitude: 106.8456,
      gpsLatitude: null,
      gpsLongitude: null,
      gpsAltitude: null,
      gpsLocationName: null,
      useIhtiyati: true,
      isDarkMode: true,
      enableNotifications: false,
      keepScreenOn: false,
      hijriOffset: 0,
      isbatDateStr: null,
    );
  }
}
