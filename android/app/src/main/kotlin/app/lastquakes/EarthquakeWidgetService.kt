package app.lastquakes

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.*

/**
 * Service that provides the RemoteViewsFactory for the earthquake widget's ListView.
 */
class EarthquakeWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return EarthquakeRemoteViewsFactory(applicationContext)
    }
}

/**
 * Factory that creates RemoteViews for each earthquake item in the widget's ListView.
 */
class EarthquakeRemoteViewsFactory(
    private val context: Context
) : RemoteViewsService.RemoteViewsFactory {

    private var earthquakes: MutableList<EarthquakeData> = mutableListOf()

    data class EarthquakeData(
        val id: String,
        val magnitude: Double,
        val place: String,
        val timeMs: Long,
        val depth: Double,
        val tsunami: Int
    )

    override fun onCreate() {
        loadData()
    }

    override fun onDataSetChanged() {
        loadData()
    }

    private fun loadData() {
        earthquakes.clear()
        try {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val jsonString = prefs.getString("earthquake_data", "[]") ?: "[]"
            val jsonArray = JSONArray(jsonString)

            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                earthquakes.add(
                    EarthquakeData(
                        id = obj.optString("id", ""),
                        magnitude = obj.optDouble("magnitude", 0.0),
                        place = obj.optString("place", "Unknown"),
                        timeMs = obj.optLong("time", 0),
                        depth = obj.optDouble("depth", 0.0),
                        tsunami = obj.optInt("tsunami", 0)
                    )
                )
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        earthquakes.clear()
    }

    override fun getCount(): Int = earthquakes.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.earthquake_widget_item)

        if (position < earthquakes.size) {
            val quake = earthquakes[position]

            // Set magnitude
            views.setTextViewText(R.id.magnitude_badge, String.format(Locale.US, "%.1f", quake.magnitude))

            // Set magnitude background based on value
            val badgeDrawable = when {
                quake.magnitude >= 7.0 -> R.drawable.magnitude_badge_red
                quake.magnitude >= 5.0 -> R.drawable.magnitude_badge_orange
                else -> R.drawable.magnitude_badge_green
            }
            views.setInt(R.id.magnitude_badge, "setBackgroundResource", badgeDrawable)

            // Set location
            views.setTextViewText(R.id.location_text, quake.place)

            // Set relative time
            views.setTextViewText(R.id.time_text, getRelativeTimeString(quake.timeMs))
            
            // Set up click intent to open app
            val fillIntent = Intent().apply {
                putExtra("earthquake_id", quake.id)
            }
            views.setOnClickFillInIntent(R.id.quake_item_container, fillIntent)
        }

        return views
    }

    private fun getRelativeTimeString(timeMs: Long): String {
        if (timeMs <= 0) return "Unknown time"

        val now = System.currentTimeMillis()
        val diff = now - timeMs

        val minutes = diff / (60 * 1000)
        val hours = diff / (60 * 60 * 1000)

        return when {
            minutes < 1 -> "Just now"
            minutes < 60 -> "${minutes}m ago"
            hours < 24 -> "${hours}h ago"
            else -> {
                val dateFormat = SimpleDateFormat("MMM d", Locale.getDefault())
                dateFormat.format(Date(timeMs))
            }
        }
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true
}
