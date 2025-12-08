package app.lastquakes

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*
import kotlin.concurrent.thread

/**
 * Android home screen widget for displaying recent earthquakes.
 * 
 * This widget:
 * - Displays all earthquakes from the last 24 hours in a scrollable list
 * - Provides a refresh button that fetches data in background
 * - Opens the main app when tapped
 * - Updates automatically every 30 minutes
 */
class EarthquakeWidget : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "HomeWidgetPreferences"
        private const val EARTHQUAKE_DATA_KEY = "earthquake_data"
        private const val LAST_UPDATE_KEY = "last_update"
        private const val LAST_REFRESH_KEY = "last_refresh_time"
        private const val REFRESH_COOLDOWN_MS = 30000L // 30 seconds cooldown
        const val ACTION_REFRESH = "app.lastquakes.REFRESH_WIDGET"

        fun updateAllWidgets(context: Context) {
            val intent = Intent(context, EarthquakeWidget::class.java)
            intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            val ids = AppWidgetManager.getInstance(context)
                .getAppWidgetIds(ComponentName(context, EarthquakeWidget::class.java))
            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            context.sendBroadcast(intent)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        if (intent.action == ACTION_REFRESH) {
            // Check cooldown to prevent spam
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val lastRefresh = prefs.getLong(LAST_REFRESH_KEY, 0)
            val now = System.currentTimeMillis()
            
            if (now - lastRefresh < REFRESH_COOLDOWN_MS) {
                val remaining = (REFRESH_COOLDOWN_MS - (now - lastRefresh)) / 1000
                android.util.Log.d("EarthquakeWidget", "Refresh cooldown: ${remaining}s remaining")
                return
            }
            
            // Save refresh time and proceed
            prefs.edit().putLong(LAST_REFRESH_KEY, now).apply()
            refreshDataInBackground(context)
        }
    }

    /**
     * Fetch earthquake data from USGS and EMSC APIs in background thread
     */
    private fun refreshDataInBackground(context: Context) {
        android.util.Log.d("EarthquakeWidget", "Refresh button pressed - fetching from USGS + EMSC...")
        
        thread {
            try {
                // Calculate 24 hours ago
                val now = System.currentTimeMillis()
                val oneDayAgo = now - (24 * 60 * 60 * 1000)
                val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
                val dateOnlyFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                dateFormat.timeZone = TimeZone.getTimeZone("UTC")
                dateOnlyFormat.timeZone = TimeZone.getTimeZone("UTC")
                val startTime = dateFormat.format(Date(oneDayAgo))
                val endTime = dateFormat.format(Date(now))
                val startDate = dateOnlyFormat.format(Date(oneDayAgo))
                val endDate = dateOnlyFormat.format(Date(now))

                val allEarthquakes = mutableListOf<JSONObject>()
                val seenIds = mutableSetOf<String>()

                // Fetch from USGS
                try {
                    val usgsUrl = "https://earthquake.usgs.gov/fdsnws/event/1/query?" +
                        "format=geojson&orderby=time&minmagnitude=3.0" +
                        "&starttime=$startTime&endtime=$endTime&limit=500"
                    
                    val usgsQuakes = fetchFromUrl(usgsUrl, "USGS")
                    for (i in 0 until usgsQuakes.length()) {
                        val quake = usgsQuakes.getJSONObject(i)
                        val id = quake.getString("id")
                        if (!seenIds.contains(id)) {
                            seenIds.add(id)
                            allEarthquakes.add(quake)
                        }
                    }
                    android.util.Log.d("EarthquakeWidget", "USGS: ${usgsQuakes.length()} earthquakes")
                } catch (e: Exception) {
                    android.util.Log.e("EarthquakeWidget", "USGS fetch failed: ${e.message}")
                }

                // Build time-based index for O(1) duplicate detection
                // Key = time bucket (5 min) + rounded magnitude
                val duplicateIndex = mutableSetOf<String>()
                for (quake in allEarthquakes) {
                    val key = createDuplicateKey(quake)
                    duplicateIndex.add(key)
                }

                // Fetch from EMSC
                try {
                    val emscUrl = "https://www.seismicportal.eu/fdsnws/event/1/query?" +
                        "format=json&orderby=time-desc&minmagnitude=3.0" +
                        "&starttime=$startDate&endtime=$endDate&limit=500"
                    
                    val emscQuakes = fetchEmscFromUrl(emscUrl)
                    var addedCount = 0
                    for (i in 0 until emscQuakes.length()) {
                        val quake = emscQuakes.getJSONObject(i)
                        val id = quake.getString("id")
                        val key = createDuplicateKey(quake)
                        // Check for duplicates using O(1) hash lookup
                        if (!seenIds.contains(id) && !duplicateIndex.contains(key)) {
                            seenIds.add(id)
                            duplicateIndex.add(key)
                            allEarthquakes.add(quake)
                            addedCount++
                        }
                    }
                    android.util.Log.d("EarthquakeWidget", "EMSC: ${emscQuakes.length()} fetched, $addedCount unique added")
                } catch (e: Exception) {
                    android.util.Log.e("EarthquakeWidget", "EMSC fetch failed: ${e.message}")
                }

                // Sort by time (most recent first)
                allEarthquakes.sortByDescending { it.optLong("time", 0) }

                // Convert to JSONArray
                val result = JSONArray()
                for (quake in allEarthquakes) {
                    result.put(quake)
                }

                android.util.Log.d("EarthquakeWidget", "Total: ${result.length()} earthquakes (after merge)")

                // Save to SharedPreferences
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit()
                    .putString(EARTHQUAKE_DATA_KEY, result.toString())
                    .putLong(LAST_UPDATE_KEY, System.currentTimeMillis())
                    .apply()

                // Update all widgets
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val ids = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, EarthquakeWidget::class.java)
                )
                
                // Notify data changed for ListView
                for (id in ids) {
                    appWidgetManager.notifyAppWidgetViewDataChanged(id, R.id.earthquake_list_view)
                }
                
                // Force update
                updateAllWidgets(context)
                
                android.util.Log.d("EarthquakeWidget", "Widget refresh complete!")
            } catch (e: Exception) {
                android.util.Log.e("EarthquakeWidget", "Refresh failed: ${e.message}")
                e.printStackTrace()
            }
        }
    }

    private fun fetchFromUrl(urlString: String, source: String): JSONArray {
        val url = URL(urlString)
        val connection = url.openConnection() as HttpURLConnection
        connection.requestMethod = "GET"
        connection.connectTimeout = 15000
        connection.readTimeout = 15000

        return if (connection.responseCode == HttpURLConnection.HTTP_OK) {
            val reader = BufferedReader(InputStreamReader(connection.inputStream))
            val response = reader.readText()
            reader.close()
            connection.disconnect()
            parseUsgsGeoJson(response)
        } else {
            connection.disconnect()
            JSONArray()
        }
    }

    private fun fetchEmscFromUrl(urlString: String): JSONArray {
        val url = URL(urlString)
        val connection = url.openConnection() as HttpURLConnection
        connection.requestMethod = "GET"
        connection.connectTimeout = 15000
        connection.readTimeout = 15000

        return if (connection.responseCode == HttpURLConnection.HTTP_OK) {
            val reader = BufferedReader(InputStreamReader(connection.inputStream))
            val response = reader.readText()
            reader.close()
            connection.disconnect()
            parseEmscJson(response)
        } else {
            connection.disconnect()
            JSONArray()
        }
    }

    /**
     * Create a hash key for duplicate detection.
     * Key = time bucket (5 min) + rounded magnitude (0.1)
     * This enables O(1) lookups instead of O(n) linear scans.
     */
    private fun createDuplicateKey(quake: JSONObject): String {
        val mag = quake.optDouble("magnitude", 0.0)
        val time = quake.optLong("time", 0)
        
        // Round magnitude to 0.1 and time to 5-minute buckets
        val roundedMag = (mag * 10).toLong()
        val timeBucket = time / (5 * 60 * 1000)
        
        return "${roundedMag}_$timeBucket"
    }

    /**
     * Parse USGS GeoJSON format into our widget data format
     */
    private fun parseUsgsGeoJson(geoJson: String): JSONArray {
        val result = JSONArray()
        try {
            val root = JSONObject(geoJson)
            val features = root.optJSONArray("features") ?: return result

            for (i in 0 until features.length()) {
                val feature = features.getJSONObject(i)
                val properties = feature.getJSONObject("properties")
                val geometry = feature.getJSONObject("geometry")
                val coordinates = geometry.getJSONArray("coordinates")

                val quake = JSONObject().apply {
                    put("id", feature.optString("id", ""))
                    put("magnitude", properties.optDouble("mag", 0.0))
                    put("place", truncatePlace(properties.optString("place", "Unknown")))
                    put("time", properties.optLong("time", 0))
                    put("depth", coordinates.optDouble(2, 0.0))
                    put("tsunami", properties.optInt("tsunami", 0))
                }
                result.put(quake)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return result
    }

    private fun truncatePlace(place: String): String {
        if (place.length <= 30) return place
        val commaIndex = place.indexOf(',')
        if (commaIndex in 1..30) {
            return place.substring(0, commaIndex)
        }
        return place.substring(0, 27) + "..."
    }

    /**
     * Parse EMSC JSON format into our widget data format
     */
    private fun parseEmscJson(jsonStr: String): JSONArray {
        val result = JSONArray()
        try {
            val root = JSONObject(jsonStr)
            val features = root.optJSONArray("features") ?: return result

            // Reuse single formatter instance (moved outside loop for performance)
            val emscDateFormatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }

            for (i in 0 until features.length()) {
                val feature = features.getJSONObject(i)
                val properties = feature.optJSONObject("properties") ?: continue
                val geometry = feature.optJSONObject("geometry") ?: continue
                val coordinates = geometry.optJSONArray("coordinates") ?: continue

                // EMSC uses ISO time string, convert to milliseconds
                val timeStr = properties.optString("time", "")
                val timeMs = try {
                    emscDateFormatter.parse(timeStr.take(19))?.time ?: 0L
                } catch (e: Exception) { 0L }

                val quake = JSONObject().apply {
                    put("id", "emsc_" + properties.optString("source_id", i.toString()))
                    put("magnitude", properties.optDouble("mag", 0.0))
                    put("place", truncatePlace(properties.optString("flynn_region", "Unknown")))
                    put("time", timeMs)
                    put("depth", coordinates.optDouble(2, 0.0))
                    put("tsunami", 0)
                }
                result.put(quake)
            }
        } catch (e: Exception) {
            android.util.Log.e("EarthquakeWidget", "EMSC parse error: ${e.message}")
        }
        return result
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.earthquake_widget)
        
        // Set up refresh button - triggers background refresh
        val refreshIntent = Intent(context, EarthquakeWidget::class.java).apply {
            action = ACTION_REFRESH
        }
        val refreshPendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            refreshIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.refresh_button, refreshPendingIntent)
        
        // Set up click to open app (for header area)
        val openAppIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val openAppPendingIntent = PendingIntent.getActivity(
            context,
            1,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_title, openAppPendingIntent)
        
        // Load earthquake data from SharedPreferences to get count
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val earthquakeJson = prefs.getString(EARTHQUAKE_DATA_KEY, "[]") ?: "[]"
        val lastUpdate = prefs.getLong(LAST_UPDATE_KEY, 0)
        
        try {
            val earthquakes = JSONArray(earthquakeJson)
            val count = earthquakes.length()
            val hasData = count > 0
            
            // Update title with count (shorter format)
            views.setTextViewText(R.id.widget_title, "Earthquakes in 24h ($count)")
            
            // Update last updated time (compact format)
            if (lastUpdate > 0) {
                val dateFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
                views.setTextViewText(R.id.last_updated, dateFormat.format(Date(lastUpdate)))
            } else {
                views.setTextViewText(R.id.last_updated, "--:--")
            }
            
            // Show/hide empty state and ListView
            views.setViewVisibility(R.id.empty_state, if (hasData) View.GONE else View.VISIBLE)
            views.setViewVisibility(R.id.earthquake_list_view, if (hasData) View.VISIBLE else View.GONE)
            
            if (hasData) {
                // Set up the intent for the RemoteViewsService (ListView adapter)
                val serviceIntent = Intent(context, EarthquakeWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    // Use a unique URI to prevent reusing old RemoteViewsFactory
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }
                views.setRemoteAdapter(R.id.earthquake_list_view, serviceIntent)
                
                // Set up the pending intent template for list item clicks
                val itemIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                val itemPendingIntent = PendingIntent.getActivity(
                    context,
                    2,
                    itemIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                )
                views.setPendingIntentTemplate(R.id.earthquake_list_view, itemPendingIntent)
            }
            
        } catch (e: Exception) {
            // Show empty state on error
            views.setViewVisibility(R.id.empty_state, View.VISIBLE)
            views.setViewVisibility(R.id.earthquake_list_view, View.GONE)
            views.setTextViewText(R.id.widget_title, "Last 24h Earthquakes")
        }
        
        // Update the widget first, then notify data changed
        appWidgetManager.updateAppWidget(appWidgetId, views)
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.earthquake_list_view)
    }
}
