package com.contactflow.contacts

import android.Manifest
import android.app.Activity
import android.content.ContentResolver
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.CallLog
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class CallsReader(private val activity: Activity) {
    private val worker = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(granted())
            "request" -> request(result)
            "read" -> read(
                call.argument<Number>("before")?.toLong(),
                call.argument<Int>("size") ?: PAGE,
                result,
            )
            else -> result.notImplemented()
        }
    }

    private fun granted(): Boolean =
        activity.checkSelfPermission(Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED

    private fun request(result: MethodChannel.Result) {
        if (granted()) {
            result.success(true)
            return
        }
        pending?.success(false)
        pending = result
        activity.requestPermissions(arrayOf(Manifest.permission.READ_CALL_LOG), REQUEST)
    }

    fun onPermissionResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST) return
        val ok = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        pending?.success(ok)
        pending = null
    }

    private fun read(before: Long?, size: Int, result: MethodChannel.Result) {
        worker.execute {
            val out = ArrayList<Map<String, Any?>>()
            try {
                val selection = if (before != null) "${CallLog.Calls.DATE} < ?" else null
                val args = if (before != null) arrayOf(before.toString()) else null
                val projection = arrayOf(
                    CallLog.Calls.NUMBER,
                    CallLog.Calls.DATE,
                    CallLog.Calls.DURATION,
                    CallLog.Calls.TYPE,
                    CallLog.Calls.CACHED_NAME,
                    CallLog.Calls.NUMBER_PRESENTATION,
                    CallLog.Calls.PHONE_ACCOUNT_ID,
                )
                val resolver = activity.contentResolver
                val cursor = if (Build.VERSION.SDK_INT >= 26) {
                    val query = Bundle().apply {
                        putString(ContentResolver.QUERY_ARG_SQL_SELECTION, selection)
                        putStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, args)
                        putString(ContentResolver.QUERY_ARG_SQL_SORT_ORDER, "${CallLog.Calls.DATE} DESC")
                        putInt(ContentResolver.QUERY_ARG_LIMIT, size)
                    }
                    resolver.query(CallLog.Calls.CONTENT_URI, projection, query, null)
                } else {
                    resolver.query(
                        CallLog.Calls.CONTENT_URI,
                        projection,
                        selection,
                        args,
                        "${CallLog.Calls.DATE} DESC LIMIT $size",
                    )
                }
                cursor?.use { c ->
                    while (c.moveToNext()) {
                        out.add(
                            mapOf(
                                "number" to (c.getString(0) ?: ""),
                                "date" to c.getLong(1),
                                "duration" to c.getLong(2),
                                "type" to c.getInt(3),
                                "name" to (c.getString(4) ?: ""),
                                "presentation" to c.getInt(5),
                                "account" to (c.getString(6) ?: ""),
                            ),
                        )
                    }
                }
                activity.runOnUiThread { result.success(out) }
            } catch (e: SecurityException) {
                activity.runOnUiThread { result.error("denied", e.message, null) }
            } catch (e: Exception) {
                activity.runOnUiThread { result.error("failed", e.message, null) }
            }
        }
    }

    private companion object {
        const val PAGE = 2000
        const val REQUEST = 4207
    }
}
