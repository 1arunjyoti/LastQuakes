# LastQuakes - Global Earthquake Monitor 🌍

A comprehensive Flutter application providing real-time global earthquake monitoring with multi-source data integration, customizable push notifications, interactive map visualization, and advanced filtering capabilities. Built with clean architecture principles and optimized for performance across mobile, web, and desktop platforms.

---

## 📱 Screenshots

<img src="graphics\screenshots\home_screen.png" width="200" height="400">, <img src="graphics\screenshots\details_screen.png" width="200" height="400">, <img src="graphics\screenshots\map_screen.png" width="200" height="400">, <img src="graphics\screenshots\settings_screen.png" width="200" height="400">, <img src="graphics\screenshots\stats_screen.png" width="200" height="400">, <img src="graphics\screenshots\web_dashboard.png">

---

## ✨ Core Features

### 📡 Multi-Source Data Integration

- **USGS (U.S. Geological Survey)**: Comprehensive global earthquake data with detailed seismic information
- **EMSC (European-Mediterranean Seismological Centre)**: Enhanced coverage for European and Mediterranean regions
- **Source Selection**: Users can enable/disable data sources based on preferences
- **Intelligent Deduplication**: Automatic removal of duplicate events from multiple sources using spatial-temporal correlation
- **Optimized Caching**: Hive-based local storage with configurable TTL for offline access and performance

### 🗺️ Interactive Map Visualization

- **flutter_map Integration**: High-performance map rendering with smooth panning and zooming
- **Multiple Base Layers**:
  - Street Map (OpenStreetMap)
  - Satellite Imagery
  - Terrain View
  - Dark Theme
- **Magnitude-Based Markers**: Color-coded markers with size scaling based on earthquake magnitude
- **Marker Clustering**: Automatic clustering of nearby events for better visualization at different zoom levels
- **Fault Line Overlays**: Optional tectonic plate boundary visualization
- **Real-Time Filtering**: Filter by magnitude, time window, and distance without reloading data
- **Responsive Design**: Optimized layouts for mobile, tablet, and desktop screens

### 📋 Dynamic List View

- **Client-Side Filtering**:
  - Filter by magnitude threshold
  - Filter by country/region
  - Distance-based filtering with unit preferences (km/mi)
- **Distance Calculation**: Haversine formula for accurate distance from user's location
- **Sorting Options**: Sort by time, magnitude, or distance
- **Modern UI**: Card-based design with gradient headers and comprehensive event information
- **Performance Optimized**: Lazy loading with efficient list rendering

### 📊 Detailed Event Analysis

- **Comprehensive Information**:
  - Magnitude, depth, and location coordinates
  - Tsunami warning status
  - Distance from user's location
  - Source attribution (USGS/EMSC)
  - Link to detailed reports
- **Interactive Map**: Pinpoint event location with surrounding context
- **Share Functionality**: Share event details via social media or messaging apps
- **Screenshot Capability**: Capture and share event information

### 🔔 Customizable Push Notifications (Production Flavor Only)

- **Firebase Cloud Messaging (FCM)**: Reliable push notification delivery
- **Backend Integration**: Dedicated Node.js backend service for notification processing
- **Filter Types**:
  - **None**: Disable all notifications
  - **Worldwide**: Receive alerts for all earthquakes above magnitude threshold
  - **By Country**: Targeted alerts for specific countries/regions
  - **By Distance**: Radius-based alerts from current location or safe zones
- **Safe Zones**: Configure multiple locations (home, office, family) for distance-based alerts
- **Current Location**: Dynamic alerts based on real-time GPS position
- **Customizable Magnitude**: Set minimum magnitude threshold (3.0-9.0)
- **Adjustable Radius**: Configure alert radius (100km - 5000km)

### ⚙️ User Preferences

- **Theme Settings**:
  - Light Mode
  - Dark Mode
  - System Default (follows device settings)
- **Unit Preferences**:
  - Distance: Kilometers or Miles
- **Time Format**: 12-hour or 24-hour display
- **Data Source Selection**: Enable/disable USGS and EMSC
- **Notification Configuration**: Comprehensive notification settings with permission management
- **Persistent Storage**: Settings synchronized across devices via backend

### 📈 Statistics & Analytics

- **Earthquake Statistics**: Visual representation of seismic activity trends
- **Magnitude Distribution**: Charts and graphs for data analysis
- **Geographic Distribution**: Breakdown by region and country
- **Time-Based Analysis**: Hourly, daily, and weekly activity patterns

### Home Screen Widget

- **Home Screen Widget**: Add widget to home screen to display latest earthquakes

### 🔒 Security Features

- **Certificate Pinning**: Secure HTTPS communication with SSL/TLS pinning
- **Encrypted Storage**: AES-256 encryption for sensitive data using `flutter_secure_storage`
- **Secure Token Management**: Encrypted FCM token storage and rotation
- **Token Migration**: Automatic migration from legacy storage to encrypted storage
- **Secure Logging**: Production-ready logging with sensitive data masking

### 🌐 Cross-Platform Support

- **Android**: Full feature support with native optimizations
- **Web**: Responsive web application with desktop-optimized layouts
- **Desktop (Planned)**: Future support for Windows, macOS, and Linux

## 🔄 Build Variants

The application supports two build variants: FOSS (Free and Open Source Software) and Production (Prod), with the following key differences:

### App Identity

- **FOSS**: App name is "LastQuakes FOSS", package ID has `.foss` suffix
- **Prod**: App name is "LastQuakes", standard package ID

### Firebase Integration

- **FOSS**: Excludes Google Play Services and Firebase classes entirely from the APK (verified in CI/CD)
- **Prod**: Includes Firebase dependencies for analytics, crash reporting, and push notifications

### Features

- **FOSS**: Push notifications and analytics are disabled (UI hides notification settings)
- **Prod**: Full Firebase-powered push notifications and analytics (Requires Firebase credentials and backend service deployment for push notifications)

### Build Configuration

- **FOSS**: Uses `android/app/proguard-rules-foss.pro` to strip Firebase/GMS classes and ignore missing dependencies
- **Prod**: Standard ProGuard rules that preserve Firebase functionality

### Distribution

- **FOSS**: Designed for F-Droid and other open-source app stores
- **Prod**: For Google Play Store with full Google services integration

---

## 🏗️ Architecture

The application follows **Clean Architecture** principles with clear separation of concerns:

```
lib/
├── main.dart                          # FOSS flavor entry point & initialization
├── main_prod.dart                     # Production flavor entry point (with Firebase)
│
├── data/                              # Data Layer
│   └── repositories/                  # Repository implementations
│       ├── earthquake_repository_impl.dart
│       ├── settings_repository_impl.dart
│       ├── device_repository_impl.dart
│       └── device_repository_noop.dart  # No-op implementation for FOSS
│
├── domain/                            # Domain Layer (Business Logic)
│   ├── models/                        # Domain models
│   │   └── notification_settings_model.dart
│   ├── repositories/                  # Repository interfaces
│   │   ├── device_repository.dart
│   │   ├── earthquake_repository.dart
│   │   └── settings_repository.dart
│   └── usecases/                      # Use cases
│       └── get_earthquakes_usecase.dart
│
├── presentation/                      # Presentation Layer
│   └── providers/                     # State management (Provider pattern)
│       ├── earthquake_provider.dart   # Earthquake data state management
│       ├── settings_provider.dart     # Settings & notification state
│       ├── map_picker_provider.dart   # Map interaction state
│       └── bookmark_provider.dart     # Bookmark state management
│
├── screens/                           # UI Screens
│   ├── home_screen.dart              # Main navigation hub
│   ├── earthquake_list.dart          # List view of earthquakes
│   ├── earthquake_map_screen.dart    # Map view screen
│   ├── earthquake_details.dart       # Detailed event information
│   ├── earthquake_comparison_screen.dart  # Historical comparison view
│   ├── bookmarks_screen.dart         # Saved earthquakes view
│   ├── settings_screen.dart          # User preferences and configuration
│   ├── statistics_screen.dart        # Data analytics and charts
│   ├── map_picker_screen.dart        # Location picker for safe zones
│   ├── onboarding_screen.dart        # First-time user experience
│   ├── web_dashboard_screen.dart     # Web-optimized dashboard
│   └── subscreens/                   # Sub-screens
│       ├── about_screen.dart         # App information
│       ├── emergency_contacts_screen.dart
│       ├── preparedness_screen.dart  # Earthquake preparedness tips
│       └── quiz_screen.dart          # Preparedness quiz
│
├── widgets/                           # Reusable UI Components
│   ├── appbar.dart                   # Custom app bar
│   ├── custom_drawer.dart            # Navigation drawer
│   ├── earthquake_list_item.dart     # List item card
│   ├── earthquake_list_widget.dart   # Complete list view widget
│   ├── earthquake_map_widget.dart    # Complete map widget (2D)
│   ├── earthquake_globe_widget.dart  # 3D globe visualization
│   ├── data_source_status_widget.dart  # Data source status display
│   ├── components/                   # Map & shared components
│   │   ├── earthquake_bottom_sheet.dart  # Map earthquake details popup
│   │   ├── location_button.dart      # GPS location button
│   │   ├── map_layers_button.dart    # Map layer selector
│   │   ├── map_legend.dart           # Magnitude legend
│   │   ├── tsunami_risk_card.dart    # Tsunami risk indicator
│   │   └── zoom_controls.dart        # Map zoom controls
│   ├── settings/                     # Settings screen widgets
│   │   ├── theme_settings_card.dart
│   │   ├── units_settings_card.dart
│   │   ├── clock_settings_card.dart
│   │   ├── cache_settings_card.dart  # Clear cache functionality
│   │   ├── data_source_settings_card.dart
│   │   └── notification_settings_card.dart
│   └── statistics/                   # Statistics visualization widgets
│       └── simple_line_chart.dart
│
├── services/                          # Service Layer
│   ├── api_service.dart              # Base API integration
│   ├── multi_source_api_service.dart # Multi-source data aggregation
│   ├── notification_service.dart     # Local notifications
│   ├── push_notification_service.dart  # Push notification interface
│   ├── push_notification_service_firebase.dart  # Firebase FCM implementation
│   ├── push_notification_service_noop.dart  # No-op for FOSS
│   ├── location_service.dart         # GPS & geolocation
│   ├── earthquake_cache_service.dart # Hive-based earthquake caching
│   ├── tile_cache_service.dart       # Map tile caching
│   ├── bookmark_service.dart         # Earthquake bookmarks persistence
│   ├── globe_cluster_service.dart    # 3D globe marker clustering
│   ├── home_widget_service.dart      # Android home screen widget
│   ├── historical_comparison_service.dart  # Historical data comparison
│   ├── secure_http_client.dart       # HTTPS with certificate pinning
│   ├── http_client_factory.dart      # Platform-agnostic HTTP client
│   ├── http_client_factory_io.dart   # Mobile/desktop HTTP client
│   ├── http_client_factory_web.dart  # Web HTTP client
│   ├── encryption_service.dart       # AES-256 encryption utilities
│   ├── secure_storage_service.dart   # Encrypted key-value storage
│   ├── secure_token_service.dart     # FCM token management
│   ├── token_migration_service.dart  # Legacy token migration
│   ├── analytics_service.dart        # Analytics interface
│   ├── analytics_service_firebase.dart  # Firebase Analytics implementation
│   ├── analytics_service_noop.dart   # No-op analytics for FOSS
│   ├── preferences_service.dart      # User preferences management
│   ├── earthquake_statistics.dart    # Statistical calculations
│   ├── sources/                      # Data source implementations
│   │   ├── earthquake_data_source.dart  # Data source interface
│   │   ├── usgs_data_source.dart     # USGS API implementation
│   │   └── emsc_data_source.dart     # EMSC API implementation
│   └── cache_manager/                # Platform-specific caching
│       ├── cache_manager.dart        # Cache manager interface
│       ├── cache_manager_io.dart     # Mobile/desktop implementation
│       └── cache_manager_web.dart    # Web implementation
│
├── models/                            # Data Models
│   ├── earthquake.dart               # Core earthquake model
│   ├── earthquake_adapter.dart       # Hive type adapter
│   ├── safe_zone.dart                # Safe zone location model
│   ├── push_message.dart             # Push notification message model
│   └── data_source_status.dart       # Data source status model
│
├── provider/                          # Legacy Providers (to be migrated)
│   └── theme_provider.dart           # Theme state management
│
├── utils/                             # Utilities & Helpers
│   ├── formatting.dart               # Date, number, distance formatting
│   ├── enums.dart                    # Application enumerations
│   ├── secure_logger.dart            # Production-ready logging
│   ├── notification_registration_coordinator.dart
│   └── app_page_transitions.dart     # Custom page transitions
│
├── theme/                             # Application Theming
│   ├── app_theme.dart                # Light & dark themes
│   └── app_gradients.dart            # Gradient definitions
```

### Design Patterns Used

- **Clean Architecture**: Separation of data, domain, and presentation layers
- **Repository Pattern**: Abstraction of data sources
- **Use Case Pattern**: Encapsulation of business logic
- **Provider Pattern**: State management across the application
- **Singleton Pattern**: Service instances (NotificationService, AnalyticsService)
- **Factory Pattern**: Data source creation and API service initialization
- **Adapter Pattern**: Hive type adapters for data serialization
- **Strategy Pattern**: Multiple data source implementations

---

## 📦 Setup Instructions

### Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK** (3.7.2 or higher) - Latest stable recommended
- **Dart SDK** (3.7.2 or higher) - Comes bundled with Flutter
- **Java JDK 17** - Required for Android builds
- **Android Studio** or **VS Code** with Flutter/Dart extensions
- **Git** for version control
- **Firebase Account** - Only required for production flavor with push notifications
- **Node.js** (for backend deployment) - Optional, required only for push notifications

### Important Notes

- To build only FOSS flavor, Remove these files (main_prod.dart, analytics_service_firebase.dart, push_notification_service_firebase.dart and other firebase related files), remove firebase dependencies from pubspec.yaml, build.gradle.kts and app/build.gradle.kts. This will ensure that the app builds without any firebase related code.
- Prefer the f-droid branch for building the FOSS flavor app.

### 1. Clone the Repository

```bash
git clone <repository-url>
cd lastquakes
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Environment Variables

Create a `.env` file in the root directory:

```bash
# Server Configuration (required for push notifications)
SERVER_URL=https://your-backend-url.com
```

> **Note:** The `.env` file is required for the app to build. For FOSS builds without push notifications, you can use a placeholder URL.

### 4. Asset Files

The application includes the following asset directories:

```
assets/
├── globe/      # 3D globe textures and resources
├── icon/       # App icon source files
└── splash/     # Splash screen images
```

These are already included in the repository. If you need to regenerate icons or splash screens, see Step 7.

### 5. Firebase Setup (Production Flavor Only)

> **Skip this section** if you're only building the FOSS flavor without Firebase.

#### 5.1 Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select an existing one
3. Enable the following services:
   - **Cloud Messaging** (for push notifications)
   - **Analytics** (for usage analytics)
   - **Crashlytics** (for crash reporting)
   - **Performance** (for performance monitoring)

#### 5.2 Configure Android

1. In Firebase Console, add an Android app
2. Register package name: `app.lastquakes`
3. Download `google-services.json`
4. Place it in `android/app/src/prod/` directory

> **Important:** The production flavor expects Firebase configuration at `android/app/src/prod/google-services.json`

#### 5.3 Configure iOS (Optional)

1. In Firebase Console, add an iOS app
2. Register bundle ID: `app.lastquakes`
3. Download `GoogleService-Info.plist`
4. Place it in `ios/Runner/` directory

#### 5.4 Configure Web (Optional)

1. In Firebase Console, add a Web app
2. Copy the Firebase configuration object
3. Update `web/index.html` with your Firebase config

#### 5.5 Update VAPID Key for Web Notifications

For web push notifications, update the VAPID key in `lib/services/push_notification_service_firebase.dart`:

1. Get your VAPID key from Firebase Console > Project Settings > Cloud Messaging
2. Replace `YOUR_VAPID_KEY_HERE` with your actual VAPID key

### 6. Backend Service Setup (Production Only)

The backend service is required for push notifications to function.

**Backend Requirements:**

- Node.js server (Express recommended)
- Firebase Admin SDK integration
- API Endpoints:
  - `POST /register` - Register FCM tokens
  - `POST /update-settings` - Update notification preferences
  - Webhook integration for USGS/EMSC earthquake feeds

**Deployment Options:**

1. Clone the backend repository (if available separately) or build your own backend service
2. Deploy to a hosting provider (Render, Railway, Heroku, AWS, etc.)
3. Update `.env` file with your backend URL
4. Configure Firebase Admin SDK credentials on your server

### 7. Generate App Icons and Splash Screen

```bash
# Generate app icons for all platforms
dart run flutter_launcher_icons

# Generate native splash screen
dart run flutter_native_splash:create
```

### 8. Build Flavors

The application supports two build flavors:

| Feature                | Production            | FOSS                  |
| ---------------------- | --------------------- | --------------------- |
| **App Name**           | LastQuakes            | LastQuakes FOSS       |
| **Package ID**         | `app.lastquakes`      | `app.lastquakes.foss` |
| **Entry Point**        | `lib/main_prod.dart`  | `lib/main.dart`       |
| **Firebase**           | ✅ Full integration   | ❌ Excluded           |
| **Push Notifications** | ✅ Available          | ❌ Disabled           |
| **Analytics**          | ✅ Firebase Analytics | ❌ No-op              |
| **Distribution**       | Google Play Store     | F-Droid, GitHub       |

### 9. Run the Application

#### Development Mode

```bash
# Run FOSS flavor (default, no Firebase required)
flutter run --flavor foss --dart-define=FLAVOR=foss -t lib/main.dart

# Run Production flavor (requires Firebase setup)
flutter run --flavor prod --dart-define=FLAVOR=prod -t lib/main_prod.dart

# Run on Web (uses FOSS by default)
flutter run -d chrome

# Run on specific device
flutter run --flavor foss --dart-define=FLAVOR=foss -t lib/main.dart -d <device-id>
```

#### Production Builds

##### Using Build Scripts (Windows - Recommended)

```powershell
# Build FOSS APK (no Firebase)
.\scripts\build_foss.ps1 -BuildType apk

# Build Production APK (with Firebase)
.\scripts\build_prod.ps1 -BuildType apk

# Build App Bundle for Play Store
.\scripts\build_prod.ps1 -BuildType appbundle

# Build both APK and App Bundle
.\scripts\build_prod.ps1 -BuildType both

# Auto-increment build number
.\scripts\build_prod.ps1 -IncrementBuild -BuildType apk
```

##### Manual Build Commands

```bash
# FOSS flavor (without Firebase)
flutter build apk --release --flavor foss --dart-define=FLAVOR=foss -t lib/main.dart
flutter build appbundle --release --flavor foss --dart-define=FLAVOR=foss -t lib/main.dart

# Production flavor (with Firebase)
flutter build apk --release --flavor prod --dart-define=FLAVOR=prod -t lib/main_prod.dart
flutter build appbundle --release --flavor prod --dart-define=FLAVOR=prod -t lib/main_prod.dart

# Web build
flutter build web --release --dart-define=FLAVOR=foss -t lib/main.dart
```

**Build Output Locations:**

| Build Type     | Output Path                                                 |
| -------------- | ----------------------------------------------------------- |
| FOSS APK       | `build/app/outputs/apk/foss/release/LastQuakes-FOSS-*.apk`  |
| FOSS AAB       | `build/app/outputs/bundle/fossRelease/app-foss-release.aab` |
| Production APK | `build/app/outputs/apk/prod/release/LastQuakes-*.apk`       |
| Production AAB | `build/app/outputs/bundle/prodRelease/app-prod-release.aab` |
| Web            | `build/web/`                                                |

### 10. Certificate Pinning (Production)

For enhanced security in production, configure SSL certificate pinning:

```bash
# Extract certificate pins for your backend
dart run scripts/get_certificate_pins.dart

# Additional certificate utilities
dart run scripts/extract_pins.dart
dart run scripts/monitor_certificates.dart
```

Update the pins in `lib/services/secure_http_client.dart` with your backend's certificate fingerprints.

### 11. Platform-Specific Permissions

#### Android Permissions

The following permissions are configured in `android/app/src/main/AndroidManifest.xml`:

| Permission                   | Purpose                                    |
| ---------------------------- | ------------------------------------------ |
| `INTERNET`                   | Network access for API calls               |
| `ACCESS_FINE_LOCATION`       | Precise location for distance calculations |
| `ACCESS_COARSE_LOCATION`     | Approximate location                       |
| `ACCESS_BACKGROUND_LOCATION` | Background location for notifications      |
| `POST_NOTIFICATIONS`         | Push notifications (Android 13+)           |
| `RECEIVE_BOOT_COMPLETED`     | Restart services after device boot         |

### 12. Verify Build Flavor

After building, verify the correct flavor was built:

| Check                     | Production                       | FOSS                            |
| ------------------------- | -------------------------------- | ------------------------------- |
| **App Name**              | "LastQuakes"                     | "LastQuakes FOSS"               |
| **Notification Settings** | Visible in Settings              | Hidden                          |
| **Logs**                  | "Firebase Analytics initialized" | "FOSS mode - Firebase disabled" |
| **APK Contents**          | Contains `com/google/firebase`   | No Firebase classes             |

### 13. Testing

```bash
# Run all tests
flutter test

# Run unit tests only
flutter test test/unit/

# Run widget tests only
flutter test test/widget/

# Run with coverage
flutter test --coverage

# Run integration tests
flutter test integration_test/

# Run specific test file
flutter test test/unit/services/multi_source_api_service_test.dart
```

### 14. CI/CD Integration

The project includes GitHub Actions workflows:

- **`build-foss-apk.yml`** - Builds signed FOSS APK on tag push (v\*)
  - Verifies no Firebase/GMS classes in APK
  - Uploads artifacts and creates GitHub releases
  - Uses GitHub Secrets for signing

**Required GitHub Secrets for CI/CD:**

| Secret              | Description                  |
| ------------------- | ---------------------------- |
| `KEYSTORE_BASE64`   | Base64-encoded keystore file |
| `KEYSTORE_PASSWORD` | Keystore password            |
| `KEY_PASSWORD`      | Key password                 |
| `KEY_ALIAS`         | Key alias name               |

---

## 🔧 Configuration

### Data Sources

By default, both USGS and EMSC are enabled. Users can configure this in Settings > Data Sources.

**USGS Configuration:**

- Endpoint: configured in `usgs_data_source.dart`
- Data format: GeoJSON
- Update frequency: Every 5 minutes (from USGS)

**EMSC Configuration:**

- Endpoint: Configured in `emsc_data_source.dart`
- Data format: JSON
- Coverage: European-Mediterranean region

### Notification System (Production Flavor Only)

Notifications use Firebase Cloud Messaging with a backend service for filtering:

1. **Client-side**: User configures notification preferences
2. **Backend**: Monitors USGS feed and matches user criteria
3. **FCM**: Delivers targeted notifications to devices

### Caching Strategy

- **Cache Duration**: 5 minutes (configurable in `multi_source_api_service.dart`)
- **Storage**: Hive database for persistent offline access
- **Cache Invalidation**: Time-based with force refresh option

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **USGS** for providing comprehensive earthquake data
- **EMSC** for European-Mediterranean seismic information
- **Firebase** for backend infrastructure
- **Flutter Community** for excellent packages and support
- **OpenStreetMap, ArcGIS** for map tiles

---

## 📞 Support

For issues, questions, or feature requests, please:

1. Check existing [GitHub Issues](../../issues)
2. Create a new issue with detailed information
3. Provide logs, screenshots, and reproduction steps

---

## 🗺️ Roadmap

- [ ] Offline mode enhancements
- [ ] Additional data sources (Japan Meteorological Agency, etc.)
- [ ] Historical earthquake data visualization
- [ ] Advanced analytics and predictive features
- [ ] Community-contributed earthquake reports
- [ ] Multilingual support

---

**Note**: This is an independent project and is not officially affiliated with USGS, EMSC, or any government seismological organization.

```

```
