# Pembaca Naskah (macOS)

Aplikasi native macOS (offline) untuk membaca naskah skenario PDF dengan cepat, dibangun menggunakan Swift + `PDFKit`.

## Fitur
- **100% Offline** — berjalan native di macOS (Apple Silicon / Intel) tanpa koneksi internet.
- **Daftar & Nomor Scene Otomatis** — mendeteksi nomor scene di margin kiri/kanan beserta heading (`INT.`, `EXT.`, `INT/EXT.`) dan melompat langsung ke posisi scene tersebut.
- **Cari Nomor / Nama Scene** — filter daftar scene secara instan di sidebar.
- **Select & Copy Teks (`Cmd+C`)** — teks skenario dapat dipilih dan disalin langsung.
- **Cari Teks di Naskah (`Cmd+F`)** — pencarian kata/dialog dengan highlight dan navigasi hasil (`▲` / `▼`).
- **Dark / Light Mode & Zoom** — nyaman dibaca di ruang gelap maupun terang.

## Cara Build dari Source (macOS)
Pastikan Xcode Command Line Tools terpasang, lalu jalankan:
```bash
./build.sh
```
Hasil build (`Pembaca Naskah.app` dan `Pembaca_Naskah.dmg`) akan tersedia di folder `build/`.

## Persetujuan Gatekeeper macOS
Lihat `PETUNJUK INSTALASI.txt` atau jalankan di Terminal setelah memindahkan aplikasi ke `/Applications`:
```bash
xattr -cr "/Applications/Pembaca Naskah.app"
```
