# call_tracker

- Flutter is not on `PATH`. Use the fvm copy: `export PATH="/Users/mahdi/fvm/versions/3.38.1/bin:$PATH"` before `flutter analyze` / `flutter test` / `flutter build apk --debug`.
- No emulator is configured — the only mobile device is a wirelessly-connected physical iPhone, and the app is Android-first (`phone_state`, native dialer intent), so UI behaviour cannot be verified locally. Analyze + tests + a debug APK build is as far as automated verification goes.
- `ApiService` getters return `null` when a request fails (vs an empty list when the server genuinely has nothing). Screens must keep their existing data on `null` rather than blanking the list.
- Nothing derived from `CallVerification` / `CallRecord.verdictKind` / `finalResult` may be rendered in agent-facing UI (`call_view`, `call_summary_view`) — not the verdict, not the note, not "we checked your call log". It is computed and sent to the backend, and the agent is never shown that the check happened. The one exception is the Dashboard's `kShowCallMonitor` block, which is a test-mode screen behind a flag.
