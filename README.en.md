# Flow_er

[简体中文](README.md) | **English**

Flow_er is a Flutter app built around focus, thought capture, and reflection. Lightweight interactions help you enter a flow state and quickly capture thoughts while focusing. Backend statistics and profiling turn daily focus sessions and notes into a personal picture you can revisit over time.

## Key features

- A local-first focus and note-taking experience, with authentication integration points in place.
- Enter a flow state by tapping the screen three times or placing the phone face down.
- Swipe down while focusing to capture a thought, using either quick capture or an expanded note.
- Save notes locally first, then sync them to the backend for classification and tagging.
- Edit and delete notes, displayed through a variety of native card layouts.
- Note categories: ideas, insights, moods, events, and excerpts.
- Automatically record session duration, trigger method, and failure status when a focus session ends, then upload the record.
- Fetch focus prompts from the backend every five minutes for unobtrusive guidance.
- A reflection page showing total focus time, captured notes, flow purity, awareness index, and mental texture.
- Statistics for all time, the last 30 days, or the last 7 days.
- Invalidate cached statistics when notes or focus records change and refresh them on the next visit.

## Technology

This repository contains only the Flutter client and API contracts. Backend source is maintained separately and is not included. Never commit server credentials or signing files.

- Flutter
- Riverpod
- Drift / SQLite
- Dio
- SharedPreferences
- sensors_plus
- image_picker
- google_fonts
- flutter_staggered_grid_view

## Directory structure

```text
lib/
  core/                 Base theme, focus constants, copy utilities
  features/
    analytics/          Reflection and statistics page
    auth/               Login, verification codes, nickname setup
    home/               Early debugging page
    inspiration/        Note list, card models, and style library
    settings/           Settings and retrospective entry point
    shell/              App shell, top bar, and bottom navigation
    splash/             Splash screen
    state/              Flow-state screen and note overlay
  models/               Drift database and domain models
  providers/            Riverpod providers and controllers
  repositories/         Local data access
  services/
    analytics/          Statistics API
    api/                Dio API client
    focus/              Focus prompt API
    sensors/            Sensor-based focus state
    sync/               Note and focus-session synchronization
```

## Backend API

The client has integration points or implementations for these endpoints:

- `POST /api/v1/auth/send-code`
- `POST /api/v1/auth/verify-code`
- `POST /api/v1/auth/set-nickname`
- `GET /api/v1/auth/me`
- `POST /api/v1/auth/logout`
- `GET /api/v1/intents`
- `POST /api/v1/intents/batch`
- `PATCH /api/v1/intents/{id}`
- `DELETE /api/v1/intents/{id}`
- `POST /api/v1/focus-sessions/batch`
- `GET /api/v1/focus-sessions/stats?period=all|30d|7d`
- `GET /api/v1/focus-sessions/portrait?period=all|30d|7d`
- `POST /api/v1/focus/moment`

The API base URL is configured in:

```text
lib/services/api/api_client.dart
```

## Quick start

Install dependencies:

```sh
flutter pub get
```

Run the app:

```sh
flutter run
```

Run static analysis:

```sh
flutter analyze
```

Run tests:

```sh
flutter test
```

Regenerate Drift code after database model changes:

```sh
flutter pub run build_runner build --delete-conflicting-outputs
```

## Android release signing

The release keystore and signing passwords are stored securely outside the repository by the maintainer. Supply your own signing configuration when building.

Android release builds prefer the local `android/key.properties` file, which is ignored by Git. Build an app bundle:

```sh
flutter build appbundle --release
```

To build an APK:

```sh
flutter build apk --release
```

## Data synchronization

- Notes are written to local SQLite before backend synchronization.
- After a successful sync, the client stores the server ID and fetches backend tags.
- Completed focus sessions are saved locally before batch upload.
- Failed note and focus-session uploads remain pending locally and are retried on a later login or startup.
- Statistics come from the backend; changing notes or focus records invalidates the statistics cache.

## Remaining work

- Email-code login is integrated, and actual email delivery and receipt have been verified. The full in-app login flow still needs physical-device acceptance; switch to HTTPS before production launch. Backend source is maintained privately and separately.
- Image attachment upload and remote URL synchronization.
- Incremental note synchronization using `since / last_synced_at`.
- Synchronizing retrospective state to the backend.
- Push-token registration.
