# sholat_nu_muhamadiyah
Flutter app jadwal sholat NU & Muhammadiyah.
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

## Catatan
- Jika pub busuk silahkan buat kode web native saja dan pastikan tambah “native activation button” di HTML yang 100% trusted gesture, lalu Flutter tinggal menampilkan status aktifnya.

## Mendatang
- Tambahkan halaman khusus untuk Google AdSense
