# Build Commands Reference

This guide provides all the commands needed to run and build the LastQuakes FOSS app.

---

## 📱 Development (Run on Device/Emulator)

```bash
# Run in debug mode
flutter run

# Run in release mode
flutter run --release
```

---

## 🏗️ Production Builds

### Using Build Script (Recommended)

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

### Manual Commands

```bash
# Build APK
flutter build apk --release

# Build App Bundle
flutter build appbundle --release

# Build split APKs per ABI (smaller files)
flutter build apk --release --split-per-abi
```

---

## 📦 Output Locations

- **APK**: `build/app/outputs/flutter-apk/app-release.apk`
- **Split APKs**: `build/app/outputs/flutter-apk/app-*-release.apk`
- **App Bundle**: `build/app/outputs/bundle/release/app-release.aab`

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

# List emulators
flutter emulators

# Launch specific emulator
flutter emulators --launch <emulator_id>
```

### Build Info

```bash
# Check Flutter version
flutter --version

# Check installed SDKs
flutter doctor -v

# Show APK analysis
flutter build apk --release --analyze-size
```

---

## 📋 Common Workflows

### First Time Setup

```bash
# 1. Clone the repository
git clone https://github.com/1arunjyoti/lastquakes.git
cd lastquakes

# 2. Get dependencies
flutter pub get

# 3. Run on device
flutter run
```

### Daily Development

```bash
# 1. Update dependencies
flutter pub get

# 2. Run app
flutter run

# 3. Hot reload (press 'r' in terminal)
# 4. Hot restart (press 'R' in terminal)
```

### Release Build

```bash
# 1. Clean previous build
flutter clean

# 2. Get dependencies
flutter pub get

# 3. Build release APK
.\scripts\build_foss.ps1 -BuildType apk
```

### Testing Workflow

```bash
# 1. Run all tests
flutter test

# 2. Run tests with coverage
flutter test --coverage

# 3. Analyze code
flutter analyze

# 4. Format code
dart format lib/ test/
```

---

## 🔍 Advanced Commands

### Profiling & Debugging

```bash
# Run with verbose logging
flutter run -v

# Run in profile mode (for performance testing)
flutter run --profile

# Build with detailed output
flutter build apk --release -v

# Check build size analysis
flutter build apk --release --analyze-size
```

### Dependency Management

```bash
# Check for outdated packages
flutter pub outdated

# Upgrade dependencies
flutter pub upgrade

# Get specific package version
flutter pub add package_name:^1.0.0
```

---

## 📱 APK Installation

### Install on Connected Device

```bash
# Install debug APK
flutter install

# Install specific APK
adb install build/app/outputs/flutter-apk/app-release.apk

# Install and launch
adb install -r build/app/outputs/flutter-apk/app-release.apk && adb shell am start -n app.lastquakes.foss/.MainActivity
```

### Uninstall

```bash
# Uninstall FOSS version
adb uninstall app.lastquakes.foss
```

---

## 🌐 Web Build (Experimental)

```bash
# Build web version
flutter build web --release

# Serve locally for testing
python -m http.server -d build/web 8000
```

---

## 📝 Notes

- **Package ID**: `app.lastquakes.foss`
- **App Name**: LastQuakes FOSS
- **Distribution**: F-Droid
- **Min SDK**: 21 (Android 5.0)
- **Target SDK**: Latest stable

---

## 🆘 Troubleshooting

### Build Fails

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --release
```

### Gradle Issues

```bash
# Clean Gradle cache
cd android
./gradlew clean
cd ..
flutter clean
```

### Plugin Issues

```bash
# Upgrade Flutter
flutter upgrade

# Repair pub cache
flutter pub cache repair
```

---

## 📚 Additional Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [F-Droid Inclusion Guide](https://f-droid.org/en/docs/Inclusion_Policy/)
- [Android Signing Guide](https://docs.flutter.dev/deployment/android#signing-the-app)
