package com.example.call_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager

/// Declared in the manifest rather than registered at runtime, so Android starts
/// the process and delivers the broadcast even when the app has been swiped away
/// or was never opened since boot. PHONE_STATE is one of the implicit broadcasts
/// still exempt from the Android 8+ manifest-receiver ban, which is what makes
/// this work at all.
class IncomingCallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return
        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        // Null on most devices from Android 9 onwards even with READ_CALL_LOG
        // granted; the call log lookup in the store is the real number source and
        // this is only an optimisation when the OEM does provide it.
        val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)

        // onReceive runs on the main thread and the store waits on the call log
        // provider, so hold the broadcast open and do the work off-thread.
        val pending = goAsync()
        val app = context.applicationContext
        Thread {
            try {
                IncomingCallStore.onPhoneState(app, state, number)
            } catch (e: Throwable) {
                // Never let a bad call log row or a malformed cache crash the
                // agent's phone — a dropped call is recoverable, a crash loop on
                // every incoming call is not.
            } finally {
                pending.finish()
            }
        }.start()
    }
}
