# LastQuakes - Global Earthquake Monitor 🌍

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A Flutter application providing real-time global earthquake monitoring using data from the U.S. Geological Survey (USGS). Features include customizable push notifications via a dedicated backend, interactive map visualization, event filtering, and detailed seismic information.

---

## Core Features

*   **Real-time Earthquake Data:** Fetches and displays recent seismic events from the official USGS API, with local caching for performance and offline viewing.
*   **Interactive Map Visualization:** Utilizes `flutter_map` for displaying events with magnitude-based markers, marker clustering, multiple base layers (Street, Satellite, Terrain, Dark), optional fault line overlays, and live filtering (magnitude, time window). Map preferences are persisted.
*   **Dynamic List View:** Presents earthquakes with client-side filtering (magnitude, country), distance calculation (km/mi respecting user preference).
*   **Detailed Event Analysis:** Provides comprehensive information for selected earthquakes, including depth, tsunami status, coordinates, and external links.
*   **Customizable Push Notifications:** Leverages Firebase Cloud Messaging (FCM) and a backend service for user-defined alerts based on magnitude, location (country or radius).
*   **User Preferences:** Includes settings for theme (Light/Dark/System), units (km/mi), time format (12/24h), notification criteria, and map display options.

---

#screenhots
<img src="graphics\screenshots\home_screen.png" width="200" height="400">
<img src="graphics\screenshots\details_screen.png" width="200" height="400">
<img src="graphics\screenshots\map_screen.png" width="200" height="400">
<img src="graphics\screenshots\mapscreen_filter.png" width="200" height="400">
<img src="graphics\screenshots\app_drawer.png" width="200" height="400">
<img src="graphics\screenshots\settings_screen.png" width="200" height="400">

---

## Architecture Overview

The application fetches data via `ApiService` (USGS API) and caches it using `shared_preferences`. UI state is managed via `provider`. Location context is provided by `LocationService` (`geolocator`). Push notifications depend on FCM and require a separate backend service (not included in this repository) for filtering and dispatch. The `NotificationService` within the app handles token registration, preference syncing with the backend, and displaying received notifications.

---

## Setup Requirements

1.  **Clone Repository:** `git clone https://[your-repository-url].git && cd lastquakes-app`
2.  **Install Dependencies:** `flutter pub get`
3.  **Firebase Project Setup:**
    *   Create a Firebase project and configure it for Flutter ([FlutterFire Setup Guide](https://firebase.google.com/docs/flutter/setup)).
    *   Add Android and/or iOS apps in the Firebase console.
    *   Place the generated `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) files in their respective directories (`android/app/` and `ios/Runner/`).
    *   Enable **Cloud Messaging** in the Firebase project.
4.  **Backend Service Deployment:**
    *   Push notifications **will not function** without a running backend service.
    *   Deploy the corresponding backend code (obtained separately) to a hosting provider (e.g., Render, Google Cloud Run, Heroku).
5.  **Run the App:** `flutter run`

## Contributing

Contributions via Pull Requests or Issue reporting are welcome. Please adhere to standard coding practices and provide clear descriptions.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.