# MAB-Player

Pemutar multimedia lintas platform (Windows, macOS, Linux, Android) berbasis **Flutter** + **media_kit** (libmpv).
Open-source, tanpa layanan berbayar.

## Fitur Fase 1
- Tema gelap, tab **Music** / **Video** / **Library**
- Video: MP4, MKV, AVI, WebM, subtitle .srt/.vtt/.ass, kecepatan 0.5x-2.0x, pilihan aspect ratio, hardware acceleration, overlay auto-hide, layar penuh, lanjut dari posisi terakhir, bookmark
- Musik: MP3, WAV, FLAC, AAC, audio background + kontrol notifikasi (Android/macOS), antrean, shuffle, repeat, seek bar bergaya waveform
- Scan folder lokal, riwayat & bookmark tersimpan lokal

## Cara pasang (Windows, VS Code terminal)
```powershell
# 1. Aktifkan Developer Mode (wajib untuk plugin Flutter di Windows)
start ms-settings:developers

# 2. Dari folder proyek ini:
powershell -ExecutionPolicy Bypass -File .\setup.ps1

# 3. Jalankan
flutter run -d windows
```

Linux: `sudo apt install libmpv-dev mpv` sebelum menjalankan setup manual
(`flutter create`, `flutter pub add ...` seperti di `setup.ps1`).

## Build rilis
```powershell
flutter build windows --release
flutter build apk --release --split-per-abi
```

## Catatan
- Waveform masih dekoratif (belum diekstrak dari audio asli).
- Tag ID3 / cover album belum dibaca (fase berikutnya).
- Media key & overlay media sistem untuk Windows/Linux belum ada.
- Sebelum memilih LICENSE, cek lisensi binari libmpv/FFmpeg yang dibundel `media_kit_libs_video`.
