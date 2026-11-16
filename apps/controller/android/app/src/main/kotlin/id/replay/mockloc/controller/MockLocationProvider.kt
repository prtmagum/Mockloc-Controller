package id.replay.mockloc.controller

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri

/**
 * Membagikan fix terakhir ke aplikasi target (flavor dev). Dilindungi izin
 * `signature` di manifest, plus allowlist package opsional (FR-11).
 */
class MockLocationProvider : ContentProvider() {
    companion object {
        const val AUTHORITY = "id.replay.mockloc.provider"
        val URI: Uri = Uri.parse("content://$AUTHORITY/location")
    }

    override fun onCreate() = true

    override fun query(
        uri: Uri, projection: Array<String>?, selection: String?,
        args: Array<String>?, sort: String?,
    ): Cursor {
        val ctx = context!!
        val allow = FixStore.allowlist(ctx)
        val caller = callingPackage
        if (allow.isNotEmpty() && caller != ctx.packageName && caller !in allow) {
            throw SecurityException("$caller tidak ada di allowlist MockLoc")
        }
        return MatrixCursor(Fix.COLUMNS).apply {
            FixStore.load(ctx)?.let { addRow(it.toRow()) }
        }
    }

    override fun getType(uri: Uri): String? = null
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun update(uri: Uri, v: ContentValues?, s: String?, a: Array<String>?) = 0
    override fun delete(uri: Uri, s: String?, a: Array<String>?) = 0
}
