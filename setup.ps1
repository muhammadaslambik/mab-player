# MAB-Player - setup otomatis (Windows PowerShell)
# Jalankan dari dalam folder proyek:
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding $false

function Step($t) { Write-Host "`n==> $t" -ForegroundColor Cyan }
function Check($what) { if ($LASTEXITCODE -ne 0) { throw "Gagal: $what" } }

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter belum ada di PATH. Pasang Flutter SDK dulu: https://docs.flutter.dev/get-started/install"
}

# 1. Generate folder platform tanpa menimpa kode di lib/
Step "Membuat project Flutter (windows, macos, linux, android)"
if (Test-Path lib_src) { Remove-Item lib_src -Recurse -Force }
Rename-Item lib lib_src
flutter create . --org com.muhammadaslambik --project-name mab_player --platforms=windows,macos,linux,android
Check "flutter create"
if (Test-Path lib) { Remove-Item lib -Recurse -Force }
Rename-Item lib_src lib
if (Test-Path test\widget_test.dart) { Remove-Item test\widget_test.dart -Force }

# 2. Dependensi
Step "Memasang dependensi"
flutter pub add media_kit media_kit_video media_kit_libs_video
Check "pub add media_kit"
flutter pub add audio_service flutter_riverpod file_picker path_provider path permission_handler window_manager wakelock_plus
Check "pub add lainnya"

# 3. Patch Android (izin, service notifikasi, MainActivity)
Step "Menyiapkan Android"
$manifestPath = "android\app\src\main\AndroidManifest.xml"
if (Test-Path $manifestPath) {
  $m = Get-Content $manifestPath -Raw
  if ($m -notmatch 'com.ryanheise.audioservice') {
    $perms = @'

    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
'@
    $service = @'

        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService"/>
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON"/>
            </intent-filter>
        </receiver>
'@
    if ($m -notmatch 'xmlns:tools') {
      $m = $m -replace '<manifest ', '<manifest xmlns:tools="http://schemas.android.com/tools" '
    }
    $m = $m -replace '(<manifest[^>]*>)', ('$1' + $perms)
    $m = $m -replace '</application>', ($service + "`n    </application>")
    [System.IO.File]::WriteAllText((Resolve-Path $manifestPath), $m, $utf8)
  }
}
$activityDir = "android\app\src\main\kotlin\com\muhammadaslambik\mab_player"
if (Test-Path $activityDir) {
  $kt = @'
package com.muhammadaslambik.mab_player

import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity()
'@
  [System.IO.File]::WriteAllText((Join-Path (Resolve-Path $activityDir) 'MainActivity.kt'), $kt, $utf8)
}

# 4. Patch macOS (izin baca file pilihan pengguna)
Step "Menyiapkan macOS"
foreach ($f in 'macos\Runner\DebugProfile.entitlements', 'macos\Runner\Release.entitlements') {
  if (Test-Path $f) {
    $e = Get-Content $f -Raw
    if ($e -notmatch 'files.user-selected.read-only') {
      $e = $e -replace '</dict>\s*</plist>', "`t<key>com.apple.security.files.user-selected.read-only</key>`n`t<true/>`n</dict>`n</plist>"
      [System.IO.File]::WriteAllText((Resolve-Path $f), $e, $utf8)
    }
  }
}

# 5. Selesai
Step "flutter pub get"
flutter pub get
Check "pub get"

Write-Host "`nSelesai! Jalankan salah satu:" -ForegroundColor Green
Write-Host "  flutter run -d windows"
Write-Host "  flutter run -d <id-perangkat-android>   (cek dengan: flutter devices)"
Write-Host "Cek kode: flutter analyze"
