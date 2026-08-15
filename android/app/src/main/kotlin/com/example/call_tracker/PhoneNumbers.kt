package com.example.call_tracker

/// Numbers arrive in three different shapes for the same person: as the agent
/// typed it on the backend ("0612345678"), as the network reports an incoming
/// call ("+212612345678") and as the call log stores it. Comparing the last
/// nine digits is what makes those three match.
///
/// A false match between two distinct local numbers sharing that suffix is the
/// known ceiling of this heuristic — same trade-off the outgoing call-log query
/// already makes, kept identical on purpose so both directions behave the same.
object PhoneNumbers {
    fun key(raw: String?): String {
        if (raw.isNullOrBlank()) return ""
        return raw.filter { it.isDigit() }.takeLast(9)
    }

    fun matches(a: String?, b: String?): Boolean {
        val ka = key(a)
        val kb = key(b)
        return ka.isNotEmpty() && ka == kb
    }
}
