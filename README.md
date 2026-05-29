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

## Catatan
google adsense

jika pub busuk silahkan buat kode web native saja dan pastikan tambah “native activation button” di HTML yang 100% trusted gesture, lalu Flutter tinggal menampilkan status aktifnya.

ada masalah kompas tidak bisa diaktifkan kembali setelah pindah halaman