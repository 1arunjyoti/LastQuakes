# LastQuakes - Global Earthquake Monitor 🌍

A Flutter application providing real-time global earthquake monitoring using data from the U.S. Geological Survey (USGS). Features include customizable push notifications via a dedicated backend, interactive map visualization, event filtering, and detailed seismic information.

---

## Core Features

*   **Real-time Earthquake Data:** Fetches and displays recent seismic events from the official USGS API, with local caching for performance and offline viewing.
*   **Interactive Map Visualization:** Utilizes `flutter_map` for displaying events with magnitude-based markers, marker clustering, multiple base layers (Street, Satellite, Terrain, Dark), optional fault line overlays, and live filtering (magnitude, time window).
*   **Dynamic List View:** Presents earthquakes with client-side filtering (magnitude, country), distance calculation (km/mi respecting user preference).
*   **Detailed Event Analysis:** Provides comprehensive information for selected earthquakes, including depth, tsunami status, coordinates.
*   **Customizable Push Notifications:** Leverages Firebase Cloud Messaging (FCM) and a backend service for user-defined alerts based on magnitude, location (country or radius).
*   **User Preferences:** Includes settings for theme (Light/Dark/System), units (km/mi), time format (12/24h), notification criteria, and map display options.

---

## Screenhots
<img src="graphics\screenshots\home_screen.png" width="200" height="400">,
<img src="graphics\screenshots\details_screen.png" width="200" height="400">,
<img src="graphics\screenshots\map_screen.png" width="200" height="400">,
<img src="graphics\screenshots\mapscreen_filter.png" width="200" height="400">,
<img src="graphics\screenshots\app_drawer.png" width="200" height="400">,
<img src="graphics\screenshots\settings_screen.png" width="200" height="400">,

---

## Setup Requirements

1.  **Clone Repository
2.  **Install Dependencies:** `flutter pub get`
3.  **Firebase Project Setup:**
    *   Create a Firebase project and configure it for Flutter.
    *   Add Android and/or iOS apps in the Firebase console.
    *   Place the generated `google-services.json` (Android) file in the respective directory (`android/app/`).
    *   Enable **Cloud Messaging** in the Firebase project.
4.  **Backend Service Deployment:**
    *   Push notifications **will not function** without a running backend service.
    *   Deploy the corresponding backend code to a hosting provider.
5. **Environment Setup:**
```bash
# Verify .env file exists with backend URL
echo "SERVER_URL=" > .env
```
6.  **Run the App:** `flutter run`
7. **Certificate Pins (Production)**
```bash
# Extract current certificate pins
dart run scripts/get_certificate_pins.dart

# Update pins in lib/services/secure_http_client.dart
# Change development mode to production in certificate validation
```

## Architechture

```
├── lib/
│   ├── main.dart                 # App entry point & Firebase setup
│   ├── models/                   # Data models
│   │   └── safe_zone.dart       # Safe zone location model
│   ├── screens/                  # UI screens
│   │   ├── home_screen.dart     # Navigation handler
│   │   ├── earthquake_list.dart # List view with filtering
│   │   ├── earthquake_map_screen.dart # Interactive map
│   │   ├── earthquake_details.dart # Event details
│   │   ├── settings_screen.dart # User preferences
│   │   └── subscreens/          # Sub-screens
│   ├── services/                # Business logic layer
│   │   ├── api_service.dart     # USGS API integration
│   │   ├── notification_service.dart # FCM & local notifications
│   │   ├── location_service.dart # GPS & location handling
│   │   ├── secure_http_client.dart # Certificate pinning
│   │   ├── encryption_service.dart # AES encryption
│   │   ├── secure_storage_service.dart # Encrypted storage
│   │   └── secure_token_service.dart # Token management
│   ├── provider/                # State management
│   │   └── theme_provider.dart  # Theme state management
│   ├── widgets/                 # Reusable UI components
│   ├── utils/                   # Utilities & helpers
│   └── theme/                   # App theming
```