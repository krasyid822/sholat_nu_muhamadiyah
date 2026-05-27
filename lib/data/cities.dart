class CityData {
  final String name;
  final double latitude;
  final double longitude;
  final double timezone; // GMT offset

  const CityData({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.timezone,
  });
}

const List<CityData> presetCities = [
  CityData(name: 'Jakarta', latitude: -6.2088, longitude: 106.8456, timezone: 7.0),
  CityData(name: 'Yogyakarta', latitude: -7.7956, longitude: 110.3695, timezone: 7.0),
  CityData(name: 'Surabaya', latitude: -7.2575, longitude: 112.7521, timezone: 7.0),
  CityData(name: 'Bandung', latitude: -6.9175, longitude: 107.6191, timezone: 7.0),
  CityData(name: 'Medan', latitude: 3.5952, longitude: 98.6722, timezone: 7.0),
  CityData(name: 'Banda Aceh', latitude: 5.5483, longitude: 95.3238, timezone: 7.0),
  CityData(name: 'Makassar', latitude: -5.1477, longitude: 119.4327, timezone: 8.0),
  CityData(name: 'Banjarmasin', latitude: -3.3186, longitude: 114.5944, timezone: 8.0),
  CityData(name: 'Jayapura', latitude: -2.5489, longitude: 140.7186, timezone: 9.0),
];
