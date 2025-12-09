# Build Commands Reference

This guide provides all the commands needed to run and build the LastQuakes app in both FOSS and Production flavors.

---

## 📱 Development (Run on Device/Emulator)

### FOSS Flavor
```bash
# Run in debug mode
flutter run --flavor foss -t lib/main.dart

# Run in release mode
flutter run --release --flavor foss -t lib/main.dart
```

### Production Flavor
```bash
# Run in debug mode
flutter run --flavor prod -t lib/main_prod.dart

# Run in release mode
flutter run --release --flavor prod -t lib/main_prod.dart
```

---

## 🏗️ Production Builds

### FOSS Flavor

#### Using Build Script (Recommended)
```powershell
# Build APK
.\scripts\build_foss.ps1 -BuildType apk

# Build App Bundle
.\scripts\build_foss.ps1 -BuildType appbundle

# Build both APK and App Bundle
.\scripts\build_foss.ps1 -BuildType both

# Build with auto-increment build number
.\scripts\build_foss.ps1 -IncrementBuild -BuildType apk
```

#### Manual Commands
```bash
# Build APK
flutter build apk --release --flavor foss -t lib/main.dart

# Build App Bundle
flutter build appbundle --release --flavor foss -t lib/main.dart

# Build split APKs per ABI (smaller files)
flutter build apk --release --flavor foss -t lib/main.dart --split-per-abi
```

### Production Flavor

#### Using Build Script (Recommended)
```powershell
# Build APK
.\scripts\build_prod.ps1 -BuildType apk

# Build App Bundle (for Play Store)
.\scripts\build_prod.ps1 -BuildType appbundle

# Build both APK and App Bundle
.\scripts\build_prod.ps1 -BuildType both

# Build with auto-increment build number
.\scripts\build_prod.ps1 -IncrementBuild -BuildType apk
```

#### Manual Commands
```bash
# Build APK
flutter build apk --release --flavor prod -t lib/main_prod.dart

# Build App Bundle (for Google Play Store)
flutter build appbundle --release --flavor prod -t lib/main_prod.dart

# Build split APKs per ABI
flutter build apk --release --flavor prod -t lib/main_prod.dart --split-per-abi
```

---

## 📦 Output Locations

### FOSS Builds
- **APK**: `build/app/outputs/flutter-apk/LastQuakes-FOSS-*.apk`
- **Split APKs**: `build/app/outputs/flutter-apk/app-foss-release-*.apk`
- **App Bundle**: `build/app/outputs/bundle/fossRelease/app-foss-release.aab`

### Production Builds
- **APK**: `build/app/outputs/flutter-apk/LastQuakes-*.apk`
- **Split APKs**: `build/app/outputs/flutter-apk/app-prod-release-*.apk`
- **App Bundle**: `build/app/outputs/bundle/prodRelease/app-prod-release.aab`

---

## 🛠️ Utility Commands

### Project Setup
```bash
# Get dependencies
flutter pub get

# Clean build artifacts
flutter clean

# Clean and get dependencies
flutter clean && flutter pub get

# Generate app icons
flutter pub run flutter_launcher_icons

# Generate splash screen
flutter pub run flutter_native_splash:create
```

### Build Number Management
```bash
# Increment build number
dart run scripts/increment_build_number.dart

# Check current version
grep "version:" pubspec.yaml
```

### Code Quality
```bash
# Analyze all code
flutter analyze

# Analyze specific files
flutter analyze lib/services/analytics_service_firebase.dart

# Format code
dart format lib/

# Run all tests
flutter test

# Run specific test
flutter test test/unit/earthquake_test.dart
```

### Device Management
```bash
# List connected devices
flutter devices

# Install APK on connected device
adb install build/app/outputs/flutter-apk/[apk-file].apk

# Install with replacement
adb install -r build/app/outputs/flutter-apk/[apk-file].apk

# Check installed packages
adb shell pm list packages | grep lastquakes

# Uninstall FOSS version
adb uninstall app.lastquakes.foss

# Uninstall Production version
adb uninstall app.lastquakes

# View logcat for app
adb logcat | grep -i lastquakes
```

### Certificate & Security
```bash
# Extract certificate pins
dart run scripts/get_certificate_pins.dart

# Get backup pins
dart run scripts/get_backup_pins.dart

# Monitor certificates
dart run scripts/monitor_certificates.dart
```

---

## 🔄 Build Comparison

| Aspect | FOSS | Production |
|--------|------|------------|
| **Entry Point** | `lib/main.dart` | `lib/main_prod.dart` |
| **Flavor Flag** | `--flavor foss` | `--flavor prod` |
| **Package ID** | `app.lastquakes.foss` | `app.lastquakes` |
| **App Name** | "LastQuakes FOSS" | "LastQuakes" |
| **Firebase** | ❌ Not included | ✅ Included |
| **Analytics** | ❌ Disabled | ✅ Enabled |
| **Push Notifications** | ❌ Disabled | ✅ Enabled |
| **Crashlytics** | ❌ Disabled | ✅ Enabled |
| **Distribution** | F-Droid | Google Play Store |
| **ProGuard Rules** | `proguard-rules-foss.pro` | `proguard-rules.pro` |

---

## 🌐 Web Build

```bash
# Build web version (FOSS by default)
flutter build web --release

# Build with base href
flutter build web --release --base-href /lastquakes/

# Run web locally
flutter run -d chrome

# Output location
build/web/
```

---

## 🍎 iOS Build (if configured)

```bash
# Build iOS (Production flavor)
flutter build ios --release --flavor prod -t lib/main_prod.dart

# Build iOS (FOSS flavor)
flutter build ios --release --flavor foss -t lib/main.dart
```

---

## 🐧 Linux Build (if configured)

```bash
# Build Linux
flutter build linux --release
```

---

## 🪟 Windows Build (if configured)

```bash
# Build Windows
flutter build windows --release
```

---

## 🔍 Debugging

### Run with Verbose Output
```bash
# FOSS with verbose logging
flutter run --flavor foss -t lib/main.dart -v

# Production with verbose logging
flutter run --flavor prod -t lib/main_prod.dart -v
```

### Profile Mode
```bash
# FOSS profile build
flutter run --profile --flavor foss -t lib/main.dart

# Production profile build
flutter run --profile --flavor prod -t lib/main_prod.dart
```

### Build with Verbose Output
```bash
flutter build apk --release --flavor prod -t lib/main_prod.dart -v
```

---

## 📝 Common Workflows

### First Time Setup
```bash
# Clone and setup
git clone <repository-url>
cd lastquakes
flutter pub get
flutter pub run flutter_launcher_icons
flutter pub run flutter_native_splash:create
```

### Daily Development (FOSS)
```bash
flutter run --flavor foss -t lib/main.dart
```

### Daily Development (Production)
```bash
flutter run --flavor prod -t lib/main_prod.dart
```

### Pre-Release Build (FOSS for F-Droid)
```bash
flutter clean
flutter pub get
.\scripts\build_foss.ps1 -IncrementBuild -BuildType apk
```

### Pre-Release Build (Production for Play Store)
```bash
flutter clean
flutter pub get
.\scripts\build_prod.ps1 -IncrementBuild -BuildType appbundle
```

### Quick Test Build
```bash
# FOSS
flutter build apk --flavor foss -t lib/main.dart

# Production
flutter build apk --flavor prod -t lib/main_prod.dart
```

---

## ⚠️ Important Notes

### Before Building Production
1. Ensure `android/app/src/prod/google-services.json` exists
2. Configure Firebase project (see `readme files/FIREBASE_SETUP.md`)
3. Update `.env` file with `SERVER_URL` if using backend
4. Verify certificate pinning configuration for production

### Before Building FOSS
1. No Firebase configuration needed
2. No backend configuration required
3. All proprietary services are automatically excluded

### Signing Configuration
- Signing configuration is in `android/key.properties`
- Required for release builds
- See `readme files/build.md` for signing setup

---

## 🆘 Troubleshooting

### Build Fails with "google-services.json not found"
```bash
# Ensure file exists at:
android/app/src/prod/google-services.json

# Or build FOSS flavor instead:
flutter build apk --release --flavor foss -t lib/main.dart
```

### "Duplicate class found" Error
```bash
flutter clean
flutter pub get
# Then rebuild
```

### APK Not Installing
```bash
# Uninstall existing version first
adb uninstall app.lastquakes       # Production
adb uninstall app.lastquakes.foss  # FOSS

# Then install new version
adb install -r build/app/outputs/flutter-apk/[apk-file].apk
```

### Gradle Build Fails
```bash
# Navigate to android directory
cd android

# Clean gradle
.\gradlew clean

# Back to root and rebuild
cd ..
flutter clean
flutter pub get
```

---

## 📚 Additional Resources

- **Main Documentation**: `README.md`
- **Firebase Setup**: `readme files/FIREBASE_SETUP.md`
- **Build Configuration**: `readme files/build.md`
- **Quick Start**: `readme files/QUICK_START.md`
- **Implementation Details**: `readme files/FIREBASE_IMPLEMENTATION_SUMMARY.md`
