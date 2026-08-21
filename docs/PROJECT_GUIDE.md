# Yalla Home — Complete Project Guide

> A code-oriented onboarding guide for junior Dart and Flutter developers.
>
> This document describes the repository as it exists today. When this guide and
> the source code disagree, the source code is the final authority.

## 1. What This Project Is

Yalla Home is an Arabic-first Flutter application for delivery representatives
(couriers). It is not the customer shopping application and it is not an admin
dashboard. Its authenticated users must have the backend role
`representative`.

The application helps a courier:

- Sign in with a phone number, email address, or username.
- Restore a previous authentication session safely.
- See currently assigned delivery orders.
- Open an order and review the customer, address, market, products, and value.
- Contact the customer by phone or WhatsApp.
- Open the destination in Google Maps.
- Move an order through the courier lifecycle: assigned, picked up, delivered.
- Add an optional delivery note and camera proof when completing delivery.
- Review delivered orders and filter a delivered-order summary by date.
- Read, mark, and delete backend notifications.
- Receive Firebase push notifications about orders and account changes.
- Review the courier profile and switch between system, light, and dark themes.
- Continue seeing the current screen while a global banner reports lost
  connectivity.

The app's visible text is mostly Egyptian Arabic, its layout is right-to-left,
and its design supports both light and dark modes.

## 2. The Fastest Mental Model

Think of the application as five cooperating parts:

```text
Flutter widgets
    ↓ call callbacks / controllers
Presentation state
    ↓ calls feature APIs
Feature data classes
    ↓ use AuthSession
Authenticated HTTP + token lifecycle
    ↓ communicates with
Yalla backend API

Firebase Messaging ──→ global push event stream ──→ shell/screens refresh
Connectivity Plus  ──→ global offline banner
```

There is no third-party state-management framework and no dependency-injection
container. State is managed using:

- `StatefulWidget` for screen-local state.
- `ChangeNotifier` for reusable notification and profile state.
- `ValueNotifier<ThemeMode>` for global theme selection.
- Singleton services for authentication, navigation, push notifications, and
  theme state.
- `InheritedNotifier` for connectivity state below the app root.

This is a pragmatic, feature-first architecture. It borrows the useful parts of
layered architecture without pretending to be a strict Clean Architecture
implementation.

## 3. Repository Map

```text
yalla_home/
├── lib/
│   ├── main.dart                         # Process entry point
│   ├── yalla_home_app.dart               # MaterialApp and global listeners
│   ├── core/                              # Shared application infrastructure
│   │   ├── auth/                          # Tokens, session restore, refresh
│   │   ├── connectivity/                  # Network status and reachability
│   │   ├── constants/                     # Assets, colors, app name
│   │   ├── formatters/                    # Shared display formatting
│   │   ├── icons/                         # Central icon aliases
│   │   ├── network/                       # API exception type
│   │   ├── notifications/                 # Firebase/local push service
│   │   ├── presentation/widgets/          # Shared UI components
│   │   ├── routing/                       # Named routes and global navigator
│   │   └── theme/                         # Light/dark themes and controller
│   └── features/
│       ├── splash/presentation/           # Session restoration screen
│       ├── auth/presentation/             # Login screen
│       └── deliveries/
│           ├── data/                      # Backend-facing feature APIs
│           ├── domain/                    # Typed courier models and rules
│           └── presentation/
│               ├── controllers/           # ChangeNotifier state holders
│               ├── views/                 # Screens and page-level flows
│               └── widgets/               # Delivery-specific components
├── assets/                                # Logo, font, placeholders
├── env/                                   # Dart-define JSON environments
├── test/                                  # Unit and widget tests
├── tool/release_preflight.dart            # Release configuration validation
├── docs/RELEASE_CHECKLIST.md               # Manual release checklist
├── android/, ios/, web/                    # Platform configuration
├── pubspec.yaml                            # SDK, packages, assets, version
└── analysis_options.yaml                   # Flutter lint configuration
```

### Why `core` and `features` are separate

Use `core` for code that is useful across multiple features or belongs to the
application runtime itself. Authentication, routing, shared colors, a reusable
button, and push infrastructure all fit there.

Use `features` for product behavior. An order, the courier profile, and the
notifications screen belong to the delivery feature because they express the
business domain.

A healthy dependency direction is:

```text
feature presentation → feature data/domain → core infrastructure
```

Avoid making `core` import a feature screen or a feature model. The core layer
should remain reusable and should not know detailed delivery UI behavior.

## 4. Technology Stack

The project requires Dart SDK `^3.11.4` and uses Flutter's Material 3 UI.

| Package | Responsibility in this app |
|---|---|
| `http` | JSON and multipart communication with the backend |
| `flutter_secure_storage` | Persistent remembered tokens on native platforms |
| `web` | Browser `sessionStorage` access for temporary web sessions |
| `connectivity_plus` | Listening for network-interface changes |
| `firebase_core` | Firebase initialization |
| `firebase_messaging` | Remote push messages and FCM device tokens |
| `flutter_local_notifications` | Showing a local notification while foregrounded |
| `firebase_crashlytics` | Release-only Flutter and platform error reporting |
| `image_picker` | Taking an optional delivery-proof photo |
| `url_launcher` | Phone, WhatsApp, and Google Maps external actions |
| `iconsax` | Application icon set, wrapped by `AppIcons` |
| `flutter_localizations` | Arabic/English Material localization support |
| `fake_async` | Deterministic timer testing for authentication sessions |

The project deliberately uses a small dependency set. Before adding a package,
check whether Flutter itself or an existing package already solves the problem.

## 5. Application Startup, Step by Step

Startup begins in `lib/main.dart`.

```text
main()
  1. Ensure Flutter bindings exist.
  2. Read AuthSession.apiBaseUrl.
  3. Fail immediately if a release has no API_BASE_URL.
  4. Run YallaHomeApp.
  5. After the first frame, initialize Firebase and push services.
  6. In release mode, enable Crashlytics error handlers if Firebase is ready.
```

The important design choice is that remote services initialize after the first
frame. A slow or unavailable Firebase setup therefore does not delay the first
Flutter frame. Push initialization catches its own failures and returns `false`,
so the main delivery workflow can still start.

`YallaHomeApp` then builds the root `MaterialApp`:

- The initial route is `/`, which shows `SplashView`.
- The locale is Arabic and the entire widget tree is forced to RTL.
- Arabic and English Material localizations are registered.
- Light and dark themes use the bundled Cairo font.
- `OfflineConnectionBanner` wraps every route.
- Global listeners react to expired sessions, changed passwords, and foreground
  courier pushes.
- `AppNavigator.key` allows infrastructure services to navigate even when they
  do not own a screen `BuildContext`.

### Splash and session restoration

`SplashView` starts a logo animation and calls `AuthSession.restore()`.

The restore result has four explicit states:

| Result | Meaning | UI action |
|---|---|---|
| `restored` | Tokens refreshed and `auth/me/` returned a representative | Register FCM device and open dashboard |
| `noSession` | No stored session exists | Open login |
| `expired` | Stored or backend session is no longer valid | Clear session and open login |
| `temporaryFailure` | Network/server problem, but the session may still be valid | Stay on splash and show retry |

This distinction matters. A temporary network failure must not be interpreted
as invalid credentials and must not silently destroy a valid user session.

The animation respects the operating system's “reduce motion” preference by
jumping to its final value when `MediaQuery.disableAnimations` is true.

## 6. Routing and Navigation

Named root routes live in `lib/core/routing/app_routes.dart`:

| Route | Screen |
|---|---|
| `/` | `SplashView` |
| `/login` | `LoginView` |
| `/dashboard` | `CourierShellView` |

`AppRouter.generateRoute` maps those names to `MaterialPageRoute` objects. An
unknown route safely falls back to login.

Authentication transitions remove the previous route stack:

```dart
Navigator.pushNamedAndRemoveUntil(context, AppRoutes.dashboard, (_) => false);
```

Removing the stack prevents a courier from pressing Back and returning to a
login or protected screen that no longer matches the authentication state.

Secondary pages such as order details, notifications, and delivered summary
use direct `MaterialPageRoute` navigation because they are internal dashboard
flows rather than application entry points.

## 7. State Ownership

One of the most important Flutter questions is: **who owns this state?**

| State | Owner | Reason |
|---|---|---|
| Logged-in tokens/current user | `AuthSession` singleton | Shared by all APIs and screens |
| Theme mode | `AppThemeController` singleton | Changes the root `MaterialApp` |
| Connectivity status | `InternetStatusController` | Shared by global offline banner |
| Push event stream | `CourierPushService` singleton | App-wide external event source |
| Loaded order list and selected tab | `CourierShellView` | Shared by its three dashboard tabs |
| Notification list/unread state | `CourierNotificationsController` | Multiple operations update one list |
| Courier account loading state | `CourierProfileController` | Profile data has loading/error/cache state |
| Form text, password visibility, submit flag | `LoginView` | Local to one screen |
| Open order details and current action | `OrderDetailsView` | Local to one order page |

The shell deliberately owns the canonical order list. Child pages receive
orders and callbacks. After pickup or delivery, the shell replaces the updated
order in that list. This keeps the active and delivered tabs consistent without
introducing a second global store.

Both feature controllers protect against duplicate requests using an
“in-flight future”:

```text
call arrives → is a load already running?
  yes → await and return the same Future
  no  → create the load Future, store it, and clear it in finally
```

This is a useful Dart concurrency pattern. It is stronger than only checking a
Boolean because every caller can await the same operation and receive the same
completion timing.

## 8. Authentication Architecture

Authentication is the most defensive part of the application. Read these files
in this order:

1. `session_metadata.dart`
2. `auth_token_store.dart`
3. `auth_session.dart`
4. `session_expired_notifier.dart`
5. `password_changed_notifier.dart`

### 8.1 Session modes

There are two backend-authoritative modes:

| Mode | Remembered? | Client storage | Deadline behavior |
|---|---:|---|---|
| `temporary` | No | Memory on native; browser `sessionStorage` on web | Absolute session deadline; currently expected to be eight hours from the backend contract |
| `persistent` | Yes | Secure storage | Refresh expiry represents a sliding remembered-session window |

The token response contains:

- `accessToken`
- `refreshToken`
- `session.accessExpiresAt`
- `session.refreshExpiresAt`
- `session.startedAt`
- `session.mode`
- `session.remember`
- `session.absoluteExpiresAt` for temporary sessions only

`tokensFromApiPayload` validates these fields instead of guessing them. A
temporary session without an absolute deadline is rejected. A persistent
session with an absolute deadline is also rejected.

`StoredAuthTokens.sessionDeadline` selects the correct effective deadline:

- Temporary: `absoluteExpiresAt`, falling back to refresh expiry only for
  already-stored compatible data.
- Persistent: `refreshExpiresAt`.

The current login screen initializes “Remember me” to `true`. Both remembered
and temporary session paths are supported. If product requirements change the
default, update the UI, README, tests, and this guide together.

### 8.2 Storage behavior

`SecureAuthTokenStore` provides one interface with platform-aware behavior.

Native remembered session:

```text
JSON-encoded StoredAuthTokens → FlutterSecureStorage
```

Native temporary session:

```text
StoredAuthTokens → process memory only
app process ends → session is no longer restorable
```

Web temporary session:

```text
JSON-encoded StoredAuthTokens → window.sessionStorage
browser tab/session closes → browser removes the value
```

Conditional imports select a browser implementation only when JavaScript
interop is available. Non-web builds receive a no-op storage stub, so they never
compile against browser APIs.

The store also migrates older token keys. Legacy JWT metadata is decoded only
to preserve an older remembered session safely; all legacy keys are then
cleared. New authentication should always use the version-2 JSON structure.

### 8.3 Login flow

```text
LoginView validates form
  ↓
remove all whitespace from identifier/password
  ↓
POST auth/login/representative/
  ↓
reject inactive account or non-representative role
  ↓
validate backend session metadata
  ↓
save tokens using the correct session mode
  ↓
store user map in AuthSession.currentUser
  ↓
request notification permission and register FCM token
  ↓
replace route stack with dashboard
```

The form accepts a plausible phone number, email, or username. This is UX
validation only. The backend remains responsible for authentication and
authorization.

### 8.4 Authorized request flow

All feature APIs call an `AuthSession` method such as `getJson`, `postJson`,
`patchJson`, `deleteJson`, or `patchMultipart`.

Before an authorized request:

1. Confirm the session deadline has not passed.
2. Refresh proactively when the access token is missing or expires within one
   minute.
3. Send the request with `Authorization: Bearer <access token>`.
4. Detect an inactive-account response immediately.
5. If the response is `401`, try one refresh and replay the request once.
6. If the replay is also `401`, expire the local session.

The request timeout is 20 seconds by default. Multipart proof upload uses 45
seconds. Timeouts and `http.ClientException` values become readable
`ApiException` messages.

### 8.5 Why refresh uses an in-flight Future

Several requests can discover an expiring token at the same time. Without
coordination, all of them would send a refresh request. `AuthSession` stores
`_refreshInFlight`, so concurrent callers await one shared refresh.

This prevents:

- Duplicate token rotation.
- Races where an older response overwrites a newer token.
- Avoidable backend load.

The session also has `_sessionVersion`. Login, clear, logout, and expiry change
the version. A refresh remembers the version with which it started and refuses
to activate tokens when the version changed meanwhile. This prevents a slow
refresh from bringing a logged-out session back to life.

### 8.6 Refresh throttling and continuity

If the refresh endpoint returns `429`, the app reads
`retry_after_seconds` or the `Retry-After` header, clamps the delay to 1–60
seconds, waits once, and retries once.

After refresh, `_validateSessionContinuity` verifies that the backend did not
unexpectedly change:

- Session mode.
- Session start time.
- Temporary absolute deadline.

A legitimate persistent refresh may move `refreshExpiresAt` forward, which is
how the remembered inactivity window is re-armed.

### 8.7 Expiry, password changes, and inactive accounts

An expiry timer is scheduled at the effective session deadline. Expiring a
session clears tokens, current user, active refresh state, and the timer. A
deduplicated notifier tells `YallaHomeApp` to return to login and show the
appropriate dialog.

Password changes are handled separately from ordinary expiry so the user sees
a more precise explanation. `account_inactive` is also intercepted globally and
clears the session.

### 8.8 Logout

Logout tries to refresh an expiring access token when necessary, calls
`POST auth/logout/` with the active access and refresh tokens, and always clears
local state in `finally`. Losing the network must never trap a user inside the
local session.

## 9. Backend API Contract Used by the App

All paths are relative to `API_BASE_URL`.

| Method | Path | Called by | Purpose |
|---|---|---|---|
| `POST` | `auth/login/representative/` | `AuthSession.login` | Courier-only login |
| `POST` | `auth/refresh/` | `AuthSession` | Rotate/refresh session tokens |
| `POST` | `auth/logout/` | `AuthSession.logout` | Invalidate server session |
| `GET` | `auth/me/` | restore/profile | Validate role and load current account |
| `GET` | `courier/orders/` | `CourierOrdersApi` | Load courier orders; accepts list or paginated `results` |
| `GET` | `courier/orders/{id}/` | details/push/notification | Load one authoritative order |
| `PATCH` | `courier/orders/{id}/status/` | order actions | Set `picked_up` or `delivered` |
| `GET` | `notifications/` | notifications controller | Load notifications |
| `GET` | `notifications/unread-count/` | shell/controller | Load unread badge count |
| `PATCH` | `notifications/{id}/read/` | notifications controller | Mark one notification read |
| `POST` | `notifications/mark-all-read/` | notifications controller | Mark every notification read |
| `DELETE` | `notifications/{id}/` | notifications controller | Delete one notification |
| `POST` | `notifications/devices/register/` | push service | Register the FCM token and platform |

The data classes intentionally remain thin. They do not create another HTTP
client or duplicate token behavior; every request goes through `AuthSession`.

### JSON versus multipart delivery

Completing a delivery without a photo sends JSON:

```json
{
  "status": "delivered",
  "delivery_note": "Optional note"
}
```

When a proof image exists, the same fields are sent as a multipart PATCH and
the file field is named `delivery_proof`.

## 10. Domain Models and Business Rules

Domain models convert weakly typed API maps into values that screens can use
safely. They also centralize display fallbacks and genuine business rules.

### 10.1 `CourierOrder`

The order model includes:

- Identity and status.
- Customer name, phone, avatar, address, area, and notes.
- Coordinates or a text map query.
- Total and optional delivery price.
- Creation, assignment-derived expectation, and delivery timestamps.
- Product items, quantities, unit prices, and subtotals.
- Market name, branch, count, and summary.
- Optional delivery note and proof URL.

Parsing is deliberately tolerant where the backend has historical shapes:

- Nested maps are normalized from generic `Map` values.
- Numbers may arrive as strings or JSON numbers.
- Address parts are cleaned, deduplicated, and joined in Arabic order.
- Customer name falls back through several fields and finally to `عميل`.
- Delivered time prefers `delivered_at`, then the latest authoritative
  `delivered` history event, and otherwise stays `null`.
- Relative media paths become absolute URLs using the API origin.

Do not scatter these fallbacks across widgets. If backend parsing changes, make
the change in the domain factory and test it there.

### 10.2 Order status normalization

The backend has current and legacy status spellings. They become one enum:

| Raw value | Dart status | Courier meaning |
|---|---|---|
| `pending` | `pending` | Waiting outside active courier workflow |
| `confirmed`, `under_preparation`, `preparing` | `confirmed` | Confirmed/preparing |
| `assigned`, `ready` | `assigned` | Assigned and can be picked up |
| `picked_up`, `on_the_way` | `pickedUp` | Courier has it and can deliver |
| `delivered`, `completed` | `delivered` | Successfully delivered |
| `failed_delivery` | `failedDelivery` | Terminal failure |
| `cancelled`, `canceled`, `rejected` | `cancelled` | Terminal cancellation |
| anything else | `unknown` | Safe unknown state |

The allowed courier state transition is intentionally narrow:

```text
assigned ── mark picked up ──→ pickedUp ── confirm delivery ──→ delivered
```

Widgets do not decide this with arbitrary string comparisons. They use getters
such as `canMarkPickedUp`, `canMarkDelivered`, `isActiveCourierOrder`, and
`isTerminal` from the status extension/model.

### 10.3 `CourierAccount` and `CourierProfile`

`CourierAccount` parses `auth/me/`, requires a representative role at the API
boundary, and supplies safe display name/contact fallbacks.

`CourierProfile` contains operational fields:

- Vehicle type.
- Plate number.
- Service city identifier and display name.
- Maximum active orders.
- Whether the courier is available to receive orders.

The UI distinguishes a missing courier profile from individual missing fields.

### 10.4 `CourierNotification`

The notification model accepts snake_case and selected camelCase keys. It
contains read, blocking, and resolved state plus an optional linked order.
Order-assignment notifications get a consistent display title/message even when
the backend text is sparse.

## 11. Delivery Feature, Screen by Screen

### 11.1 `CourierShellView`

The shell is the authenticated workspace and owns:

- All loaded orders.
- Initial loading and non-destructive refresh errors.
- Selected bottom-navigation tab.
- Unread notification badge.
- Shared profile and notification controllers.
- Push-event refresh behavior.

Its bottom navigation has exactly three tabs:

1. Active orders.
2. Delivered history.
3. Courier account.

An `IndexedStack` keeps the state of inactive tabs alive. Changing tabs does
not rebuild each page from scratch.

When the app resumes, the shell validates the session, then refreshes orders,
profile, and unread count together. Temporary failures are swallowed at this
level so a momentary network problem does not interrupt an already-visible
delivery workflow.

### 11.2 Active orders

`CourierOrdersView` receives only orders for which
`isActiveCourierOrder == true`. It provides:

- Pull-to-refresh.
- Notification badge entry.
- Active count.
- Pickup-required count.
- Total active-order value.
- Empty state.
- Order cards that open details.

The view does not fetch its own order list. This is intentional: the shell owns
the data and hands down the callbacks needed to change it.

### 11.3 Order details

`OrderDetailsView` receives an initial order so navigation is immediate, then
loads the authoritative order by ID. It has explicit loading, retry, action
submission, and push-removal states.

The screen displays:

- Order/status header.
- Customer identity and phone.
- Address label, full address, area, and city where available.
- Market summary and number of markets.
- Customer note.
- Products, quantities, and values.
- Historical delivery timestamp, note, and proof for delivered orders.
- Phone/WhatsApp contact actions.
- Google Maps directions using coordinates first and address text second.
- Pickup or delivery action according to current status.

If a push says the currently open order was unassigned or cancelled, the page
closes and informs the courier. This avoids allowing a stale action on an order
the courier no longer owns.

### 11.4 Delivery confirmation

The confirmation bottom sheet allows an optional note and optional camera
photo. The image is constrained to 1600×1600 at quality 72 to reduce upload size
while preserving useful evidence.

On Android, an external camera activity can kill and recreate the app process.
`ImagePicker.retrieveLostData()` restores the interrupted selection when
possible. This is a mobile-specific reliability detail a web-only developer can
easily miss.

After successful delivery, the shell replaces the updated order and selects the
delivered tab.

### 11.5 Delivered history and summary

`DeliveredHistoryView` shows delivered orders, their authoritative delivery
time, a count summary, and pull-to-refresh.

The profile can open `DeliveredSummaryView`, which filters delivered orders by:

- Today.
- Yesterday.
- Current week, starting Monday.
- Current month.
- A custom range within the last year.

Ranges use an inclusive start and exclusive end. This avoids errors at midnight:

```dart
!deliveredAt.isBefore(range.start) && deliveredAt.isBefore(range.end)
```

The summary reports both delivered count and the sum of order totals.

### 11.6 Notifications

The notifications page supports:

- Initial loading, error/retry, empty, and populated states.
- Pull-to-refresh.
- Backend unread count.
- Marking one notification read before opening it.
- Marking all notifications read.
- Swipe-to-delete in either horizontal direction.
- Opening a linked order by loading its current backend representation.
- A safe message when a linked order no longer exists or is no longer visible.

The controller changes local state only after the corresponding API succeeds.
For example, a failed delete keeps the card visible and a failed mark-all-read
does not erase unread state.

### 11.7 Profile

The profile screen loads `auth/me/` through `CourierProfileController` and
shows:

- Courier name, contact fallback, and avatar placeholder.
- Active and delivered counts with navigation actions.
- Service city, availability, vehicle, plate, and order limit.
- A warning when the backend courier profile is incomplete.
- System, light, and dark theme options.
- Confirmed logout.

The controller retains already-loaded account data during a failed refresh, so
an inline error can be shown without replacing useful content.

## 12. Push Notifications

`CourierPushService` combines Firebase Cloud Messaging with local
notifications and an in-process broadcast event stream.

### Initialization

The service:

1. Registers the top-level background handler.
2. Initializes Firebase.
3. Initializes local notifications.
4. Creates Android notification channels.
5. Listens for foreground messages.
6. Listens for notification taps.
7. Listens for FCM token rotation.
8. Reads the notification that launched a terminated app.

Notification permission is requested only after a representative is
authenticated. The device token is posted with platform `ios` or `android`.

### Android channels

| Channel | Typical events | Importance |
|---|---|---|
| `courier_orders` | Assigned, unassigned, cancelled orders | High |
| `account_updates` | Account disabled/restored | High |
| `courier_updates` | Profile and availability changes | Default |

### Supported event behavior

| Event | Important app behavior |
|---|---|
| `courier_order_assigned` | Refresh orders; a tapped push loads and opens the order if still active |
| `courier_order_unassigned` | Refresh orders; close matching details page |
| `courier_order_cancelled` | Refresh orders; close matching details page |
| `courier_account_disabled` | Clear authentication and return to login once |
| `courier_account_restored` | A tapped event returns to login |
| `courier_profile_updated` | Refresh profile |
| `courier_availability_changed` | Refresh profile |

Foreground data messages usually show both a local OS notification and an
in-app snackbar/haptic response. Opened events do not show the extra global
snackbar, preventing duplicate feedback after a tap.

### Deduplication

Messages can arrive through more than one Firebase path. The service keeps up
to 100 recently handled keys for ten minutes and distinguishes display from
open phases. The key prefers `notification_id`, then falls back to event,
order, and Firebase message identifiers.

Opened events that arrive before the shell subscribes are queued. The shell
drains this queue during initialization, so a cold-start notification is not
lost.

The shell debounces push-driven refreshes by 250 milliseconds. A burst of
related events therefore produces one refresh wave instead of repeated API
calls.

## 13. Connectivity and Offline UX

`connectivity_plus` reports whether a network interface exists, but an active
Wi-Fi interface does not guarantee internet access. On IO platforms the app
also performs a short DNS lookup. The controller:

- Listens for connectivity changes.
- Checks current connectivity at startup.
- Re-verifies every 45 seconds.
- Avoids overlapping checks.
- Cancels its stream and timer on disposal.

The global `OfflineConnectionBanner` listens to this controller and renders
above the current route. This is status feedback, not an offline data cache.
API calls can still fail and must retain their own loading/error behavior.

The reachability function uses a conditional implementation. Web returns
`null` because `dart:io` DNS lookup is unavailable there; interface status is
then used without importing an unsupported library.

## 14. Theme, RTL, Assets, and Shared UI

### Theme

`AppTheme` creates light and dark Material 3 themes from one private base
builder. Colors are centralized in `AppColors`, and the Cairo font is applied
to the app's text theme and buttons.

`AppThemeController` starts in `ThemeMode.system`. Theme selection is currently
kept in memory, so it resets to system after a new process starts. Persist it
only if that becomes a product requirement.

### RTL and localization

The app sets Arabic as the active locale and forces `TextDirection.rtl` at the
root. Use directional APIs where the meaning is leading/trailing:

- Prefer `EdgeInsetsDirectional` when direction should flip.
- Prefer `PositionedDirectional` for badges.
- Use explicit LTR only for values such as dates, coordinates, or formatted
  numbers when required.

Visible application strings are currently embedded in widgets and models;
there are no generated ARB localization files. English is registered as a
supported Material locale, but the product UI is not fully translated.

### Assets

`AppAssets` is the single source of paths for:

- Yalla Home logo.
- Courier fallback image.
- Product fallback image.
- User avatar fallback image.

`NetworkImageOrPlaceholder` handles missing/failed remote images while keeping
semantics and optional cache sizing in one reusable widget.

### Shared widgets

| Widget | Purpose |
|---|---|
| `AppActionButton` | Consistent filled, outlined, danger, ghost, loading, and disabled actions |
| `PageTopBar` | Shared title/subtitle/actions/back-button layout |
| `CustomSnackBar` | Success, warning, error, and info feedback |
| `NetworkImageOrPlaceholder` | Safe network image with local fallback |
| `OfflineConnectionBanner` | App-wide connectivity status |
| `CourierNotificationsButton` | Bell action with capped `9+` badge |
| `OrderCard` | Active/delivered order summary presentation |

Use these before creating another one-off implementation.

## 15. Environment Configuration

`API_BASE_URL` is compiled into the app with a Dart define.

Default debug behavior when no define is supplied:

| Platform | Default URL |
|---|---|
| Web | `http://127.0.0.1:8000/api/v1` |
| Native | `http://10.0.2.2:8000/api/v1` |

`10.0.2.2` is the Android emulator alias for the host computer. It is not the
correct address for a physical phone. Use a reachable LAN or tunnel URL for
physical-device development.

Release builds fail early when `API_BASE_URL` is missing. Android release builds
additionally require HTTPS in Gradle.

Run a development configuration:

```bash
flutter pub get
flutter run --dart-define-from-file=env/development.json
```

Run the Android emulator against the native default:

```bash
flutter run
```

Run all static and automated checks:

```bash
flutter analyze
flutter test
```

## 16. Platform Configuration

### Android

- Application ID: `com.yallamarket.yalla_home`.
- Java/Kotlin compatibility: Java 17.
- Portrait orientation.
- Internet and notification permissions.
- Backups disabled.
- Cleartext traffic disabled in main/release manifest and enabled only by the
  debug manifest.
- Release signing requires `android/key.properties` and its referenced
  keystore.
- Release requires `android/app/google-services.json`.
- Firebase Google Services is applied only when that file exists.
- A white notification resource is configured as `ic_notification`.

Do not commit keystore passwords or invent Firebase credentials.

### iOS

- Portrait orientation.
- Camera usage description for delivery proof.
- Remote-notification background mode.
- Push entitlements split between debug/profile and release.
- A real Apple Development Team and `GoogleService-Info.plist` are required for
  release work.
- Physical-device notification testing is required before TestFlight rollout.

See `ios/README_RELEASE.md` for account-owned setup steps.

### Web and desktop directories

Flutter platform scaffolding exists for web, Linux, macOS, and Windows. The
product-specific Firebase, notification, camera, and release workflows in this
repository are centered on Android and iOS. Do not assume that the presence of
a generated platform directory means every feature is configured and supported
there. Verify the target platform before promising parity.

## 17. Release Process

First validate production configuration:

```bash
dart run tool/release_preflight.dart env/production.json --platform=android
```

The preflight script checks:

- The environment file exists and is valid JSON.
- `API_BASE_URL` is a valid HTTPS URL.
- Android Firebase configuration exists for Android checks.
- iOS Firebase configuration and a valid Apple Team exist for iOS checks.

Example Android release build:

```bash
flutter build appbundle --release --obfuscate \
  --split-debug-info=build/debug-symbols/android \
  --dart-define-from-file=env/production.json
```

Archive the split debug symbols with the release. Without them, obfuscated
Crashlytics stack traces cannot be decoded reliably.

Read `docs/RELEASE_CHECKLIST.md` before distribution. It covers device sizes,
accessibility text, RTL, dark mode, offline behavior, authentication, delivery,
push, and staged rollout monitoring.

## 18. Testing Strategy

The repository uses Flutter's existing test stack. It does not require an end
to end browser test framework.

### Authentication tests

`test/auth_session_test.dart` covers high-risk concurrency and lifecycle rules:

- Temporary and remembered login metadata.
- Restore behavior.
- Rate-limited refresh retry.
- One shared refresh for concurrent requests.
- Protection against a refresh reviving a cleared session.
- One retry after a reactive `401`.
- Authentication versus transient refresh failures.
- Readable timeouts.
- Exact temporary deadline expiry.
- Persistent window re-arming.
- Password-changed and inactive-account behavior.

`test/auth_token_store_test.dart` covers backend metadata validation, native and
web storage policy, clearing all storage locations, and legacy migration.

### Feature and widget tests

`test/widget_test.dart` covers:

- Login rendering.
- Order parsing, timestamps, statuses, and lifecycle helpers.
- Compact-width and larger-text order cards.
- JSON and multipart delivery behavior.
- Contact/map availability.
- Active and delivered screen behavior.
- Notification parsing, counts, mark-read, mark-all-read, deletion, swiping,
  linked orders, and failure preservation.
- Navigation bar composition.
- Historical proof display.
- Image placeholders.
- Profile parsing, fallbacks, loading/error/retry, refresh, theme, statistics,
  and logout confirmation.

Other focused tests cover push deduplication, foreground feedback, and bundled
asset size/format expectations.

### How to write a useful new test

Test public behavior and invariants rather than private implementation. Good
examples are:

- “Two simultaneous requests produce one refresh request.”
- “A failed delete leaves the notification visible.”
- “An assigned order permits pickup but not delivery.”

Avoid tests that only assert a private variable name or the exact number of
internal helper calls unless that count represents a real correctness rule.

## 19. Common Development Recipes

### Add a new authenticated endpoint

1. Decide which feature owns it.
2. Add a focused method to the existing feature API class.
3. Call the appropriate `AuthSession` JSON or multipart method.
4. Parse the response into an existing or new typed domain model.
5. Expose loading, error, empty, and success behavior through the screen or
   controller that owns the state.
6. Add tests for success, malformed data, and important failure behavior.
7. Do not create a second HTTP client or manually duplicate refresh logic.

Example shape:

```dart
Future<SomeModel> loadSomething(String id) async {
  final data = await AuthSession.instance.getJson('feature/items/$id/');
  return SomeModel.fromJson(data as Map<String, dynamic>);
}
```

### Add a new order status

1. Add the enum case if it represents a genuinely distinct UI state.
2. Update `courierOrderStatusFromRaw` with every backend spelling.
3. Define label, color, terminal state, and allowed actions.
4. Search for all status helpers rather than all raw strings.
5. Add parsing and action-permission tests.
6. Confirm active/delivered shell filtering remains correct.

Never enable an order action in a widget without also expressing the rule in
the domain model and enforcing it on the backend.

### Add a new push event

1. Agree on a stable backend `event` value and payload fields.
2. Add fallback title/body text to `CourierPushEvent` if needed.
3. Choose the correct Android channel in `_showLocal`.
4. Add app behavior in the shell or relevant screen.
5. Decide whether a tap opens a route, refreshes data, or clears a session.
6. Verify deduplication for display and open phases.
7. Test foreground, background, terminated, and cold-start behavior on devices.

### Add a new screen

1. Place it under the owning feature's `presentation/views` directory.
2. Keep server parsing in `domain`, requests in `data`, and reusable state in a
   controller only when it outlives one local widget concern.
3. Use shared page bars, action buttons, snackbars, colors, and image fallbacks.
4. Support loading, error, retry, empty, and success states as applicable.
5. Respect safe areas, RTL, keyboard insets, dark mode, and large text.
6. Use `mounted` or `context.mounted` after every awaited operation before
   touching widget state or navigation.

## 20. Dart and Flutter Lessons in This Codebase

### Prefer types at boundaries

HTTP JSON begins as `dynamic`, but it should stop being dynamic at the parsing
boundary. `CourierOrder.fromJson` and related factories turn external data into
predictable Dart objects.

### Use enums for finite states

`CourierOrderStatus` and `AuthSessionMode` make invalid string combinations
harder to express. Exhaustive switch expressions make the compiler identify
missing cases after an enum grows.

### Use immutable models and `copyWith`

Models have final fields. When one value changes, create a new model. This makes
screen updates more predictable than mutating a shared map.

### Always clean up asynchronous resources

State classes cancel stream subscriptions, timers, animation controllers, and
text controllers in `dispose`. Forgetting this can produce memory leaks,
duplicate events, or callbacks after a widget is gone.

### Check `mounted` after `await`

An async operation may finish after the user closed the page. Calling
`setState`, showing a snackbar, or navigating then can throw. The screens check
`mounted` before touching UI state after asynchronous work.

### Use `unawaited` intentionally

Some work is explicitly fire-and-forget, such as a non-blocking refresh or
background service initialization. `unawaited(...)` documents that choice and
prevents the reader from wondering whether a missing `await` is accidental.

### Use `finally` for state cleanup

Loading flags and in-flight references are cleared in `finally`, so success and
failure cannot leave the interface permanently disabled.

### Prefer derived state

Active and delivered orders are derived from the shell's canonical list. They
are not maintained as independent mutable lists, which would eventually drift
out of sync.

## 21. Important Invariants and Current Limitations

Treat these as rules that should remain true during future changes:

1. Only a user with role `representative` may enter the dashboard.
2. Backend session metadata is authoritative; the client must not invent token
   deadlines.
3. A temporary failure must not be treated as an invalid session.
4. Only one token refresh may be active at a time.
5. A cleared or logged-out session must never be revived by an older request.
6. Authorized feature traffic must go through `AuthSession`.
7. `assigned` can become `picked_up`; `picked_up` can become `delivered`.
8. The shell owns the canonical order list.
9. A failed destructive notification action must preserve visible local data.
10. Push events may refresh the UI, but the backend response remains
    authoritative.
11. Release builds require an explicit HTTPS backend URL and platform Firebase
    configuration.
12. Crashlytics collection is enabled only in release mode after successful
    Firebase initialization.

Current architectural limitations to understand before extending the app:

- UI strings are not yet extracted into ARB localization files.
- Theme choice is not persisted.
- Orders are loaded as one list; the client does not currently expose explicit
  pagination controls even if the backend returns a paginated `results` shape.
- Connectivity reporting is informational; there is no offline mutation queue
  or order cache.
- API response parsing mixes strict checks at security boundaries with tolerant
  fallbacks in display models. Preserve that distinction.
- `AuthSession.currentUser` is a raw map for global role checks, while the
  profile feature uses a typed `CourierAccount`. New feature code should prefer
  typed models where possible.
- Some large view files contain many private presentation widgets. Extract a
  widget only when it is reused or when it owns a meaningful, independently
  testable responsibility—not merely to reduce line count.

## 22. Troubleshooting

### Release fails immediately with `API_BASE_URL is required`

Pass the production file:

```bash
flutter build appbundle --release \
  --dart-define-from-file=env/production.json
```

### Android emulator cannot reach the local backend

Use `10.0.2.2`, not `127.0.0.1`, from the Android emulator. Running without an
environment file already uses the correct emulator default.

### Physical phone cannot reach the backend

The phone cannot use your computer's loopback address. Provide a URL reachable
from the phone, ensure firewall/network rules allow it, and remember that
release Android rejects cleartext HTTP.

### Login succeeds but the dashboard immediately returns to login

Check that:

- `user.role` is exactly `representative`.
- The response includes valid session metadata.
- Temporary/persistent mode agrees with the `remember` Boolean.
- Token timestamps are ordered and have not expired.
- `auth/me/` returns the same active representative account.

### Notifications do not arrive

Check, in order:

1. Firebase platform file matches the application/bundle ID.
2. Firebase initializes successfully on a physical device.
3. Notification permission is granted.
4. Login registered the FCM token with the backend.
5. The backend sends a supported `event` field in message data.
6. Android channel and notification icon exist.
7. APNs key is uploaded to Firebase for iOS.
8. Foreground, background, and terminated cases are tested separately.

### Delivery proof disappears after the camera closes

Verify camera permission and the `image_picker` lost-data path. On Android,
process recreation during camera capture is expected and must remain supported.

### Session unexpectedly logs out during poor connectivity

Separate authentication failures (`400`, `401`, `403` in restore/refresh
contexts) from timeouts or transport errors. Transient failures should preserve
stored tokens and surface retry behavior.

## 23. Recommended Reading Order for a New Developer

Use this order instead of opening the largest screen first:

1. `pubspec.yaml` — understand the platform and dependencies.
2. `lib/main.dart` — see the process entry point.
3. `lib/yalla_home_app.dart` — understand global app behavior.
4. `lib/core/routing/` — learn the three root routes.
5. `lib/features/splash/presentation/views/splash_view.dart` — see restoration.
6. `lib/features/auth/presentation/views/login_view.dart` — see login UX.
7. `lib/core/auth/session_metadata.dart` — understand session modes.
8. `lib/core/auth/auth_token_store.dart` — understand persistence.
9. `lib/core/auth/auth_session.dart` — understand all authenticated traffic.
10. `lib/features/deliveries/domain/courier_order.dart` — learn the business
    model and status rules.
11. `lib/features/deliveries/data/courier_orders_api.dart` — see the thin API
    boundary.
12. `lib/features/deliveries/presentation/views/courier_shell_view.dart` — see
    state ownership and tab composition.
13. `courier_orders_view.dart` and `order_details_view.dart` — follow the main
    delivery journey.
14. Notification domain/API/controller/view — see the complete layered pattern.
15. `lib/core/notifications/courier_push_service.dart` — learn external events.
16. Tests — confirm which behaviors are intentional invariants.

## 24. Before Submitting a Change

Use this checklist:

- The change follows the existing feature/core directory ownership.
- External JSON is validated and converted into typed models.
- No screen bypasses `AuthSession` for authenticated HTTP.
- Loading, empty, error, retry, disabled, and success states are handled where
  relevant.
- Async UI code checks `mounted` after awaits.
- Timers, subscriptions, controllers, and notifiers are disposed.
- RTL, dark mode, safe areas, keyboard, and large text still work.
- Backend authorization remains authoritative.
- Order and session invariants are preserved.
- No secret, keystore, password, or environment-specific credential was added.
- `flutter analyze` passes.
- `flutter test` passes.
- Affected physical-device behavior is manually verified when it involves
  camera, phone, maps, Firebase, permissions, or process recreation.
- Release configuration passes the correct preflight command when the change
  affects deployment.

## 25. Glossary

| Term | Meaning in this repository |
|---|---|
| Access token | Short-lived bearer token used on API requests |
| Refresh token | Token used to obtain a new access/session token pair |
| Session deadline | The time after which the client must no longer use a session |
| Temporary session | Non-remembered session with an absolute deadline |
| Persistent session | Remembered session stored securely with a sliding refresh window |
| FCM | Firebase Cloud Messaging |
| Foreground message | Push received while the app is visible |
| Opened event | Push payload processed because the user tapped a notification |
| Domain model | Typed Dart representation of business data and rules |
| Controller | `ChangeNotifier` that coordinates reusable presentation state |
| In-flight Future | A currently running operation shared with duplicate callers |
| Optimistic update | Local state changed before server success; intentionally avoided for destructive notification actions here |
| Inclusive start / exclusive end | Date range rule `start <= value < end` |

---

If you remember only one principle, remember this: keep backend communication,
business rules, and visual rendering in their current layers. That separation is
what makes a mobile app with authentication, refresh races, push events, camera
process recreation, and multiple screens understandable and safe to change.
