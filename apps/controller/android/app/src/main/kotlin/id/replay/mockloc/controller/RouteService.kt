package id.replay.mockloc.controller

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import java.util.Arrays
import java.util.Random
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Foreground service (`specialUse`) yang memutar rute dengan tick 1 detik,
 * supaya simulasi tetap jalan saat Controller di latar belakang. Rute satu
 * titik dipakai untuk "titik diam + jitter". Berhenti sendiri saat rute
 * selesai (kecuali loop).
 */
class RouteService : Service() {
    companion object {
        private const val ACTION_START = "id.replay.mockloc.route.START"
        private const val ACTION_PAUSE = "id.replay.mockloc.route.PAUSE"
        private const val ACTION_RESUME = "id.replay.mockloc.route.RESUME"
        private const val ACTION_STOP = "id.replay.mockloc.route.STOP"
        private const val CHANNEL = "route"
        private const val NOTIF_ID = 42
        private const val TICK_MS = 1000L
        private const val EARTH_RADIUS = 6371008.8

        /** Instance yang sedang jalan; diakses hanya dari main thread. */
        private var instance: RouteService? = null

        /**
         * [spec]: `points` (DoubleArray lat,lng,lat,lng,…), `speedKmh`, `loop`,
         * `accuracy`, `jitter`, opsional `altitude`, `bearing`, `speed` (m/s, titik diam).
         */
        fun start(ctx: Context, spec: Bundle) {
            val intent = Intent(ctx, RouteService::class.java).setAction(ACTION_START).putExtras(spec)
            ContextCompat.startForegroundService(ctx, intent)
        }

        fun pause() = instance?.setPaused(true)
        fun resume() = instance?.setPaused(false)
        fun stop() = instance?.finish("idle")

        fun distance(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Double {
            val dLat = Math.toRadians(lat2 - lat1)
            val dLng = Math.toRadians(lng2 - lng1)
            val a = sin(dLat / 2).let { it * it } +
                cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) * sin(dLng / 2).let { it * it }
            return 2 * EARTH_RADIUS * atan2(sqrt(a), sqrt(1 - a))
        }

        fun bearing(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Double {
            val p1 = Math.toRadians(lat1)
            val p2 = Math.toRadians(lat2)
            val dl = Math.toRadians(lng2 - lng1)
            val y = sin(dl) * cos(p2)
            val x = cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dl)
            return (Math.toDegrees(atan2(y, x)) + 360) % 360
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val random = Random()

    private var lats = DoubleArray(0)
    private var lngs = DoubleArray(0)
    private var cum = DoubleArray(0) // jarak kumulatif per titik, meter
    private var speedKmh = 0.0
    private var loop = false
    private var accuracy = 10.0
    private var jitter = 0.0
    private var altitude: Double? = null
    private var staticBearing: Double? = null
    private var staticSpeed: Double? = null

    private var traveled = 0.0
    private var paused = false
    private var lastTick = 0L

    private val total get() = cum.lastOrNull() ?: 0.0
    private val isStatic get() = total <= 0.0

    private val tick = object : Runnable {
        override fun run() {
            step()
            if (instance === this@RouteService && !paused) handler.postDelayed(this, TICK_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action != ACTION_START && lats.isEmpty()) {
            // Aksi notifikasi yang datang setelah rute selesai.
            stopSelf()
            return START_NOT_STICKY
        }
        when (intent?.action) {
            ACTION_START -> begin(intent)
            ACTION_PAUSE -> setPaused(true)
            ACTION_RESUME -> setPaused(false)
            ACTION_STOP -> finish("idle")
            else -> stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        if (instance === this) instance = null
        super.onDestroy()
    }

    private fun begin(intent: Intent) {
        val pts = intent.getDoubleArrayExtra("points")
        if (pts == null || pts.size < 2) {
            stopSelf()
            return
        }
        val n = pts.size / 2
        lats = DoubleArray(n) { pts[it * 2] }
        lngs = DoubleArray(n) { pts[it * 2 + 1] }
        cum = DoubleArray(n)
        for (i in 1 until n) cum[i] = cum[i - 1] + distance(lats[i - 1], lngs[i - 1], lats[i], lngs[i])

        speedKmh = intent.getDoubleExtra("speedKmh", 40.0)
        loop = intent.getBooleanExtra("loop", false)
        accuracy = intent.getDoubleExtra("accuracy", 10.0)
        jitter = intent.getDoubleExtra("jitter", 0.0)
        altitude = intent.optDouble("altitude")
        staticBearing = intent.optDouble("bearing")
        staticSpeed = intent.optDouble("speed")

        traveled = 0.0
        paused = false
        startInForeground()
        handler.removeCallbacks(tick)
        lastTick = SystemClock.elapsedRealtime()
        emit()
        handler.postDelayed(tick, TICK_MS)
    }

    private fun Intent.optDouble(key: String): Double? =
        if (hasExtra(key)) getDoubleExtra(key, 0.0) else null

    fun setPaused(value: Boolean) {
        if (paused == value) return
        paused = value
        handler.removeCallbacks(tick)
        if (!value) {
            lastTick = SystemClock.elapsedRealtime()
            handler.postDelayed(tick, TICK_MS)
        }
        publishStatus(if (value) "paused" else "running")
        FixStore.notifyChanged(this)
        NotificationManagerCompat.from(this).notifyIfAllowed()
    }

    private fun step() {
        val now = SystemClock.elapsedRealtime()
        traveled += speedKmh / 3.6 * (now - lastTick) / 1000.0
        lastTick = now
        if (!isStatic && traveled >= total) {
            if (loop) {
                traveled %= total
            } else if (SystemMock.isEnabled(this)) {
                // Mode Sistem: aplikasi lain butuh fix terus, jadi diam di titik akhir.
                val lastLat = lats.last()
                val lastLng = lngs.last()
                lats = doubleArrayOf(lastLat)
                lngs = doubleArrayOf(lastLng)
                cum = doubleArrayOf(0.0)
                speedKmh = 0.0
                traveled = 0.0
                staticSpeed = 0.0
                staticBearing = null
            } else {
                traveled = total
                emit(arrived = true)
                finish("finished")
                return
            }
        }
        emit()
    }

    private fun emit(arrived: Boolean = false) {
        var (lat, lng, segBearing) = positionAt(traveled)
        if (jitter > 0) {
            val r = jitter * sqrt(random.nextDouble())
            val theta = 2 * Math.PI * random.nextDouble()
            lat += r * cos(theta) / 111_320.0
            lng += r * sin(theta) / (111_320.0 * cos(Math.toRadians(lat)))
        }
        publishStatus(if (paused) "paused" else "running")
        FixStore.save(
            this,
            Fix(
                lat = lat,
                lng = lng,
                accuracy = accuracy,
                altitude = altitude,
                speed = when {
                    isStatic -> staticSpeed
                    arrived -> 0.0
                    else -> speedKmh / 3.6
                },
                bearing = if (isStatic) staticBearing else segBearing,
            ),
        )
        NotificationManagerCompat.from(this).notifyIfAllowed()
    }

    private fun positionAt(d: Double): Triple<Double, Double, Double?> {
        val n = lats.size
        if (n == 1 || isStatic) return Triple(lats[0], lngs[0], null)
        val idx = Arrays.binarySearch(cum, d)
        val seg = (if (idx >= 0) idx else -idx - 2).coerceIn(0, n - 2)
        val len = cum[seg + 1] - cum[seg]
        val t = if (len > 0) ((d - cum[seg]) / len).coerceIn(0.0, 1.0) else 0.0
        return Triple(
            lats[seg] + (lats[seg + 1] - lats[seg]) * t,
            lngs[seg] + (lngs[seg + 1] - lngs[seg]) * t,
            bearing(lats[seg], lngs[seg], lats[seg + 1], lngs[seg + 1]),
        )
    }

    fun finish(state: String) {
        handler.removeCallbacks(tick)
        if (instance === this) instance = null
        publishStatus(state)
        FixStore.notifyChanged(this)
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun publishStatus(state: String) = FixStore.saveRouteStatus(
        this,
        RouteStatus(state = state, traveled = traveled, total = total, speedKmh = speedKmh, isStatic = isStatic),
    )

    private fun startInForeground() {
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIF_ID, notification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIF_ID, notification())
        }
    }

    private fun NotificationManagerCompat.notifyIfAllowed() {
        if (instance !== this@RouteService || !areNotificationsEnabled()) return
        try {
            notify(NOTIF_ID, notification())
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS ditolak; service tetap jalan.
        }
    }

    private fun notification(): Notification {
        NotificationManagerCompat.from(this).createNotificationChannel(
            NotificationChannelCompat.Builder(CHANNEL, NotificationManagerCompat.IMPORTANCE_LOW)
                .setName("Simulasi rute")
                .build(),
        )
        val flags = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        fun action(action: String, code: Int) = PendingIntent.getService(
            this, code, Intent(this, RouteService::class.java).setAction(action), flags,
        )
        val open = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            flags,
        )
        val text = if (isStatic) {
            "Titik diam, jitter ${jitter.toInt()} m"
        } else {
            "%.2f / %.2f km · %.0f km/j%s".format(traveled / 1000, total / 1000, speedKmh, if (loop) " · loop" else "")
        }
        return NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle(if (paused) "MockLoc: dijeda" else "MockLoc: lokasi simulasi aktif")
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(open)
            .addAction(
                0,
                if (paused) "Lanjut" else "Jeda",
                action(if (paused) ACTION_RESUME else ACTION_PAUSE, 1),
            )
            .addAction(0, "Stop", action(ACTION_STOP, 2))
            .build()
    }
}
