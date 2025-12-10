# LastQuakes FOSS - Global Earthquake Monitor 🌍

A comprehensive Flutter application providing real-time global earthquake monitoring with multi-source data integration, interactive map visualization, and advanced filtering capabilities. Built with clean architecture principles and optimized for performance across mobile, web, and desktop platforms.

**This is the FOSS (Free and Open Source Software) version without any proprietary dependencies like Firebase or Google Play Services.**

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

### ⚙️ User Preferences

- **Theme Settings**:
  - Light Mode
  - Dark Mode
  - System Default (follows device settings)
- **Unit Preferences**:
  - Distance: Kilometers or Miles
- **Time Format**: 12-hour or 24-hour display
- **Data Source Selection**: Enable/disable USGS and EMSC
- **Persistent Storage**: Local storage for user preferences

### 📈 Statistics & Analytics

- **Earthquake Statistics**: Visual representation of seismic activity trends
- **Magnitude Distribution**: Charts and graphs for data analysis
- **Geographic Distribution**: Breakdown by region and country
- **Time-Based Analysis**: Hourly, daily, and weekly activity patterns

### Home Screen Widget

- **Home Screen Widget**: Add widget to home screen to display latest earthquakes

### 🔒 Security Features

- **Certificate Pinning**: Secure HTTPS communication with SSL/TLS pinning
- **Secure Storage**: Encrypted local storage for sensitive data using `flutter_secure_storage`
- **Secure Logging**: Privacy-focused logging with sensitive data masking

### 🌐 Cross-Platform Support

- **Android**: Full feature support with native optimizations
- **Web**: Responsive web application with desktop-optimized layouts
- **Desktop (Planned)**: Future support for Windows, macOS, and Linux

## 🔄 FOSS Version

This is the **FOSS (Free and Open Source Software)** version of LastQuakes:

- **App Name**: LastQuakes FOSS
- **Package ID**: `app.lastquakes.foss`
- **No Proprietary Dependencies**: Completely free of Google Play Services, Firebase, and other proprietary software
- **Privacy-Focused**: No analytics, no tracking, no data collection
- **Distribution**: Designed for F-Droid and other open-source app stores

---

## 🏗️ Architecture

The application follows **Clean Architecture** principles with clear separation of concerns:

```
lib/
├── main.dart                          # Application entry point & initialization
│
├── data/                              # Data Layer
│   └── repositories/                  # Repository implementations
│       ├── earthquake_repository_impl.dart
│       ├── settings_repository_impl.dart
│       └── device_repository_noop.dart
│
├── domain/                            # Domain Layer (Business Logic)
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
│       ├── settings_provider.dart     # Settings state (data sources only)
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
│   │   └── data_source_settings_card.dart
│   └── statistics/                   # Statistics visualization widgets
│       └── simple_line_chart.dart
│
├── services/                          # Service Layer
├── services/                          # Service Layer
│   ├── api_service.dart              # Base API integration
│   ├── multi_source_api_service.dart # Multi-source data aggregation
│   ├── location_service.dart         # GPS & geolocationuake caching
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
│   ├── token_migration_service.dart  # Legacy data migration
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
├── models/                            # Data Models
│   ├── earthquake.dart               # Core earthquake model
│   ├── earthquake_adapter.dart       # Hive type adapter
│   ├── safe_zone.dart                # Safe zone location model
│   └── data_source_status.dart       # Data source status model migrated)
│   └── theme_provider.dart           # Theme state management
│
├── utils/                             # Utilities & Helpers
│   ├── formatting.dart               # Date, number, distance formatting
├── utils/                             # Utilities & Helpers
│   ├── formatting.dart               # Date, number, distance formatting
│   ├── enums.dart                    # Application enumerations
│   ├── secure_logger.dart            # Production-ready logging
│   └── app_page_transitions.dart     # Custom page transitions
│   ├── app_theme.dart                # Light & dark themes
│   └── app_gradients.dart            # Gradient definitions
```

### Design Patterns Used

- **Clean Architecture**: Separation of data, domain, and presentation layers
- **Repository Pattern**: Abstraction of data sources
- **Clean Architecture**: Separation of data, domain, and presentation layers
- **Repository Pattern**: Abstraction of data sources
- **Use Case Pattern**: Encapsulation of business logic
- **Provider Pattern**: State management across the application
- **Singleton Pattern**: Service instances (CacheService, ApiService)
- **Factory Pattern**: Data source creation and API service initialization
- **Adapter Pattern**: Hive type adapters for data serialization
- **Strategy Pattern**: Multiple data source implementations

## 📦 Setup Instructions

### Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK** (3.7.2 or higher) - Latest stable recommended
- **Dart SDK** (3.7.2 or higher) - Comes bundled with Flutter
- **Java JDK 17** - Required for Android builds
- **Android Studio** or **VS Code** with Flutter/Dart extensions
- **Git** for version control

### Important Notes

- This is the **f-droid branch** containing only the FOSS version without any proprietary dependencies.
- No Firebase, no Google Play Services, no analytics, no tracking.

### 1. Clone the Repository

```bash
git clone <repository-url>
cd lastquakes
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Environment Variables (Optional)

The `.env` file is optional for the FOSS build. If you need it for development, create one:

```bash
# Optional: Development configuration
DEV_MODE=true
```

### 4. Asset Files

The application includes the following asset directories:

```
assets/
├── globe/      # 3D globe textures and resources
├── icon/       # App icon source files
└── splash/     # Splash screen images
```

These are already included in the repository. If you need to regenerate icons or splash screens, see Step 7.

### 5. Generate App Icons and Splash Screen

```bash
# Generate app icons for all platforms
dart run flutter_launcher_icons

# Generate native splash screen
dart run flutter_native_splash:create
```

### 6. Run the Application

#### Development Mode

```bash
# Run on default device
flutter run --flavor foss --dart-define=FLAVOR=foss -t lib/main.dart

# Run on Web
flutter run -d chrome --flavor foss --dart-define=FLAVOR=foss -t lib/main.dart

# Run on specific device
flutter run --flavor foss --dart-define=FLAVOR=foss -t lib/main.dart -d <device-id>
```

#### Release Builds

##### Using Build Script (Windows - Recommended)

```powershell
# Build FOSS APK
.\scripts\build_foss.ps1 -BuildType apk

# Build App Bundle
.\scripts\build_foss.ps1 -BuildType appbundle

# Build both APK and App Bundle
.\scripts\build_foss.ps1 -BuildType both
```

##### Manual Build Commands

```bash
# Build APK
flutter build apk --release --flavor foss --dart-define=FLAVOR=foss -t lib/main.dart

# Build App Bundle
flutter build appbundle --release --flavor foss --dart-define=FLAVOR=foss -t lib/main.dart

# Web build
flutter build web --release --dart-define=FLAVOR=foss -t lib/main.dart
```

**Build Output Locations:**

| Build Type | Output Path                                                 |
| ---------- | ----------------------------------------------------------- |
| APK        | `build/app/outputs/apk/foss/release/LastQuakes-FOSS-*.apk` |
| AAB        | `build/app/outputs/bundle/fossRelease/app-foss-release.aab` |
| Web        | `build/web/`                                                |

### 7. Platform-Specific Permissions

#### Android Permissions

The following permissions are configured in `android/app/src/main/AndroidManifest.xml`:

| Permission                   | Purpose                                    |
| ---------------------------- | ------------------------------------------ |
| `INTERNET`                   | Network access for API calls               |
| `ACCESS_FINE_LOCATION`       | Precise location for distance calculations |
| `ACCESS_COARSE_LOCATION`     | Approximate location                       |

### 8. Verify Build

After building, verify the build:

- **App Name**: "LastQuakes FOSS"
- **Logs**: Check for "Starting app in FOSS mode"
- **APK Contents**: Verify no Firebase or Google Play Services classes

### 9. Testing

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

### 10. CI/CD Integration

The project includes GitHub Actions workflow:

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
- **Flutter Community** for excellent packages and support
- **OpenStreetMap, ArcGIS** for map tiles
- **F-Droid Community** for promoting free and open-source software

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
- [ ] Multilingual support
- [ ] Desktop platform support (Linux, Windows, macOS)

---

**Note**: This is an independent project and is not officially affiliated with USGS, EMSC, or any government seismological organization.

```

```
