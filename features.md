## Security features

1. SecureHttpClient with Certificate Pinning: The app implements certificate pinning to protect against Man-in-the-Middle (MitM) attacks during HTTP communication
2. SecureTokenService: This service is dedicated to securely managing tokens, specifically FCM (Firebase Cloud Messaging) tokens.
3. SecureLogger: The app uses a custom SecureLogger for logging security-related events, such as token operations, certificate pinning results, and errors.
4. SecureStorageService utilizing the EncryptionService for underlying encryption: Provides a high-level interface for managing the secure storage of user data like safe zones, emergency contacts, and notification settings. (Currently uses XOR encryption)

## ---Future planned-
1. Stronger Encryption: Upgrade from XOR to a more robust encryption standard like 
AES-256 for storing sensitive user data locally.

## APP features

1. Near Real-time Earthquake Monitoring
2. Notification alert based on the user settings 
Home screen- 
3. Filtering earthquakes based on Country and magnitude threshold.
4. Earthquake details like Tsunami issued, coordinates, depth, time, specific location on map, 
View on USGS website and open in google map option. 

### Map Screen-
5. Interective map with earthquake points
6. Change map style (Street map, Sattelite, Terrain, Dark and Show fault lines)
7. Current location pin on map
8. Zoom controls on map
9. Filtering options (Magnitude and Time window)

### Settings Screen-
10. Notification settings options (Nearby, safe zones, specific country and worldwide) 
with magnitude threshold.
11. Theme options (Light, Dark, System)
12. Distance measurement change (KM, Mi)
13. Time format change (12 hour clock. 24 hour clock)

### Other features- 
14. Preparedness and safety tips
15. Emergency contacts for different countries with custom contact adding functionality
16. Quizes on earthquakes

## ---Future planned-
1. Multi-Language Support
2. Historical Earthquake Data: Allow users to search and explore past 
earthquake events with interactive visualizations.
3. Improve the map screen design with better map quality

### (User & Social Features)
4. User Accounts: Introduce user accounts to sync settings, saved locations, and emergency contacts across devices.
5. "I Am Safe" Feature: A one-tap button for users to notify their emergency contacts that they are safe after an earthquake.
6. Community Reports: Allow users to report tremors they've felt or share damage reports, creating a real-time feed of information.

### (Advanced Analytics- Earthquake Insights and Predictive Features)
7. Historical earthquake patterns
8. Seismic activity trends
9. Risk assessment for user location
10. Aftershock probability calculations
11. Seismic hazard maps
12. Tsunami Travel Time Visualizer: For users in coastal areas, display an estimated tsunami arrival time on the map after a relevant offshore earthquake.
