package id.replay.mockloc.controller

import android.content.Context
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** Satu fix (atau satu skenario error) yang dibagikan lewat [MockLocationProvider]. */
data class Fix(
    val lat: Double? = null,
    val lng: Double? = null,
    val accuracy: Double? = null,
    val altitude: Double? = null,
    val speed: Double? = null,
    val bearing: Double? = null,
    val time: Long = System.currentTimeMillis(),
    val error: String? = null,
) {
    fun toRow(): Array<Any?> = arrayOf(lat, lng, accuracy, altitude, speed, bearing, time, error)

    fun toMap(): Map<String, Any?> = COLUMNS.zip(toRow()).toMap()

    fun toJson(): String = JSONObject().apply {
        for ((k, v) in toMap()) put(k, v ?: JSONObject.NULL)
    }.toString()

    companion object {
        val COLUMNS = arrayOf("lat", "lng", "accuracy", "altitude", "speed", "bearing", "time", "error")

        fun fromJson(s: String): Fix {
            val o = JSONObject(s)
            fun d(k: String) = if (o.isNull(k)) null else o.getDouble(k)
            return Fix(
                lat = d("lat"),
                lng = d("lng"),
                accuracy = d("accuracy"),
                altitude = d("altitude"),
                speed = d("speed"),
                bearing = d("bearing"),
                time = o.optLong("time", System.currentTimeMillis()),
                error = if (o.isNull("error")) null else o.getString("error"),
            )
        }
    }
}

/** Status pemutar rute, dibaca UI Controller. */
data class RouteStatus(
    val state: String = "idle", // idle, running, paused, finished
    val traveled: Double = 0.0,
    val total: Double = 0.0,
    val speedKmh: Double = 0.0,
    val isStatic: Boolean = false,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "state" to state, "traveled" to traveled, "total" to total,
        "speedKmh" to speedKmh, "isStatic" to isStatic,
    )
}

/**
 * Fix terakhir, status rute, allowlist, dan riwayat. Fix disimpan di
 * SharedPreferences supaya tetap ada setelah aplikasi ditutup.
 */
object FixStore {
    private const val PREFS = "mockloc_fix"
    private const val KEY_FIX = "fix"
    private const val KEY_ALLOW = "allowlist"
    private const val KEY_ROUTE = "route"
    private const val HISTORY_FILE = "history.csv"
    private const val HISTORY_MAX_BYTES = 512 * 1024
    private const val HISTORY_KEEP_LINES = 3000
    const val HISTORY_HEADER = "time,lat,lng,accuracy,altitude,speed,bearing,error"

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun load(ctx: Context): Fix? = prefs(ctx).getString(KEY_FIX, null)?.let(Fix::fromJson)

    fun save(ctx: Context, fix: Fix) {
        prefs(ctx).edit().putString(KEY_FIX, fix.toJson()).apply()
        appendHistory(ctx, fix)
        SystemMock.push(ctx, fix)
        notifyChanged(ctx)
    }

    fun clear(ctx: Context) {
        SystemMock.release(ctx)
        prefs(ctx).edit().remove(KEY_FIX).apply()
        notifyChanged(ctx)
    }

    /** ContentObserver di aplikasi target dan di UI Controller menerima ini. */
    fun notifyChanged(ctx: Context) = ctx.contentResolver.notifyChange(MockLocationProvider.URI, null)

    fun routeStatus(ctx: Context): RouteStatus {
        val o = prefs(ctx).getString(KEY_ROUTE, null)?.let(::JSONObject) ?: return RouteStatus()
        return RouteStatus(
            state = o.optString("state", "idle"),
            traveled = o.optDouble("traveled", 0.0),
            total = o.optDouble("total", 0.0),
            speedKmh = o.optDouble("speedKmh", 0.0),
            isStatic = o.optBoolean("isStatic", false),
        )
    }

    fun saveRouteStatus(ctx: Context, status: RouteStatus) =
        prefs(ctx).edit().putString(KEY_ROUTE, JSONObject(status.toMap()).toString()).apply()

    fun allowlist(ctx: Context): Set<String> = prefs(ctx).getStringSet(KEY_ALLOW, emptySet()) ?: emptySet()

    fun setAllowlist(ctx: Context, packages: Set<String>) =
        prefs(ctx).edit().putStringSet(KEY_ALLOW, packages).apply()

    private val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }

    private fun appendHistory(ctx: Context, fix: Fix) {
        val file = File(ctx.filesDir, HISTORY_FILE)
        val cells = listOf(isoFormat.format(Date(fix.time))) +
            listOf(fix.lat, fix.lng, fix.accuracy, fix.altitude, fix.speed, fix.bearing).map { it?.toString() ?: "" } +
            (fix.error ?: "")
        file.appendText(cells.joinToString(",") + "\n")
        if (file.length() > HISTORY_MAX_BYTES) {
            file.writeText(file.readLines().takeLast(HISTORY_KEEP_LINES).joinToString("\n", postfix = "\n"))
        }
    }

    fun historyCsv(ctx: Context): String {
        val file = File(ctx.filesDir, HISTORY_FILE)
        return HISTORY_HEADER + "\n" + (if (file.exists()) file.readText() else "")
    }

    fun clearHistory(ctx: Context) {
        File(ctx.filesDir, HISTORY_FILE).delete()
    }
}
