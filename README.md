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

### 🔔 Customizable Push Notifications

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

### 🔒 Security Features

- **Certificate Pinning**: Secure HTTPS communication with SSL/TLS pinning
- **Encrypted Storage**: AES-256 encryption for sensitive data using `flutter_secure_storage`
- **Secure Token Management**: Encrypted FCM token storage and rotation
- **Token Migration**: Automatic migration from legacy storage to encrypted storage
- **Secure Logging**: Production-ready logging with sensitive data masking

### 🌐 Cross-Platform Support

- **Android**: Full feature support with native optimizations
- **iOS**: Full feature support with iOS-specific UI adaptations
- **Web**: Responsive web application with desktop-optimized layouts
- **Linux**: Desktop application support
- **macOS**: Desktop application support
- **Windows**: Desktop application support

---

## 🏗️ Architecture

The application follows **Clean Architecture** principles with clear separation of concerns:

```
lib/
├── main.dart                          # Application entry point & initialization
├── app_bootstrap.dart                 # Bootstrap configuration and setup
│
├── data/                              # Data Layer
│   └── repositories/                  # Repository implementations
│       ├── earthquake_repository_impl.dart
│       ├── settings_repository_impl.dart
│       └── device_repository_impl.dart
│
├── domain/                            # Domain Layer (Business Logic)
│   ├── models/                        # Domain models
│   ├── repositories/                  # Repository interfaces
│   ├── usecases/                      # Use cases
│   │   └── get_earthquakes_usecase.dart
│   └── services/                      # Domain services
│
├── presentation/                      # Presentation Layer
│   └── providers/                     # State management (Provider pattern)
│       ├── earthquake_provider.dart   # Earthquake data state management
│       ├── settings_provider.dart     # Settings & notification state
│       └── map_picker_provider.dart   # Map interaction state
│
├── screens/                           # UI Screens
│   ├── home_screen.dart              # Main navigation hub
│   ├── earthquake_list.dart          # List view of earthquakes
│   ├── earthquake_map_screen.dart    # Map view screen
│   ├── earthquake_details.dart       # Detailed event information
│   ├── settings_screen.dart          # User preferences and configuration
│   ├── statistics_screen.dart        # Data analytics and charts
│   ├── map_picker_screen.dart        # Location picker for safe zones
│   ├── onboarding_screen.dart        # First-time user experience
│   ├── web_dashboard_screen.dart     # Web-optimized dashboard
│   └── subscreens/                   # Sub-screens
│       ├── about_screen.dart         # App information
│       ├── emergency_contacts_screen.dart
│       ├── privacy_policy_screen.dart
│       └── terms_and_conditions_screen.dart
│
├── widgets/                           # Reusable UI Components
│   ├── appbar.dart                   # Custom app bar
│   ├── custom_drawer.dart            # Navigation drawer
│   ├── earthquake_list_item.dart     # List item card
│   ├── earthquake_list_widget.dart   # Complete list view widget
│   ├── earthquake_map_widget.dart    # Complete map widget
│   ├── components/                   # Shared components
│   ├── settings/                     # Settings screen widgets
│   │   ├── theme_settings_card.dart
│   │   ├── units_settings_card.dart
│   │   └── clock_settings_card.dart
│   └── statistics/                   # Statistics visualization widgets
│
├── services/                          # Service Layer
│   ├── api_service.dart              # USGS API integration
│   ├── multi_source_api_service.dart # Multi-source data aggregation
│   ├── notification_service.dart     # FCM & local notifications
│   ├── location_service.dart         # GPS & geolocation
│   ├── earthquake_cache_service.dart # Hive-based caching
│   ├── secure_http_client.dart       # HTTPS with certificate pinning
│   ├── encryption_service.dart       # AES-256 encryption utilities
│   ├── secure_storage_service.dart   # Encrypted key-value storage
│   ├── secure_token_service.dart     # FCM token management
│   ├── token_migration_service.dart  # Legacy token migration
│   ├── analytics_service.dart        # Firebase Analytics integration
│   ├── preferences_service.dart      # User preferences management
│   ├── earthquake_statistics.dart    # Statistical calculations
│   ├── sources/                      # Data source implementations
│   │   ├── usgs_data_source.dart
│   │   ├── emsc_data_source.dart
│   │   └── data_source_interface.dart
│   └── cache_manager/                # Caching strategy implementations
│       ├── cache_manager.dart
│       ├── memory_cache.dart
│       └── hive_cache.dart
│
├── models/                            # Data Models
│   ├── earthquake.dart               # Core earthquake model
│   ├── earthquake_adapter.dart       # Hive type adapter
│   └── safe_zone.dart                # Safe zone location model
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
│
└── config/                            # Configuration Files
    └── [Configuration files if any]
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

- **Flutter SDK** (3.7.2 or higher)
- **Dart SDK** (3.7.2 or higher) - Comes with Flutter
- **Android Studio** or **VS Code** with Flutter extensions
- **Git** for version control
- **Firebase Account** for push notifications
- **Node.js** (for backend deployment) - Optional but required for notifications

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
# Server Configuration
SERVER_URL=https://your-backend-url.com
```

Replace `https://your-backend-url.com` with your deployed backend URL. This is required for push notifications to function.

### 4. Firebase Setup

#### 4.1 Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select an existing one
3. Enable **Cloud Messaging**, **Analytics**, and **Crashlytics**

#### 4.2 Configure Android

1. In Firebase Console, add an Android app
2. Register package name: `com.yourcompany.lastquakes` (or your custom package)
3. Download `google-services.json`
4. Place it in `android/app/` directory

#### 4.3 Configure Web (Optional)

1. In Firebase Console, add a Web app
2. Copy the Firebase configuration
3. Update `web/index.html` with Firebase config

### 5. Backend Service Setup

The backend service is required for push notifications to function.

#### Deploy Your Own Backend

1. Clone the backend repository (if available separately)
2. Deploy to a hosting provider (Render, Heroku, AWS, etc.)
3. Update `.env` file with your backend URL
4. Ensure the backend has access to Firebase Admin SDK for FCM

**Backend Requirements:**

- Node.js server with Express
- Firebase Admin SDK integration
- Endpoints for:
  - `/register` - Register FCM tokens
  - `/update-settings` - Update notification preferences
  - Webhook for USGS earthquake feed

### 6. Generate App Icons and Splash Screen

```bash
# Generate app icons
flutter pub run flutter_launcher_icons

# Generate splash screen
flutter pub run flutter_native_splash:create
```

### 7. Run the Application

#### For Development (Mobile)

```bash
# Android
flutter run

# Web
flutter run -d chrome

```

#### For Production Build

```bash
# Android APK
flutter build apk --release

# Android App Bundle (for Google Play)
flutter build appbundle --release

# Web
flutter build web --release
```

### 8. Certificate Pinning Configuration (Production)

For production environments, update the SSL certificate pins:

```bash
# Extract current certificate pins
dart run scripts/get_certificate_pins.dart

# Update pins in lib/services/secure_http_client.dart
# Change development mode to production in certificate validation
```

**Important**: Update the certificate pins according to your backend's SSL certificate.

### 9. Platform-Specific Permissions

#### Android

Ensure the following permissions are in `android/app/src/main/AndroidManifest.xml`:

- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `INTERNET`
- `POST_NOTIFICATIONS` (Android 13+)

### 10. Testing

```bash
# Run all tests
flutter test

# Run unit tests
flutter test test/unit/

# Run widget tests
flutter test test/widget/

# Run integration tests
flutter test integration_test/
```

---

## 🔧 Configuration

### Data Sources

By default, both USGS and EMSC are enabled. Users can configure this in Settings > Data Sources.

**USGS Configuration:**

- Endpoint: `https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/`
- Data format: GeoJSON
- Update frequency: Every 5 minutes (from USGS)

**EMSC Configuration:**

- Endpoint: Configured in `emsc_data_source.dart`
- Data format: JSON
- Coverage: European-Mediterranean region

### Notification System

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
- **OpenStreetMap** for map tiles

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
