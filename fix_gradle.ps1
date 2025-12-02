# Apri Notepad o un editor di testo
# Salva come: C:\jamsetgemini\fix_gradle.ps1

# Copia questo contenuto:
@'
# fix_gradle.ps1
Write-Host "=== FIX GRADLE PER JAMSETGEMINI ===" -ForegroundColor Cyan
Write-Host "Cartella: $PWD" -ForegroundColor Yellow

# 1. Vai nella cartella android
Set-Location "android"
Write-Host "`n1. Nella cartella android..." -ForegroundColor Green

# 2. Lista file esistenti
Write-Host "`n2. File esistenti:" -ForegroundColor Yellow
Get-ChildItem -Path . -Filter "*.gradle*" -File | Format-Table Name

# 3. Elimina file problematici
Write-Host "`n3. Eliminazione file .gradle (non .kts)..." -ForegroundColor Red
$oldFiles = @("build.gradle", "settings.gradle")
foreach ($file in $oldFiles) {
    if (Test-Path $file) {
        Remove-Item -Path $file -Force
        Write-Host "   ELIMINATO: $file" -ForegroundColor Red
    }
}

# 4. Crea build.gradle.kts minimale
Write-Host "`n4. Creazione build.gradle.kts..." -ForegroundColor Green
@'
// Build file minimale
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
'@ | Out-File -FilePath "build.gradle.kts" -Encoding UTF8
Write-Host "   Creato: build.gradle.kts" -ForegroundColor Green

# 5. Crea settings.gradle.kts minimale
Write-Host "`n5. Creazione settings.gradle.kts..." -ForegroundColor Green
@'
// Settings minimale
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "jamset"
include(":app")
'@ | Out-File -FilePath "settings.gradle.kts" -Encoding UTF8
Write-Host "   Creato: settings.gradle.kts" -ForegroundColor Green

# 6. Controlla app/build.gradle.kts
Write-Host "`n6. Controllo app/build.gradle.kts..." -ForegroundColor Yellow
if (-not (Test-Path "app\build.gradle.kts")) {
    Write-Host "   File mancante! Creazione versione base..." -ForegroundColor Red
    @'
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.jamset"
    compileSdk = 34

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.jamset"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
        }
    }
}

flutter {
    source = "../.."
}
'@ | Out-File -FilePath "app\build.gradle.kts" -Encoding UTF8
    Write-Host "   Creato: app/build.gradle.kts" -ForegroundColor Green
} else {
    Write-Host "   OK: app/build.gradle.kts esiste" -ForegroundColor Green
}

# 7. Torna alla root
Set-Location ".."
Write-Host "`n7. Tornato a: $PWD" -ForegroundColor Yellow

# 8. Flutter clean
Write-Host "`n8. Esecuzione flutter clean..." -ForegroundColor Cyan
flutter clean
Write-Host "   Esecuzione flutter pub get..." -ForegroundColor Cyan
flutter pub get

# 9. Prova build
Write-Host "`n9. Prova build APK..." -ForegroundColor Green
Write-Host "   Comando: flutter build apk --debug" -ForegroundColor White
flutter build apk --debug

Write-Host "`n=== FIX COMPLETATO ===" -ForegroundColor Cyan
Write-Host "Se ci sono errori, esegui:" -ForegroundColor Yellow
Write-Host "flutter doctor -v" -ForegroundColor White
Write-Host "flutter clean" -ForegroundColor White
Write-Host "flutter pub get" -ForegroundColor White
'@ | Out-File -FilePath "C:\jamsetgemini\fix_gradle.ps1" -Encoding UTF8