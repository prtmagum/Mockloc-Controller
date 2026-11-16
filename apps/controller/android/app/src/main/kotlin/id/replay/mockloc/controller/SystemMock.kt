package id.replay.mockloc.controller

import android.Manifest
import android.annotation.SuppressLint
import android.app.AppOpsManager
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.Process
import android.os.SystemClock
import android.provider.Settings
import androidx.core.content.ContextCompat
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import java.util.concurrent.TimeUnit

/**
 * Mode Sistem (opsional): fix yang sama juga dikirim ke provider lokasi
 * Android lewat API mock resmi, sehingga Google Maps dan aplikasi lain ikut
 * melihatnya. Syaratnya MockLoc dipilih sebagai "aplikasi lokasi palsu" di
 * Opsi Pengembang, atau izin AppOps `mock_location` diberikan lewat root.
 * Android tetap menandai lokasi ini sebagai mock (`Location.isMock`).
 */
object SystemMock {
    private const val PREFS = "mockloc_system"
    private const val KEY_ENABLED = "enabled"

    private var installed = false
    private var gmsMockMode = false
    private var lastError: String? = null

    private val providers: List<String>
        get() = buildList {
            add(LocationManager.GPS_PROVIDER)
            add(LocationManager.NETWORK_PROVIDER)
            if (Build.VERSION.SDK_INT >= 31) add(LocationManager.FUSED_PROVIDER)
        }

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun isEnabled(ctx: Context) = prefs(ctx).getBoolean(KEY_ENABLED, false)

    fun setEnabled(ctx: Context, enabled: Boolean) {
        prefs(ctx).edit().putBoolean(KEY_ENABLED, enabled).apply()
        if (!enabled) release(ctx)
    }

    fun status(ctx: Context): Map<String, Any?> = mapOf(
        "enabled" to isEnabled(ctx),
        "active" to installed,
        "devOptions" to (Settings.Global.getInt(
            ctx.contentResolver, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0,
        ) == 1),
        "mockApp" to isMockApp(ctx),
        "locationPermission" to hasLocationPermission(ctx),
        "playServices" to hasPlayServices(ctx),
        "lastError" to lastError,
    )

    fun isMockApp(ctx: Context): Boolean = try {
        val ops = ctx.getSystemService(AppOpsManager::class.java)
        val mode = if (Build.VERSION.SDK_INT >= 29) {
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_MOCK_LOCATION, Process.myUid(), ctx.packageName)
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(AppOpsManager.OPSTR_MOCK_LOCATION, Process.myUid(), ctx.packageName)
        }
        mode == AppOpsManager.MODE_ALLOWED
    } catch (_: Exception) {
        false
    }

    fun hasLocationPermission(ctx: Context) =
        ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    private fun hasPlayServices(ctx: Context) =
        GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(ctx) == ConnectionResult.SUCCESS

    /**
     * HP root: beri izin AppOps `mock_location` tanpa membuka Opsi Pengembang.
     * Mengembalikan null kalau berhasil, atau pesan error.
     */
    fun grantViaRoot(ctx: Context): String? = try {
        val cmd = "appops set ${ctx.packageName} android:mock_location allow"
        val p = ProcessBuilder("su", "-c", cmd).redirectErrorStream(true).start()
        val output = p.inputStream.bufferedReader().readText().trim()
        when {
            !p.waitFor(15, TimeUnit.SECONDS) -> "su tidak merespons (izin root ditolak?)"
            p.exitValue() != 0 -> "su gagal (kode ${p.exitValue()}): $output"
            !isMockApp(ctx) -> "Perintah jalan tapi izin belum aktif: $output"
            else -> null
        }
    } catch (e: Exception) {
        "HP tidak di-root atau su tidak ditemukan (${e.message})"
    }

    /** Dipanggil untuk setiap fix/skenario yang dibagikan (lihat [FixStore.save]). */
    fun push(ctx: Context, fix: Fix) {
        if (!isEnabled(ctx)) return
        val lm = ctx.getSystemService(LocationManager::class.java)
        try {
            when {
                fix.error == "service_disabled" -> {
                    install(lm)
                    providers.forEach { lm.setTestProviderEnabled(it, false) }
                }
                fix.lat == null || fix.lng == null -> return
                else -> {
                    install(lm)
                    for (p in providers) {
                        lm.setTestProviderEnabled(p, true)
                        lm.setTestProviderLocation(p, fix.toLocation(p))
                    }
                    pushToPlayServices(ctx, fix)
                }
            }
            lastError = null
        } catch (e: SecurityException) {
            installed = false
            lastError = "MockLoc belum dipilih sebagai aplikasi lokasi palsu"
        } catch (e: IllegalArgumentException) {
            lastError = "Provider ditolak sistem: ${e.message}"
        }
    }

    private fun install(lm: LocationManager) {
        if (installed) return
        for (p in providers) {
            try {
                lm.removeTestProvider(p)
            } catch (_: Exception) {
                // Belum terpasang.
            }
            // Argumen terakhir: POWER_USAGE_LOW = 1, ACCURACY_FINE = 1.
            lm.addTestProvider(p, false, false, false, false, true, true, true, 1, 1)
            lm.setTestProviderEnabled(p, true)
        }
        installed = true
    }

    /**
     * Google Maps membaca lokasi dari fused provider Google Play Services, yang
     * juga memakai Wi-Fi/seluler asli. Mock mode membuatnya hanya memakai fix kita.
     */
    @SuppressLint("MissingPermission")
    private fun pushToPlayServices(ctx: Context, fix: Fix) {
        if (!hasLocationPermission(ctx) || !hasPlayServices(ctx)) return
        val client: FusedLocationProviderClient = LocationServices.getFusedLocationProviderClient(ctx)
        if (!gmsMockMode) {
            client.setMockMode(true).addOnFailureListener { lastError = "Play Services: ${it.message}" }
            gmsMockMode = true
        }
        client.setMockLocation(fix.toLocation("fused"))
            .addOnFailureListener { lastError = "Play Services: ${it.message}" }
    }

    /** Lepas semua provider mock; lokasi asli kembali dipakai. */
    @SuppressLint("MissingPermission")
    fun release(ctx: Context) {
        val lm = ctx.getSystemService(LocationManager::class.java)
        for (p in providers) {
            try {
                lm.removeTestProvider(p)
            } catch (_: Exception) {
                // Belum terpasang atau izin sudah dicabut.
            }
        }
        installed = false
        if (gmsMockMode && hasLocationPermission(ctx) && hasPlayServices(ctx)) {
            LocationServices.getFusedLocationProviderClient(ctx).setMockMode(false)
        }
        gmsMockMode = false
    }

    private fun Fix.toLocation(provider: String) = Location(provider).also { l ->
        l.latitude = lat!!
        l.longitude = lng!!
        l.accuracy = (accuracy ?: 10.0).toFloat()
        altitude?.let { l.altitude = it }
        speed?.let { l.speed = it.toFloat() }
        bearing?.let { l.bearing = it.toFloat() }
        l.time = System.currentTimeMillis()
        l.elapsedRealtimeNanos = SystemClock.elapsedRealtimeNanos()
        if (Build.VERSION.SDK_INT >= 26) {
            l.verticalAccuracyMeters = 5f
            l.speedAccuracyMetersPerSecond = 0.5f
            l.bearingAccuracyDegrees = 5f
        }
    }
}
