# call_tracker

- Flutter is not on `PATH`. Use the fvm copy: `export PATH="/Users/mahdi/fvm/versions/3.38.1/bin:$PATH"` before `flutter analyze` / `flutter test` / `flutter build apk --debug`.
- No emulator is configured — the only mobile device is a wirelessly-connected physical iPhone, and the app is Android-first (`phone_state`, native dialer intent), so UI behaviour cannot be verified locally. Analyze + tests + a debug APK build is as far as automated verification goes.
- The four tabs live in an `IndexedStack` in `root_view.dart`, so a tab's `initState` runs once per session and never again. Anything that needs to re-fetch must listen to `RefreshSignal` (`lib/data/refresh_signal.dart`); it is fired on tab change, on app resume, and after a call is submitted.
- `ApiService` getters return `null` when a request fails (vs an empty list when the server genuinely has nothing). Screens must keep their existing data on `null` rather than blanking the list.
