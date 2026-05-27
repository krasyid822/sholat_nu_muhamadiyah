// Hijri (Islamic) Calendar Converter
// Uses the Tabular Islamic Calendar algorithm (civil/standard variant).
// Accurate for computational purposes — actual Hijri dates may differ by
// 1-2 days depending on moon sighting authority (Kemenag, Muhammadiyah, etc.)

import '../models/app_settings.dart';

class HijriDate {
  final int year;
  final int month;
  final int day;

  const HijriDate({
    required this.year,
    required this.month,
    required this.day,
  });

  /// Full month names in Arabic/Indonesian
  static const List<String> monthNames = [
    'Muharram',
    'Safar',
    'Rabiul Awal',
    'Rabiul Akhir',
    'Jumadil Awal',
    'Jumadil Akhir',
    'Rajab',
    'Sya\'ban',
    'Ramadhan',
    'Syawal',
    'Dzulqadah',
    'Dzulhijjah',
  ];

  /// Short month names
  static const List<String> shortMonthNames = [
    'Muh',
    'Saf',
    'Rb1',
    'Rb2',
    'Jm1',
    'Jm2',
    'Raj',
    'Syb',
    'Ram',
    'Syw',
    'Dzq',
    'Dzh',
  ];

  String get monthName => monthNames[month - 1];
  String get shortMonthName => shortMonthNames[month - 1];

  String get formatted => '$day $monthName $year H';
  String get shortFormatted => '$day $shortMonthName $year';

  @override
  String toString() => formatted;

  /// Known Islamic holidays / important dates
  /// Returns null if the date is not a special day
  String? get islamicEvent {
    if (month == 1 && day == 1) return 'Tahun Baru Islam';
    if (month == 1 && day == 10) return 'Hari Asyura';
    if (month == 3 && day == 12) return 'Maulid Nabi ﷺ';
    if (month == 7 && day == 27) return 'Isra Mi\'raj';
    if (month == 8 && day == 15) return 'Nisfu Sya\'ban';
    if (month == 9 && day == 1) return 'Awal Ramadhan';
    if (month == 9 && day == 17) return 'Nuzulul Qur\'an';
    if (month == 10 && day == 1) return 'Idul Fitri';
    if (month == 10 && day == 2) return 'Idul Fitri (Hari 2)';
    if (month == 12 && day == 9) return 'Hari Arafah';
    if (month == 12 && day == 10) return 'Idul Adha';
    if (month == 12 && day == 11) return 'Hari Tasyrik';
    if (month == 12 && day == 12) return 'Hari Tasyrik';
    if (month == 12 && day == 13) return 'Hari Tasyrik';
    return null;
  }

  bool get isSpecialDay => islamicEvent != null;
}

class HijriConverter {
  /// Convert Gregorian date to Hijri date using the Tabular Islamic Calendar
  /// (Kuwaiti Algorithm — civil variant)
  /// Calculate the synodic age of the moon in days (0 to 29.53)
  static double getMoonAge(DateTime date) {
    // Reference New Moon: 2000-01-06 18:14:00 UTC
    final epoch = DateTime.utc(2000, 1, 6, 18, 14, 0);
    final diffInMs = date.toUtc().difference(epoch).inMilliseconds;
    final diffInDays = diffInMs / (1000 * 60 * 60 * 24);
    final lunations = diffInDays / 29.530588853;
    final fractional = lunations - lunations.floor();
    return fractional * 29.530588853;
  }

  /// Convert Gregorian date to Hijri date using the Tabular Islamic Calendar
  /// with automatic Fiqih-based adjustments (Kemenag MABIMS vs Muhammadiyah KHGT)
  /// and a manual day offset.
  static HijriDate fromGregorian(DateTime date, CalcMethod method, [int offset = 0, String? isbatDateStr]) {
    // 1. Get standard tabular Hijri date
    final standard = _fromGregorianTabular(date);

    // 2. Find the 1st day of this Hijri month in standard tabular (standard.day == 1)
    final firstDayOfHijriMonth = date.subtract(Duration(days: standard.day - 1));

    // 3. Get moon age at the start of this tabular month
    final double ageAtStart = getMoonAge(firstDayOfHijriMonth);

    int adjustment = 0;

    // General Conjunction Rule (for both Kemenag and Muhammadiyah)
    // If the moon is extremely old (conjunction not occurred yet), delay month start by 1 day
    if (ageAtStart > 29.0) {
      adjustment = -1;
    }

    // Kemenag MABIMS Rule
    if (method == CalcMethod.kemenag) {
      // Check the moon age at the proposed start day (after conjunction check)
      final DateTime checkDate = ageAtStart > 29.0 
          ? firstDayOfHijriMonth.add(const Duration(days: 1))
          : firstDayOfHijriMonth;
          
      final double checkAge = getMoonAge(checkDate);
      
      // Under Kemenag (MABIMS), if the moon age is < 0.35 days, it means at sunset on the observation day,
      // the moon height was too low (< 3 degrees), so Kemenag delays the month start by another 1 day.
      if (checkAge < 0.35) {
        adjustment -= 1;
      }
    }

    // Apply Sidang Isbat manual offset if the current date falls in the same Hijri month
    // as the user-selected Gregorian isbatDateStr.
    int activeOffset = 0;
    if (method == CalcMethod.kemenag && isbatDateStr != null && offset != 0) {
      try {
        final isbatDate = DateTime.parse(isbatDateStr);
        final isbatHijri = _fromGregorianTabular(isbatDate);
        if (standard.year == isbatHijri.year && standard.month == isbatHijri.month) {
          activeOffset = offset;
        }
      } catch (_) {}
    }

    if (adjustment != 0 || activeOffset != 0) {
      return _fromGregorianTabular(date.add(Duration(days: adjustment + activeOffset)));
    }

    return standard;
  }

  /// Convert Gregorian date to standard Tabular Hijri date
  /// (Kuwaiti Algorithm — civil variant)
  static HijriDate _fromGregorianTabular(DateTime date) {
    final int day = date.day;
    int month = date.month;
    int year = date.year;

    if (month < 3) {
      year -= 1;
      month += 12;
    }

    final int a = (year / 100).floor();
    int b = 2 - a + (a / 4).floor();
    if (year < 1583) b = 0;

    final int jd = (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        day +
        b -
        1524;

    const int epochastro = 1948084;
    final int z = jd - epochastro;
    final int cyc = (z / 10631).floor();
    final int zRem = z - 10631 * cyc;
    final int j = ((zRem - 8.01 / 60) / 354.36667).floor();
    final int iy = 30 * cyc + j;

    final int zRem2 = zRem - (j * 354.36667 + 8.5 / 30).floor();
    int im = ((zRem2 + 28.5001) / 29.5).floor();
    if (im == 13) im = 12;
    final int id = zRem2 - (im * 29.5 - 28.99).floor();

    return HijriDate(year: iy, month: im, day: id);
  }

  /// Convert Hijri date to Gregorian date
  static DateTime toGregorian(int hYear, int hMonth, int hDay) {
    final int jd = _hijriToJulian(hYear, hMonth, hDay);
    return _julianToGregorian(jd);
  }

  /// Get the number of days in a Hijri month
  static int daysInHijriMonth(int hYear, int hMonth) {
    if (hMonth == 12 && _isHijriLeapYear(hYear)) return 30;
    return (hMonth % 2 == 1) ? 30 : 29;
  }

  /// Check if a Hijri year is a leap year
  static bool _isHijriLeapYear(int year) {
    return ((11 * year + 14) % 30) < 11;
  }

  /// Convert Hijri date to Julian Day Number using the exact mathematical inverse
  /// of the fromGregorian Kuwaiti algorithm
  static int _hijriToJulian(int year, int month, int day) {
    final int cyc = (year / 30).floor();
    final int j = year % 30;
    final int zRem2 = day + (month * 29.5 - 28.99).floor();
    final int zRem = zRem2 + (j * 354.36667 + 8.5 / 30).floor();
    final int z = 10631 * cyc + zRem;
    return z + 1948084;
  }

  /// Convert Julian Day Number to Gregorian date
  static DateTime _julianToGregorian(int jd) {
    final int l = jd + 68569;
    final int n = ((4 * l) / 146097).floor();
    final int remainder = l - ((146097 * n + 3) / 4).floor();
    final int i = ((4000 * (remainder + 1)) / 1461001).floor();
    final int remainder2 = remainder - ((1461 * i) / 4).floor() + 31;
    final int j = ((80 * remainder2) / 2447).floor();
    final int day = remainder2 - ((2447 * j) / 80).floor();
    final int l2 = (j / 11).floor();
    final int month = j + 2 - 12 * l2;
    final int year = 100 * (n - 49) + i + l2;
    return DateTime(year, month, day);
  }
}
