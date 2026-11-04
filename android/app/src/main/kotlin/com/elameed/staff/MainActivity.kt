package com.elameed.staff

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.CallLog
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "call_tracker/native_call"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "placeCall" -> placeCall(call.argument<String>("number"), result)
                "isCallActive" -> isCallActive(result)
                "queryCallSince" -> queryCallSince(
                    call.argument<String>("number"),
                    call.argument<Long>("sinceEpochMs") ?: 0L,
                    result,
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun placeCall(number: String?, result: MethodChannel.Result) {
        if (number.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "number is required", null)
            return
        }
        val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            result.error("PERMISSION_DENIED", "CALL_PHONE not granted", null)
            return
        }
        try {
            val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$number"))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("CALL_FAILED", e.message, null)
        }
    }

    /// True while the device is ringing or off-hook. Android only writes the
    /// CallLog entry when a call disconnects, so reconciling before this goes
    /// false always looks like "no call was ever placed".
    private fun isCallActive(result: MethodChannel.Result) {
        try {
            val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            @Suppress("DEPRECATION")
            result.success(tm.callState != TelephonyManager.CALL_STATE_IDLE)
        } catch (e: SecurityException) {
            // No READ_PHONE_STATE — report idle rather than blocking reconcile forever.
            result.success(false)
        }
    }

    private fun queryCallSince(number: String?, sinceEpochMs: Long, result: MethodChannel.Result) {
        if (number.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "number is required", null)
            return
        }
        val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            result.error("PERMISSION_DENIED", "READ_CALL_LOG not granted", null)
            return
        }

        // ponytail: matches by last-9-digit subscriber number to tolerate +country-code /
        // formatting differences between the log and our stored numbers; a false match across
        // two distinct local numbers sharing that suffix is the known ceiling of this heuristic.
        val target = number.filter { it.isDigit() }.takeLast(9)
        val projection = arrayOf(CallLog.Calls.NUMBER, CallLog.Calls.TYPE, CallLog.Calls.DURATION, CallLog.Calls.DATE)
        val selection = "${CallLog.Calls.DATE} >= ?"
        val selectionArgs = arrayOf(sinceEpochMs.toString())
        val sortOrder = "${CallLog.Calls.DATE} DESC"

        contentResolver.query(CallLog.Calls.CONTENT_URI, projection, selection, selectionArgs, sortOrder)?.use { cursor ->
            val numberIdx = cursor.getColumnIndexOrThrow(CallLog.Calls.NUMBER)
            val typeIdx = cursor.getColumnIndexOrThrow(CallLog.Calls.TYPE)
            val durationIdx = cursor.getColumnIndexOrThrow(CallLog.Calls.DURATION)
            val dateIdx = cursor.getColumnIndexOrThrow(CallLog.Calls.DATE)
            while (cursor.moveToNext()) {
                val rawNumber = cursor.getString(numberIdx) ?: continue
                val candidate = rawNumber.filter { it.isDigit() }.takeLast(9)
                if (target.isNotEmpty() && candidate == target) {
                    result.success(
                        mapOf(
                            "found" to true,
                            "type" to cursor.getInt(typeIdx),
                            "durationSeconds" to cursor.getLong(durationIdx).toInt(),
                            "dateEpochMs" to cursor.getLong(dateIdx),
                        ),
                    )
                    return
                }
            }
        }
        result.success(mapOf("found" to false, "type" to null, "durationSeconds" to null, "dateEpochMs" to null))
    }
}
