package com.contactflow.contacts

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pending: List<Map<String, Any>> = emptyList()
    private val worker = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "contactflow/incoming").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "take") {
                    result.success(pending)
                    pending = emptyList()
                } else {
                    result.notImplemented()
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "contactflow/device").setMethodCallHandler { call, result ->
            when (call.method) {
                "simCountry" -> {
                    val tm = getSystemService(TELEPHONY_SERVICE) as? TelephonyManager
                    result.success((tm?.simCountryIso ?: "").uppercase())
                }
                "edition" -> result.success(Edition.NAME)
                else -> result.notImplemented()
            }
        }
        Edition.install(this, flutterEngine)
        ingest(intent)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        Edition.onPermissionResult(requestCode, grantResults)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        ingest(intent)
    }

    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
    }

    private fun ingest(intent: Intent?) {
        if (intent == null) return
        if ((intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0) return
        if (intent.getBooleanExtra(CONSUMED, false)) return
        intent.putExtra(CONSUMED, true)
        val text = sharedText(intent)
        if (text != null) {
            deliver(listOf(mapOf("name" to "shared.txt", "bytes" to text.toByteArray())))
            return
        }
        val uris = uriList(intent)
        if (uris.isEmpty()) return
        worker.execute {
            val out = uris.map { copyToCache(it) }
            runOnUiThread { deliver(out) }
        }
    }

    private fun deliver(files: List<Map<String, Any>>) {
        if (files.isEmpty()) return
        pending = pending + files
        channel?.invokeMethod("ready", null)
    }

    private fun sharedText(intent: Intent): String? {
        if (intent.action != Intent.ACTION_SEND) return null
        @Suppress("DEPRECATION")
        val stream = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
        if (stream != null) return null
        val text = intent.getStringExtra(Intent.EXTRA_TEXT)
        return if (text.isNullOrBlank()) null else text
    }

    private fun uriList(intent: Intent): List<Uri> {
        val uris = mutableListOf<Uri>()
        when (intent.action) {
            Intent.ACTION_VIEW -> intent.data?.let { uris.add(it) }
            Intent.ACTION_SEND -> {
                @Suppress("DEPRECATION")
                (intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))?.let { uris.add(it) }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                @Suppress("DEPRECATION")
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris.addAll(it) }
            }
        }
        return uris
    }

    private fun failure(name: String, error: String): Map<String, Any> =
        mapOf("name" to name, "error" to error)

    private fun copyToCache(uri: Uri): Map<String, Any> {
        val name = nameOf(uri)
        val declared = sizeOf(uri)
        if (declared != null && declared > LIMIT) return failure(name, "tooLarge")
        var target: File? = null
        try {
            val dir = File(cacheDir, DIR)
            dir.mkdirs()
            sweep(dir)
            val file = File.createTempFile("in_", ".bin", dir)
            target = file
            val input = contentResolver.openInputStream(uri)
            if (input == null) {
                file.delete()
                return failure(name, "unreadable")
            }
            var total = 0L
            var tooLarge = false
            input.use { src ->
                file.outputStream().use { dst ->
                    val buf = ByteArray(64 * 1024)
                    while (true) {
                        val n = src.read(buf)
                        if (n < 0) break
                        total += n
                        if (total > LIMIT) {
                            tooLarge = true
                            break
                        }
                        dst.write(buf, 0, n)
                    }
                }
            }
            if (tooLarge) {
                file.delete()
                return failure(name, "tooLarge")
            }
            return mapOf("name" to name, "path" to file.absolutePath)
        } catch (_: Exception) {
            target?.delete()
            return failure(name, "unreadable")
        }
    }

    private fun sweep(dir: File) {
        val cutoff = System.currentTimeMillis() - 24L * 60 * 60 * 1000
        dir.listFiles()?.forEach {
            if (it.isFile && it.lastModified() < cutoff) it.delete()
        }
    }

    private fun sizeOf(uri: Uri): Long? {
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { c ->
                if (c.moveToFirst() && !c.isNull(0)) {
                    val n = c.getLong(0)
                    if (n >= 0) return n
                }
            }
        } catch (_: Exception) {
        }
        return null
    }

    private fun nameOf(uri: Uri): String {
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    val n = c.getString(0)
                    if (!n.isNullOrBlank()) return n
                }
            }
        } catch (_: Exception) {
        }
        return uri.lastPathSegment?.substringAfterLast('/') ?: "shared"
    }

    private companion object {
        const val LIMIT = 64L * 1024 * 1024
        const val DIR = "incoming"
        const val CONSUMED = "contactflow.consumed"
    }
}
