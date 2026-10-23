# Yalla Delivery

Yalla Delivery is a Flutter courier application for managing delivery orders. It
provides an Arabic-first, right-to-left workflow for Yalla Market delivery
representatives and connects to the Yalla Delivery REST API.

## Features

- Secure courier authentication with automatic access-token refresh.
- Active order tracking and detailed delivery information.
- Pickup and delivery status updates.
- Delivery confirmation with optional notes and photo proof.
- Delivered-order history and summary views.
- Firebase push notifications for order and account updates.
- Courier profile and availability management.
- Light and dark themes with offline connection feedback.

## Tech Stack

- Flutter and Dart
- REST API integration using `http`
- Firebase Cloud Messaging and Crashlytics
- Secure token storage with `flutter_secure_storage`
- Local notifications with `flutter_local_notifications`
- Courier order state uses `flutter_bloc` Cubits and `get_it` composition,
  with pure domain use cases and typed repository results. These dependencies
  keep network operations out of the updated order presentation flows.

## Requirements

Before running the project, install:

- A Flutter SDK compatible with Dart `^3.11.4`
- Android Studio and the Android SDK for Android development
- Xcode and CocoaPods for iOS development
- A running Yalla Delivery backend API

## Getting Started

Install the project dependencies:

```bash
flutter pub get
```

Run the app with the development environment:

```bash
flutter run --dart-define-from-file=env/development.json
```

The development environment points to `http://127.0.0.1:8000/api/v1`. When
using an Android emulator with a backend running on the host machine, change
the host to `10.0.2.2`. A physical device must use an address that is reachable
from that device.

## Environment Configuration

Runtime configuration is supplied through a JSON file:

```json
{
  "API_BASE_URL": "https://example.com/api/v1"
}
```

Pass the file to Flutter with `--dart-define-from-file`. Release builds require
`API_BASE_URL` to be a valid HTTPS URL.

## Firebase Configuration

Firebase configuration files are deployment-specific and are not committed to
the repository. Add the appropriate file before testing push notifications or
creating a release build:

- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`

The iOS Runner target bundles this file, so supply it before an iOS debug or
release build. Use the configuration for `com.yallamarket.yallaHome`, not the
customer app. The file is ignored by Git.

## Quality Checks

Run static analysis and the test suite before submitting changes:

```bash
flutter analyze
dart run tool/check_source_size.dart
flutter test
```

## Release Builds

### Android

Configure the Android release keystore in `android/key.properties`, add the
Firebase configuration, and run the release preflight check:

```bash
dart run tool/release_preflight.dart env/production.json --platform=android
```

Build the Android App Bundle with obfuscation and split debug information:

```bash
flutter build appbundle --release --obfuscate \
  --split-debug-info=build/debug-symbols/android \
  --dart-define-from-file=env/production.json
```

Archive `build/debug-symbols/android` with every release so obfuscated
Crashlytics stack traces can be decoded.

### iOS

An iOS release requires the Firebase configuration and a valid Apple
Development Team:

- Minimum supported iOS version: **15.0**, matching the Firebase Apple SDK.
- Add `ios/Runner/GoogleService-Info.plist` for `com.yallamarket.yallaHome`.
- In Xcode, select the Runner signing team and configure provisioning with
  Push Notifications, Remote notifications, and Keychain Sharing enabled.
- Upload the matching APNs authentication key in Firebase Cloud Messaging.

```bash
dart run tool/release_preflight.dart env/production.json --platform=ios
flutter build ipa --release \
  --dart-define-from-file=env/production.json
```

Configure signing, Firebase, and APNs on a Mac with Xcode before distributing
the app through TestFlight.

Verify a fresh installation on a real iPhone: allow and deny notifications,
check pushes in foreground/background and after reopening, verify remembered
login after a restart, and test delivery confirmation with camera permission
both granted and denied. Windows tests do not validate native iOS builds.

## Authentication Sessions

- **Remember me** is disabled by default. On mobile, this creates a
  process-only session with an absolute eight-hour backend deadline. On the
  web, session data is stored in `sessionStorage`.
- Enabling **Remember me** persists the session and uses a seven-day inactivity
  window. A successful foreground token refresh starts a new seven-day window.
- Access tokens refresh automatically. The app does not perform background
  refreshes solely to keep an unused session active.

## Project Structure

```text
lib/
|-- core/                 # Authentication, networking, routing, and shared UI
|-- features/
|   |-- auth/             # Courier sign-in flow
|   |-- deliveries/       # Orders, notifications, and courier profile
|   `-- splash/           # Application startup and session restoration
|-- main.dart             # Application entry point
`-- yalla_home_app.dart   # Root Material application
```
