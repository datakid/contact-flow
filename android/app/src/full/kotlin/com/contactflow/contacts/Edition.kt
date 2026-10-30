package com.contactflow.contacts

import android.app.Activity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object Edition {
    const val NAME = "full"

    private var reader: CallsReader? = null

    fun install(activity: Activity, engine: FlutterEngine) {
        val r = CallsReader(activity)
        reader = r
        MethodChannel(engine.dartExecutor.binaryMessenger, "contactflow/calls").setMethodCallHandler { call, result ->
            r.handle(call, result)
        }
    }

    fun onPermissionResult(requestCode: Int, grantResults: IntArray) {
        reader?.onPermissionResult(requestCode, grantResults)
    }
}
