# sholat_nu_muhamadiyah

Flutter app jadwal sholat NU & Muhammadiyah.

## Widget

Pembaruan ini telah dideploy dan dapat diakses secara live di: 👉 https://al-waqt-9cdb7.web.app/widget.html

Cara memasangnya ke Launcher Android Anda:
1. Buka Google Play Store di Android Anda, cari dan instal aplikasi "Web Widget" (oleh anod atau aplikasi serupa seperti WidgetsWeb).
2. Tambahkan widget baru dari aplikasi tersebut ke layar beranda (launcher) HP Anda.
3. Masukkan URL widget: https://al-waqt-9cdb7.web.app/widget.html
4. Atur interval penyegaran (refresh interval) di pengaturan widget tersebut agar selalu menyegarkan waktu (misalnya setiap beberapa detik/menit) dan setel ukuran grid-nya agar pas di beranda.

### Solusi: Melewati Sandbox Lewat Parameter URL
Untuk mengatasi batasan sandbox WebView ini, kami telah memperbarui kode agar widget.html dapat menerima koordinat lokasi, metode hisab, dan status ihtiyati langsung via URL Query Parameters sebagai prioritas utama.

Sekarang Anda bisa memasukkan URL yang sudah terisi pengaturan ke dalam aplikasi Web Widget Anda:

text
https://al-waqt-9cdb7.web.app/widget.html?lat=[LATITUDE]&lng=[LONGITUDE]&city=[NAMA_KOTA]&method=[METODE]&ihtiyati=[true/false]&rt=[KOLOM,BARIS]
Parameter yang Didukung:
lat & lng: Garis lintang & bujur lokasi Anda (misal: lat=-6.2088&lng=106.8456).
city / name: Nama kota yang ingin ditampilkan di widget (misal: city=Jakarta).
method: Metode Hisab (0 untuk Kemenag/NU, 1 untuk Muhammadiyah).
ihtiyati: Koreksi waktu pengaman (true untuk +2 menit, false untuk normal).
rt: Ukuran kotak sel widget launcher (4,1 untuk flat memanjang, 3,2 atau 4,2 untuk vertikal/kotak).
Contoh URL untuk dimasukkan ke Web Widget Anda:
Contoh 4x1 (Flat Horizontal - Jakarta, Kemenag + Ihtiyati): https://al-waqt-9cdb7.web.app/widget.html?lat=-6.2088&lng=106.8456&city=Jakarta&method=0&ihtiyati=true&rt=4,1
Contoh 3x2 (Kotak/Vertikal - Yogyakarta, Muhammadiyah): https://al-waqt-9cdb7.web.app/widget.html?lat=-7.7971&lng=110.3705&city=Yogyakarta&method=1&ihtiyati=true&rt=3,2

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

### Done
jika pub busuk silahkan buat kode web native saja dan pastikan tambah “native activation button” di HTML yang 100% trusted gesture, lalu Flutter tinggal menampilkan status aktifnya.

ada masalah kompas tidak bisa diaktifkan kembali setelah pindah halaman

google adsense

## Catatan

buat widget otomatis adaptif mengikuti ukuran widget launcher android

preset 4x2

tambahkan mekanisme untuk meminta izin lokasi presisi di widget.html agar bisa mendapatkan lokasi tanpa perlu membuka url utama aplikasi

cegah widget melar, buat sudutnya tetap tajam saja jangan ada efek rounded