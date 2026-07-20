# Call Tracker — API Requirements

This document specifies the backend API the Call Tracker mobile app needs. It's written from the app's current (working, tested) client-side logic, so every field below is something the app can already produce — nothing here is speculative.

## 1. Context — what this app is for

Call center agents at a language institute use this app to call parents/students about payments, absences, sessions, etc. The app places the call directly (Android `ACTION_CALL`, no dialer screen the agent could dodge), then independently verifies what actually happened using Android's own call log and telephony state — **not** anything the agent claims. Both the agent's self-reported outcome and the objective verification are sent to the backend so a supervisor can spot agents who mark a call as "Interested" when the call log shows it was never even answered.

Everything below currently runs against local dummy data / on-device storage (`shared_preferences`) because there is no backend yet. Each section notes exactly what needs to move server-side.

## 2. Authentication

Agents don't self-register. A supervisor creates agent accounts from the (separate) web dashboard; the app only ever logs an existing agent in.

### `POST /api/auth/login`

Request:
```json
{
  "email": "sara.amrani@institute.dz",
  "password": "agent123"
}
```

Response `200 OK`:
```json
{
  "token": "eyJhbGciOi...",
  "agent": {
    "id": "a1",
    "name": "Sara Amrani",
    "email": "sara.amrani@institute.dz"
  }
}
```

Response `401 Unauthorized` (wrong email/password):
```json
{ "error": "Invalid email or password" }
```

- **Token type**: JWT or opaque session token, backend's choice — the app just stores whatever string comes back and sends it as `Authorization: Bearer <token>` on every subsequent request. Suggest a **~30 day expiry**; the app should treat any `401` on any endpoint as "session expired" and force the agent back to the login screen.
- **Password requirements**: none enforced client-side today (accounts are created by a supervisor, not self-service) — whatever the backend/dashboard enforces at creation time is fine.
- The app currently validates against a local hardcoded list of two test accounts (`lib/data/auth_service.dart`, `lib/data/dummy_data.dart`) purely as a stand-in so the rest of the team isn't blocked. **This must never be treated as the real auth mechanism** — it does no hashing, no server round-trip, nothing. Swapping in the real call is a one-function change once this endpoint exists.

### `POST /api/auth/logout` (recommended, not yet wired up)

Headers: `Authorization: Bearer <token>`, empty body.
Response: `204 No Content`. Invalidates the token server-side (the app already clears its local session on logout regardless).

### Open question for backend
JWT vs. opaque token, and exact expiry — the app is agnostic, pick whichever fits the rest of your stack.

## 3. Reference data the app will need

Currently 100% local dummy data (`lib/data/dummy_data.dart`) — not blocking the call-submission work below, but the app can't go live without these existing server-side eventually:

### `GET /api/students`
Returns the list of students/parents an agent can call.
```json
[
  {
    "id": "7",
    "name": "Amine Chaalal",
    "phone": "+213555123456",
    "level": "B2",
    "parentName": "Kamel Chaalal",
    "studentId": "#LI-2024-882"
  }
]
```
| Field | Type | Notes |
|---|---|---|
| `id` | string | Internal id, used everywhere else to reference this student |
| `name` | string | Student's name |
| `phone` | string | Parent's phone number, used to place the call and to verify it against the call log |
| `level` | string | e.g. `A1`, `B2` — used for the level filter in the student list |
| `parentName` | string | Shown on the call screen |
| `studentId` | string | Human-facing display code (e.g. `#LI-2024-882`), distinct from `id` |

### `GET /api/groups`
```json
[
  { "name": "Bourhane B2", "studentCount": 12, "studentIds": ["5", "7"] }
]
```
`studentCount` is shown directly in the UI and does **not** need to equal `studentIds.length` — groups can be large with only a subset of members individually browsable/callable in the app today. Confirm with backend whether `studentCount` should just become `studentIds.length` once real data backs it, or stay independent (e.g. some students in a group aren't in the callable roster).

## 4. Call submission — the core of this document

### `POST /api/calls`

Called once, right after the agent taps **"Save and Finish"** on the call summary screen. One request per completed call.

Headers: `Authorization: Bearer <token>`

Request body:
```json
{
  "studentId": "7",
  "studentName": "Amine Chaalal",
  "reason": "paymentInquiry",
  "outcome": "interested",
  "notes": "Parent asked for a payment extension until next week.",
  "reallyDialed": true,
  "talkDurationSeconds": 92,
  "ringSessionSeconds": 6,
  "likelyHungUpEarly": false,
  "endedQuickly": false,
  "finalResult": "Agent called, call was answered, talked for 1min 32s",
  "startedAtEpochMs": 1732650000000,
  "endedAtEpochMs": 1732650096000
}
```

**Every field is produced by `CallRecord` in `lib/data/models.dart` — this is the exact shape of `CallRecord.toJson()`.**

| Field | Type | Always present? | Meaning |
|---|---|---|---|
| `studentId` | string | yes | Which student/parent was called — matches `GET /api/students[].id` |
| `studentName` | string | yes | Denormalized copy of the student's name at call time, so history reads correctly even if the student record changes later |
| `reason` | string enum | yes | Why the agent placed the call — see §4.1 |
| `outcome` | string enum \| `null` | no | What the agent says happened — see §4.2. `null` if the agent didn't pick one before saving |
| `notes` | string \| `null` | no | Agent's free-text note. `null`/omitted if empty — the app only sends it when non-blank |
| `reallyDialed` | boolean | yes | **`false` means the call log shows this number was never actually dialed on the device** — the strongest possible "agent didn't call" signal |
| `talkDurationSeconds` | integer | yes | Seconds actually connected/talking, from the **call log** (authoritative), not a client-side timer. `0` if never answered |
| `ringSessionSeconds` | integer \| `null` | no | Seconds the device was in an active call session (dial → hang-up), timed locally on-device via telephony state — **not** from the call log. `null` when this couldn't be observed (see §5.2) |
| `likelyHungUpEarly` | boolean | yes | `true` when `talkDurationSeconds` is 0 **and** `ringSessionSeconds` was under ~3s — too short to have possibly rung, so the agent almost certainly cancelled before it even reached the parent |
| `endedQuickly` | boolean | yes | `true` for the ambiguous 3–8s zone: might have rung once briefly. Could be the parent declining fast, or the agent hanging up early — **the app deliberately does not claim to know which** (see §6) |
| `finalResult` | string | yes | Ready-made short phrase describing what happened, e.g. *"Agent called, call was answered, talked for 1min 32s"* — see §4.3 for the exact phrase set. Convenience field: safe to just display as-is, but backend should be able to derive the same categories independently (see §4.4) for filtering/reporting |
| `startedAtEpochMs` | integer (epoch ms) | yes | When the agent tapped "Start Call" |
| `endedAtEpochMs` | integer (epoch ms) | yes | When the call was reconciled as finished (see §5.1 for why this can be much later than the actual call) |

Response `201 Created` — echo the submitted record plus server-assigned fields:
```json
{
  "id": "generated-id",
  "agentId": "a1",
  "agentName": "Sara Amrani",
  "createdAt": "2026-07-20T14:32:10Z",
  "...": "...rest of the submitted fields"
}
```

**`agentId`/`agentName` come from the authenticated session (the `Authorization` token), not the request body** — the app doesn't send them explicitly; derive them server-side from whichever agent is making the authenticated request. This is what makes the whole feature meaningful: every call is attributable to a specific agent for supervisor review.

### 4.1 Reason codes
Exact enum names from `CallReason` (`lib/data/models.dart`) — send/expect these strings verbatim:

| Code | Display label |
|---|---|
| `paymentInquiry` | Payment inquiry |
| `beginningOfSession` | Beginning of study session |
| `teacherAbsence` | Teacher absence notification |
| `inquiryOnAbsences` | Inquiry on absences |
| `survey` | Survey |
| `parentDidNotPickUp` | Parent didn't pick up child |

### 4.2 Outcome codes
Exact enum names from `CallOutcome` — `outcome` is `null` if the agent hasn't picked one:

| Code | Display label |
|---|---|
| `interested` | Interested |
| `notInterested` | Not Interested |
| `comingToInstitute` | Coming to institute |
| `informationDiscussed` | Information discussed |
| `couldNotReach` | Couldn't reach |
| `followUpRequired` | Follow-up required |

### 4.3 `finalResult` — exact phrase set
`finalResult` is always exactly one of these five patterns (`CallRecord.finalResult` getter):

| Situation | Phrase |
|---|---|
| `reallyDialed == false` | `Agent never actually placed the call` |
| `likelyHungUpEarly == true` | `Agent called and cancelled almost immediately` |
| `endedQuickly == true` | `Call ended quickly — could be a decline or an early hangup` |
| `talkDurationSeconds <= 0` (and neither of the above) | `Call rang for {ringSessionSeconds}s but was not answered` (or `Call was not answered` if `ringSessionSeconds` is `null`) |
| `talkDurationSeconds > 0` | `Agent called, call was answered, talked for {duration}` — duration formatted as `1min 32s`, `45s`, or `2min` (see below) |

Duration formatting (`CallRecord._formatDuration`): under a minute → `{s}s`; on-the-minute → `{m}min`; otherwise → `{m}min {s}s`. Replicate this exactly if the backend ever needs to regenerate the phrase (e.g. after a manual data correction).

### 4.4 Server-side verdict — for the supervisor dashboard
The fields above are the raw facts. Whether they add up to a problem is a judgment call the app currently makes client-side (`CallRecord.verdictKind`), for the one call the agent is looking at right after finishing it. But **supervisor reporting across all agents needs to run this same logic server-side** (or in the dashboard's queries) — please replicate exactly:

```
if not reallyDialed:            verdict = "no_call_detected"          # hard flag
elif likelyHungUpEarly:          verdict = "early_hangup"               # hard flag
elif endedQuickly:                verdict = "ended_quickly"              # needs review, NOT a hard flag
else:
  answered = talkDurationSeconds > 0
  claimedReached = outcome is not null and outcome != "couldNotReach"
  if answered and claimedReached:         verdict = "answered_match"
  elif answered and not claimedReached:   verdict = "mismatch_underclaimed"
  elif not answered and not claimedReached: verdict = "not_answered_match"
  else:                                     verdict = "mismatch_overclaimed"  # hard flag
```

- **Hard flags** (`no_call_detected`, `early_hangup`, `mismatch_overclaimed`) are the strongest signals an agent is misreporting — these are what "agent is lying" detection actually means in this app. Surface them prominently (e.g. a dashboard filter, a count per agent).
- **`ended_quickly`** is genuinely ambiguous (see §6) — show it as "needs review", never assert it as a confirmed violation. Don't fold it into the same count as the hard flags.
- **`mismatch_underclaimed`** (call connected, but agent said "Couldn't reach") is the opposite kind of error — worth tracking too, but isn't evidence of dishonesty (more likely a slip while filling the form).

## 5. Timing, reliability, and edge cases

### 5.1 Submission can arrive long after the call happened
If the app process is killed while the native Phone app owns the screen (common — Android may reclaim memory from a backgrounded app during a call), the app resumes on its **next launch**, reconciles the call against the call log then, and only submits at that point. So `POST /api/calls` can land minutes or hours after `endedAtEpochMs`. **Always use `startedAtEpochMs`/`endedAtEpochMs` for "when did this call happen", never server receipt time.**

### 5.2 `ringSessionSeconds` can be `null`
This is timed live on-device (via Android telephony state) while the app is running. If the app process was killed mid-call (see 5.1), that in-memory timer is lost — the app still knows `reallyDialed` and `talkDurationSeconds` (from the call log, which persists independent of our process), but `ringSessionSeconds`, `likelyHungUpEarly`, and `endedQuickly` fall back to their "not observed" defaults (`null`/`false`). This is expected, not a bug — treat a `null` `ringSessionSeconds` as "we don't have this signal for this call," not as a zero.

### 5.3 Duplicate submission
If the network fails after the backend receives the request but before the app gets a `2xx` back, the app may retry the same submission. **Recommend deduping by `(agentId, studentId, startedAtEpochMs)`** — that triple is unique per real call attempt.

### 5.4 Phone number format
The app does **not** send the raw phone number in `POST /api/calls` — only `studentId`. The backend already has the student's phone number from `GET /api/students`; there's no need to duplicate PII in every call record.

## 6. Why some things genuinely can't be known

Worth understanding so nobody asks for a field the platform can't provide: Android's call log only ever tags an **outgoing** call as `OUTGOING` — it does not distinguish "parent explicitly declined" from "parent's phone was on Do Not Disturb" from "rang out with no answer." That distinction (`DisconnectCause.REJECTED` vs `BUSY` vs `MISSED`) exists in Android's telecom stack, but is only exposed to whichever app is the device's **default phone/dialer app** — a role this app doesn't take (doing so would replace the agent's personal calling app and require reimplementing a full in-call UI). So `endedQuickly` stays deliberately ambiguous rather than guessing.

## 7. Not implemented yet — flag if these need to change

- **Offline queueing**: the app currently assumes network is available when the agent taps "Save and Finish." If an agent finishes a call with no signal, submission will simply fail today — no local retry queue exists yet. Flag if this needs to be built before launch.
- **Alerting on hard flags**: nothing currently notifies a supervisor in real time when a hard-flag call comes in — it's only visible by querying/browsing. Flag if you want a webhook or notification on ingest.
