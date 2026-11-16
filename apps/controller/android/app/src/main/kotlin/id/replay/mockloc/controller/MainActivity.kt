package id.replay.mockloc.controller

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var observer: ContentObserver? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        val messenger = engine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "mockloc/control").setMethodCallHandler(::onCall)
        EventChannel(messenger, "mockloc/state").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                val emit = { sink.success(snapshot()) }
                observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
                    override fun onChange(selfChange: Boolean) = emit()
                }.also { contentResolver.registerContentObserver(MockLocationProvider.URI, false, it) }
                emit()
            }

            override fun onCancel(args: Any?) {
                observer?.let(contentResolver::unregisterContentObserver)
                observer = null
            }
        })
    }

    private fun snapshot(): Map<String, Any?> = mapOf(
        "fix" to FixStore.load(this)?.toMap(),
        "route" to FixStore.routeStatus(this).toMap(),
    )

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setFix" -> {
                val fix = Fix(
                    lat = call.argument<Double>("lat"),
                    lng = call.argument<Double>("lng"),
                    accuracy = call.argument<Double>("accuracy") ?: 10.0,
                    altitude = call.argument<Double>("altitude"),
                    speed = call.argument<Double>("speed"),
                    bearing = call.argument<Double>("bearing"),
                )
                if (SystemMock.isEnabled(this) && fix.lat != null && fix.lng != null) {
                    // Aplikasi lain butuh fix tiap detik; titik diam diputar oleh RouteService.
                    startStatic(fix)
                } else {
                    RouteService.stop()
                    FixStore.save(this, fix)
                }
                result.success(null)
            }
            "systemStatus" -> result.success(SystemMock.status(this))
            "setSystemMock" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                if (enabled && !SystemMock.hasLocationPermission(this)) {
                    // Hanya untuk API mock Google Play Services; Controller tidak membaca lokasi.
                    requestPermissions(
                        arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
                        2,
                    )
                }
                SystemMock.setEnabled(this, enabled)
                val route = FixStore.routeStatus(this)
                val routePlaying = route.state in listOf("running", "paused") && !route.isStatic
                // Rute yang sedang jalan sudah mengirim fix tiap detik; jangan diganti.
                if (!routePlaying) {
                    FixStore.load(this)?.takeIf { it.lat != null && it.lng != null }?.let {
                        if (enabled) {
                            startStatic(it)
                        } else {
                            RouteService.stop()
                            FixStore.save(this, it.copy(time = System.currentTimeMillis()))
                        }
                    }
                }
                result.success(SystemMock.status(this))
            }
            "grantViaRoot" -> Thread {
                val error = SystemMock.grantViaRoot(this)
                runOnUiThread { result.success(error) }
            }.start()
            "openUrl" -> result.success(
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("url"))))
                    true
                } catch (_: Exception) {
                    false
                },
            )
            "appVersion" -> result.success(packageManager.getPackageInfo(packageName, 0).versionName)
            "openDevSettings" -> {
                val opened = listOf(
                    Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS,
                    Settings.ACTION_DEVICE_INFO_SETTINGS,
                ).any { action ->
                    try {
                        startActivity(Intent(action))
                        true
                    } catch (_: Exception) {
                        false
                    }
                }
                result.success(opened)
            }
            "setError" -> {
                RouteService.stop()
                FixStore.save(this, Fix(error = call.argument<String>("code")))
                result.success(null)
            }
            "clear" -> {
                RouteService.stop()
                FixStore.clear(this)
                result.success(null)
            }
            "startRoute" -> {
                requestNotificationPermission()
                val spec = Bundle().apply {
                    putDoubleArray("points", call.argument<DoubleArray>("points"))
                    putDouble("speedKmh", call.argument<Double>("speedKmh") ?: 40.0)
                    putBoolean("loop", call.argument<Boolean>("loop") ?: false)
                    putDouble("accuracy", call.argument<Double>("accuracy") ?: 10.0)
                    putDouble("jitter", call.argument<Double>("jitter") ?: 0.0)
                    for (key in listOf("altitude", "bearing", "speed")) {
                        call.argument<Double>(key)?.let { putDouble(key, it) }
                    }
                }
                RouteService.start(this, spec)
                result.success(null)
            }
            "pauseRoute", "resumeRoute", "stopRoute" -> {
                when (call.method) {
                    "pauseRoute" -> RouteService.pause()
                    "resumeRoute" -> RouteService.resume()
                    else -> RouteService.stop()
                }
                result.success(null)
            }
            "history" -> result.success(FixStore.historyCsv(this))
            "clearHistory" -> {
                FixStore.clearHistory(this)
                result.success(null)
            }
            "getAllowlist" -> result.success(FixStore.allowlist(this).sorted())
            "setAllowlist" -> {
                FixStore.setAllowlist(this, call.argument<List<String>>("packages").orEmpty().toSet())
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startStatic(fix: Fix) {
        requestNotificationPermission()
        RouteService.start(this, Bundle().apply {
            putDoubleArray("points", doubleArrayOf(fix.lat!!, fix.lng!!))
            putDouble("speedKmh", 0.0)
            putBoolean("loop", true)
            putDouble("accuracy", fix.accuracy ?: 10.0)
            putDouble("jitter", 0.0)
            fix.altitude?.let { putDouble("altitude", it) }
            fix.bearing?.let { putDouble("bearing", it) }
            fix.speed?.let { putDouble("speed", it) }
        })
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        }
    }
}
