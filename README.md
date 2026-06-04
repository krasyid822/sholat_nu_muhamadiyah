# sholat_nu_muhamadiyah

Flutter app jadwal sholat NU & Muhammadiyah.

## Desain Sistem & Skema Warna

Aplikasi Al-Waqt menggunakan skema warna tema gelap (*dark theme*) premium berikut:
*   **Latar Belakang Utama (Scaffold Background)**: `#05120C` (Hijau emerald sangat gelap mendekati hitam obsidian)
*   **Latar Belakang Kartu / Komponen (Surface Color)**: `#0C1913` (Hijau emerald gelap untuk kontras elevasi)
*   **Emas Islami (Primary Accent)**: `#D4AF37` (Digunakan untuk teks judul, ikon utama, dan border aktif)
*   **Hijau Emerald (Secondary Accent)**: `#0F5A3E` (Digunakan untuk detail sekunder)
*   **Teks Utama (Primary Text)**: `#FFFFFF` (Putih bersih)
*   **Teks Sekunder (Secondary Text)**: `rgba(255, 255, 255, 0.7)` (Putih dengan opasitas 70%) atau hijau emerald terang `#81C784`

Catatan: Firebase Web API key tetap bisa terlihat di bundle web saat app dipublish. Lindungi dari sisi Firebase/Google Cloud dengan API key restrictions, authorized domains, dan Firebase Security Rules.

## Cara Deploy
_(sebelumnya)_\
Lakukan:
```pwsh
git push # trigger ada disini
```
Lalu:
```pwsh
flutter build web --release
firebase deploy --only hosting
firebase deploy --only functions
```
_(sekarang)_\
cukup dengan
```pwsh
firebase deploy --only hosting
```
## Cara run ke ponsel
1. Connect ke usb debugging
2. flutter run -d web-server --web-port 8888
3. adb reverse tcp:8888 tcp:8888
4. Buka http://localhost:8888 di browser ponsel (Chromium)
5. Open url edge://inspect/#devices di desktop untuk Inspect (Sholat NU & Muhammadiyah
http://localhost:8888/)

## Hijri Calendar API

API ini memungkinkan webapp lain membaca hasil konversi kalender Hijriah presisi berdasarkan metode Kemenag (NU) & Muhammadiyah dari aplikasi ini.

### Endpoint URL
`https://us-central1-al-waqt-9cdb7.cloudfunctions.net/getHijriCalendar`

### Metode Request
Mendukung `GET` (Query parameter) dan `POST` (JSON Body).

### Parameter
*   `date` (string, opsional): Tanggal Masehi yang akan dikonversi (contoh: `2026-06-04`). Default: waktu sekarang.
*   `method` (string, opsional): Metode perhitungan fiqih, pilih `kemenag` atau `muhammadiyah`. Default: `kemenag`.
*   `offset` (number, opsional): Angka offset hari manual (contoh: `-1`, `1`). Default: `0`.
*   `isbatDate` (string, opsional): Tanggal Masehi spesifik untuk mengikat berlakunya offset manual pada satu bulan Hijriah terkait.

### Contoh Response (JSON)
```json
{
  "success": true,
  "gregorianDate": "2026-06-04T00:00:00.000Z",
  "hijri": {
    "year": 1447,
    "month": 12,
    "day": 18,
    "monthName": "Dzulhijjah",
    "shortMonthName": "Dzh",
    "formatted": "18 Dzulhijjah 1447 H",
    "islamicEvent": "Hari Tasyrik",
    "isSpecialDay": true
  },
  "params": {
    "method": "kemenag",
    "offset": 0,
    "isbatDate": null
  }
}
```

## Catatan
google adsense

### Done
jika pub busuk silahkan buat kode web native saja dan pastikan tambah “native activation button” di HTML yang 100% trusted gesture, lalu Flutter tinggal menampilkan status aktifnya.

ada masalah kompas tidak bisa diaktifkan kembali setelah pindah halaman