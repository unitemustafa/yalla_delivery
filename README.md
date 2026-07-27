# Yalla Home

Flutter courier app for managing Yalla Home delivery orders.

## Features

- Arabic-first delivery workflow.
- Active, delivered, notification, and profile tabs.
- Theme switching and offline connection status.

## Running

```powershell
flutter pub get
flutter run
```

## Checks

```powershell
flutter analyze
flutter test
dart run tool/release_preflight.dart env/production.json --platform=android
flutter build appbundle --release --obfuscate `
  --split-debug-info=build/debug-symbols/android `
  --dart-define-from-file=env/production.json
```

The Android check also requires the courier Firebase configuration. Use
`--platform=ios` before an internal iOS archive; it requires
`GoogleService-Info.plist` and an Apple Development Team.
Archive the generated debug-symbol directory with every internal release so
obfuscated Crashlytics stack traces can be decoded.

## Authentication sessions

- `تذكرني` is off by default. Off creates a process-only mobile session with
  an absolute eight-hour backend deadline; Web uses `sessionStorage`.
- Enabling it persists the session and uses a seven-day inactivity window.
  A successful foreground token refresh starts a new seven-day window.
- Access tokens refresh automatically. The app does not refresh in the
  background solely to keep an unused session alive.
