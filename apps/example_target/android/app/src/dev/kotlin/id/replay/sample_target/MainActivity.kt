package id.replay.sample_target

import android.database.ContentObserver
import android.database.Cursor
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

/**
 * Flavor dev saja: meneruskan fix dari ContentProvider Controller ke
 * `ControllerLocationSource` lewat EventChannel. ContentObserver membuat
 * jedanya < 1 detik tanpa polling.
 */
class MainActivity : FlutterActivity() {
    private val uri = Uri.parse("content://id.replay.mockloc.provider/location")
    private var observer: ContentObserver? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        EventChannel(engine.dartExecutor.binaryMessenger, "mock_location_kit/fixes")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                    val emit = { sink.success(readFix()) }
                    observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
                        override fun onChange(selfChange: Boolean) = emit()
                    }.also { contentResolver.registerContentObserver(uri, false, it) }
                    emit()
                }

                override fun onCancel(args: Any?) {
                    observer?.let(contentResolver::unregisterContentObserver)
                    observer = null
                }
            })
    }

    override fun onDestroy() {
        observer?.let(contentResolver::unregisterContentObserver)
        observer = null
        super.onDestroy()
    }

    /** Satu baris dari provider, atau `{error: ...}` kalau tidak bisa dibaca. */
    private fun readFix(): Map<String, Any?> = try {
        contentResolver.query(uri, null, null, null, null)?.use { c ->
            if (!c.moveToFirst()) return@use mapOf("error" to "no_fix")
            (0 until c.columnCount).associate { i ->
                c.getColumnName(i) to when (c.getType(i)) {
                    Cursor.FIELD_TYPE_INTEGER -> c.getLong(i)
                    Cursor.FIELD_TYPE_FLOAT -> c.getDouble(i)
                    Cursor.FIELD_TYPE_NULL -> null
                    else -> c.getString(i)
                }
            }
        } ?: mapOf("error" to "controller_unavailable") // Controller belum terpasang.
    } catch (e: SecurityException) {
        // Tanda tangan APK beda dengan Controller, atau package tidak ada di allowlist.
        mapOf("error" to if (e.message?.contains("allowlist") == true) "not_allowed" else "controller_unavailable")
    }
}
