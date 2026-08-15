package com.example.call_tracker

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Build
import android.provider.CallLog
import android.telephony.TelephonyManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject

/// The incoming-call engine.
///
/// Everything here runs from a manifest-declared BroadcastReceiver, which means
/// it must work with no Flutter engine, no Activity, and possibly no app process
/// until the broadcast itself created one. So all state lives in its own
/// SharedPreferences file and nothing depends on Dart being alive.
///
/// The shape of an incoming call in PHONE_STATE broadcasts:
///   RINGING -> OFFHOOK -> IDLE   (answered)
///   RINGING -> IDLE              (missed, declined, or rejected)
/// An outgoing call is OFFHOOK -> IDLE with no RINGING, which is exactly how
/// this distinguishes the two: no RINGING seen, not our business.
object IncomingCallStore {
    private const val PREFS = "call_tracker_incoming"
    private const val KEY_SESSION = "session"
    private const val KEY_QUEUE = "queue"
    private const val KEY_STUDENTS = "students"

    private const val CHANNEL_ID = "incoming_calls"
    private const val CHANNEL_NAME = "Incoming calls to log"

    /// A ring that never reached IDLE — process killed mid-call, or a broadcast
    /// the OEM simply never delivered — must not swallow every later call by
    /// leaving a session parked forever.
    private const val SESSION_STALE_MS = 2L * 60L * 60L * 1000L

    /// How old a session may be and still be believed on the strength of this
    /// app's own observation alone.
    ///
    /// Guards the one way this can misfire: a RINGING whose IDLE never arrived
    /// (process killed mid-call) leaves a session parked, and the next OFFHOOK —
    /// which could be an ordinary outgoing call — would otherwise be finished
    /// against it and queued as an incoming call that never happened. A call log
    /// row proves the call was really incoming, so a corroborated session is
    /// trusted at any age; an uncorroborated one only within this window, which
    /// is far longer than any real call and far shorter than a parked session
    /// tends to sit around for.
    private const val CORROBORATION_WINDOW_MS = 30L * 60L * 1000L

    /// The agent may go a long time without opening the app; keep a generous
    /// backlog but never let it grow without bound.
    private const val MAX_QUEUE = 100

    /// The call log row is written when the call disconnects, but not always
    /// before this broadcast lands. Back off and retry rather than concluding
    /// "no record" from a read that was simply too early.
    private val LOG_RETRY_DELAYS_MS = longArrayOf(0, 500, 1000, 2000, 3000)

    private fun prefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    // ---------------------------------------------------------------- state machine

    /// Called for every PHONE_STATE broadcast. Safe to call on a background
    /// thread; the call-log reads inside block.
    fun onPhoneState(context: Context, state: String, extraNumber: String?) {
        val p = prefs(context)
        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> onRinging(p, extraNumber)
            TelephonyManager.EXTRA_STATE_OFFHOOK -> onOffHook(p)
            TelephonyManager.EXTRA_STATE_IDLE -> onIdle(context, p)
        }
    }

    private fun onRinging(p: SharedPreferences, extraNumber: String?) {
        val existing = readSession(p)
        if (existing != null && !isStale(existing)) {
            // Some OEMs fire RINGING more than once, and on a few of them only
            // the later broadcast carries the number. Take it if we lack one,
            // but never restart the session — its startedAt bounds the call-log
            // query, and a second incoming call while one is already in progress
            // (call waiting) belongs to the call already being tracked.
            if (existing.optString("number").isBlank() && !extraNumber.isNullOrBlank()) {
                existing.put("number", extraNumber)
                writeSession(p, existing)
            }
            return
        }
        writeSession(
            p,
            JSONObject()
                .put("startedAt", System.currentTimeMillis())
                .put("number", extraNumber ?: "")
                .put("offhookAt", 0L),
        )
    }

    private fun onOffHook(p: SharedPreferences) {
        // No session means no RINGING was seen, so this is an outgoing call —
        // the outgoing flow owns that, and reconciling it here would double-log.
        val session = readSession(p) ?: return
        if (session.optLong("offhookAt", 0L) != 0L) return
        session.put("offhookAt", System.currentTimeMillis())
        writeSession(p, session)
    }

    private fun onIdle(context: Context, p: SharedPreferences) {
        val session = readSession(p) ?: return
        clearSession(p)
        if (isStale(session)) return
        finish(context, p, session)
    }

    private fun finish(context: Context, p: SharedPreferences, session: JSONObject) {
        val startedAt = session.optLong("startedAt", System.currentTimeMillis())
        val offhookAt = session.optLong("offhookAt", 0L)
        val endedAt = System.currentTimeMillis()
        var number = session.optString("number", "")

        // Locally observed fallback, always available even if the call log can't
        // be read — this is what keeps the feature working when READ_CALL_LOG is
        // refused or the OEM writes the row late.
        var answered = offhookAt > 0L
        var talkSeconds = if (answered) ((endedAt - offhookAt) / 1000L).toInt() else 0
        var source = "device"

        // The call log is ground truth when we can get it, same convention the
        // outgoing flow already follows. It also recovers the number on the many
        // devices where EXTRA_INCOMING_NUMBER comes back null.
        val row = queryIncomingCall(context, startedAt, number)
        if (row != null) {
            val loggedNumber = row.optString("number", "")
            if (number.isBlank() && loggedNumber.isNotBlank()) number = loggedNumber
            talkSeconds = row.optInt("durationSeconds", 0)
            answered = talkSeconds > 0
            source = "call_log"
        } else if (endedAt - startedAt > CORROBORATION_WINDOW_MS) {
            // Nothing in the log backs this up and the session is far too old to
            // have been this call — see CORROBORATION_WINDOW_MS.
            return
        }

        if (talkSeconds < 0) talkSeconds = 0

        val entry = JSONObject()
            .put("id", "${startedAt}_${PhoneNumbers.key(number)}")
            .put("number", number)
            .put("startedAtEpochMs", startedAt)
            .put("endedAtEpochMs", endedAt)
            .put("answered", answered)
            .put("talkDurationSeconds", talkSeconds)
            .put("source", source)

        // A call with no number at all is unattributable — there is no student
        // it could ever resolve to, so queueing it would only ever produce a
        // dead entry the app has to throw away.
        if (PhoneNumbers.key(number).isEmpty()) return

        enqueue(p, entry)

        if (MainActivity.isForeground) {
            // On screen already: route the agent straight to the summary screen.
            // A notification on top of that is just something to dismiss.
            MainActivity.pingIncomingCall()
        } else {
            // Deliberately no ping here even when the app is alive but in the
            // background. Draining the queue would cancel this notification and
            // hide the summary screen behind an app the agent isn't looking at —
            // the prompt is the entire point when he is somewhere else. It stays
            // queued until he actually comes back.
            val student = findCachedStudent(p, number)
            if (student != null) notify(context, entry.getString("id"), student, answered)
        }
    }

    // ---------------------------------------------------------------- call log

    /// Most recent non-outgoing call log row at or after [startedAt], optionally
    /// constrained to [number]. Retried, because the row is written on disconnect
    /// and this broadcast can beat it.
    private fun queryIncomingCall(context: Context, startedAt: Long, number: String): JSONObject? {
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALL_LOG) ==
            PackageManager.PERMISSION_GRANTED
        if (!granted) return null

        for (delay in LOG_RETRY_DELAYS_MS) {
            if (delay > 0) {
                try {
                    Thread.sleep(delay)
                } catch (e: InterruptedException) {
                    Thread.currentThread().interrupt()
                    return null
                }
            }
            val row = readIncomingRow(context, startedAt, number)
            if (row != null) return row
        }
        return null
    }

    private fun readIncomingRow(context: Context, startedAt: Long, number: String): JSONObject? {
        // Clock skew between our timestamp and the provider's is real; a few
        // seconds of slack costs nothing and avoids missing our own row.
        val since = startedAt - 10_000L
        val target = PhoneNumbers.key(number)
        val projection = arrayOf(
            CallLog.Calls.NUMBER,
            CallLog.Calls.TYPE,
            CallLog.Calls.DURATION,
            CallLog.Calls.DATE,
        )
        // 1 INCOMING, 3 MISSED, 5 REJECTED, 6 BLOCKED — literals rather than the
        // constants because REJECTED/BLOCKED were added in later API levels.
        val selection = "${CallLog.Calls.DATE} >= ? AND ${CallLog.Calls.TYPE} IN (1, 3, 5, 6)"
        val args = arrayOf(since.toString())
        val sortOrder = "${CallLog.Calls.DATE} DESC"

        return try {
            context.contentResolver.query(
                CallLog.Calls.CONTENT_URI, projection, selection, args, sortOrder,
            )?.use { cursor ->
                val numberIdx = cursor.getColumnIndexOrThrow(CallLog.Calls.NUMBER)
                val typeIdx = cursor.getColumnIndexOrThrow(CallLog.Calls.TYPE)
                val durationIdx = cursor.getColumnIndexOrThrow(CallLog.Calls.DURATION)
                val dateIdx = cursor.getColumnIndexOrThrow(CallLog.Calls.DATE)
                while (cursor.moveToNext()) {
                    val rowNumber = cursor.getString(numberIdx) ?: ""
                    // With no number from the broadcast, the newest incoming row
                    // since the ring started IS this call — that is the recovery
                    // path for devices that never hand us EXTRA_INCOMING_NUMBER.
                    if (target.isNotEmpty() && !PhoneNumbers.matches(rowNumber, number)) continue
                    return@use JSONObject()
                        .put("number", rowNumber)
                        .put("type", cursor.getInt(typeIdx))
                        .put("durationSeconds", cursor.getLong(durationIdx).toInt())
                        .put("dateEpochMs", cursor.getLong(dateIdx))
                }
                null
            }
        } catch (e: SecurityException) {
            null
        } catch (e: Exception) {
            null
        }
    }

    // ---------------------------------------------------------------- queue

    private fun enqueue(p: SharedPreferences, entry: JSONObject) {
        val queue = readQueue(p)
        val id = entry.optString("id")
        for (i in 0 until queue.length()) {
            // The same call reaching IDLE twice (duplicate broadcast) must not
            // make the agent log it twice.
            if (queue.optJSONObject(i)?.optString("id") == id) return
        }
        queue.put(entry)
        val trimmed = if (queue.length() > MAX_QUEUE) {
            val out = JSONArray()
            for (i in queue.length() - MAX_QUEUE until queue.length()) out.put(queue.get(i))
            out
        } else {
            queue
        }
        p.edit().putString(KEY_QUEUE, trimmed.toString()).apply()
    }

    /// Hands the queued calls to Dart and empties it. Also clears the
    /// notifications for them — the agent is about to be shown the screen those
    /// notifications exist to open.
    fun drain(context: Context): List<Map<String, Any?>> {
        val p = prefs(context)
        val queue = readQueue(p)
        p.edit().remove(KEY_QUEUE).apply()

        val manager = NotificationManagerCompat.from(context)
        val out = ArrayList<Map<String, Any?>>(queue.length())
        for (i in 0 until queue.length()) {
            val o = queue.optJSONObject(i) ?: continue
            val id = o.optString("id")
            if (id.isNotEmpty()) manager.cancel(id.hashCode())
            out.add(
                mapOf(
                    "id" to id,
                    "number" to o.optString("number"),
                    "startedAtEpochMs" to o.optLong("startedAtEpochMs"),
                    "endedAtEpochMs" to o.optLong("endedAtEpochMs"),
                    "answered" to o.optBoolean("answered"),
                    "talkDurationSeconds" to o.optInt("talkDurationSeconds"),
                    "source" to o.optString("source"),
                ),
            )
        }
        return out
    }

    // ---------------------------------------------------------------- student cache

    /// Dart pushes the roster down every time it loads it, so the receiver can
    /// tell a parent calling back from the agent's own dentist without any
    /// network access and without a Flutter engine.
    fun cacheStudents(context: Context, students: List<Map<String, Any?>>) {
        val array = JSONArray()
        for (s in students) {
            array.put(
                JSONObject()
                    .put("id", s["id"] as? String ?: "")
                    .put("name", s["name"] as? String ?: "")
                    .put("phone", s["phone"] as? String ?: "")
                    .put("level", s["level"] as? String ?: "")
                    .put("parentName", s["parentName"] as? String ?: "")
                    .put("studentId", s["studentId"] as? String ?: ""),
            )
        }
        prefs(context).edit().putString(KEY_STUDENTS, array.toString()).apply()
    }

    fun cachedStudents(context: Context): List<Map<String, Any?>> {
        val array = readArray(prefs(context), KEY_STUDENTS)
        val out = ArrayList<Map<String, Any?>>(array.length())
        for (i in 0 until array.length()) {
            val o = array.optJSONObject(i) ?: continue
            out.add(
                mapOf(
                    "id" to o.optString("id"),
                    "name" to o.optString("name"),
                    "phone" to o.optString("phone"),
                    "level" to o.optString("level"),
                    "parentName" to o.optString("parentName"),
                    "studentId" to o.optString("studentId"),
                ),
            )
        }
        return out
    }

    private fun findCachedStudent(p: SharedPreferences, number: String): JSONObject? {
        val array = readArray(p, KEY_STUDENTS)
        for (i in 0 until array.length()) {
            val o = array.optJSONObject(i) ?: continue
            if (PhoneNumbers.matches(o.optString("phone"), number)) return o
        }
        return null
    }

    // ---------------------------------------------------------------- notification

    private fun notify(context: Context, entryId: String, student: JSONObject, answered: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
            if (!granted) return
        }

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH)
            channel.description = "Reminds you to record a call a parent made to you."
            manager.createNotificationChannel(channel)
        }

        val name = student.optString("name").ifBlank { "a parent" }
        val parent = student.optString("parentName")
        val title = if (answered) "Call from $name" else "Missed call from $name"
        val body = if (parent.isBlank()) {
            "Tap to record how the call went."
        } else {
            "$parent — tap to record how the call went."
        }

        val launch = Intent(context, MainActivity::class.java).setFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP,
        )
        val notifyId = entryId.hashCode()
        val pending = PendingIntent.getActivity(
            context,
            notifyId,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.sym_action_call)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()

        try {
            manager.notify(notifyId, notification)
        } catch (e: SecurityException) {
            // Notifications refused at the OS level — the queued entry still
            // surfaces the next time the agent opens the app.
        }
    }

    // ---------------------------------------------------------------- json helpers

    private fun readSession(p: SharedPreferences): JSONObject? {
        val raw = p.getString(KEY_SESSION, null) ?: return null
        return try {
            JSONObject(raw)
        } catch (e: Exception) {
            null
        }
    }

    private fun writeSession(p: SharedPreferences, session: JSONObject) {
        // commit(), not apply(): the process hosting a receiver can be killed the
        // instant onReceive returns, and a lost RINGING turns the whole call into
        // an outgoing one as far as the state machine is concerned.
        p.edit().putString(KEY_SESSION, session.toString()).commit()
    }

    private fun clearSession(p: SharedPreferences) {
        p.edit().remove(KEY_SESSION).commit()
    }

    private fun isStale(session: JSONObject): Boolean =
        System.currentTimeMillis() - session.optLong("startedAt", 0L) > SESSION_STALE_MS

    private fun readQueue(p: SharedPreferences): JSONArray = readArray(p, KEY_QUEUE)

    private fun readArray(p: SharedPreferences, key: String): JSONArray {
        val raw = p.getString(key, null) ?: return JSONArray()
        return try {
            JSONArray(raw)
        } catch (e: Exception) {
            JSONArray()
        }
    }
}
