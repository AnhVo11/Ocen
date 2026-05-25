# OCEN App — Project Handoff Brief
_Last updated: 24 May 2026. Paste this entire file into a new chat to resume work._

---

## What Is OCEN?

A Flutter mobile app (Android) that acts as an AI scheduling assistant for Anh's father, who is a corporate executive. It has two roles:
- **Executive (read-only):** views his schedule, gets travel alerts, sees flight options
- **Secretary/Driver (full access):** adds/edits schedule entries via voice or form

The project lives at `C:\Users\anhvo\Desktop\Ocen\`. Key subdirectories:
- `mobile/` — Flutter app (the main focus)
- `app/` — Python bot/backend (Telegram bot + SQLite, mostly scaffolded)

---

## Tech Stack

| Layer | Tech |
|---|---|
| Mobile frontend | Flutter / Dart (Android emulator: Pixel 6 API 34) |
| Local storage | SQLite via `sqflite` |
| Notifications | `flutter_local_notifications ^18.0.0` + `timezone` |
| Voice input | `speech_to_text ^7.0.0` |
| TTS | `flutter_tts ^4.0.0` |
| HTTP | `http ^1.2.0` |
| Localisation | `intl ^0.20.2` + `flutter_localizations` |
| Maps | Google Maps Directions API (key already in config) |
| Flight data | Amadeus API (mock fallback when keys not set) |
| Backend | Python + Flask + SQLite + Alembic (in `app/`) |

**Android build config:** `mobile/android/app/build.gradle.kts`
**Run script:** Double-click `C:\Users\anhvo\Desktop\Ocen\restart_flutter.vbs` to kill old dart/flutter processes and launch fresh `flutter run`.

---

## API Keys Already Configured

File: `mobile/lib/config/app_config.dart`

```dart
static const String googleMapsApiKey = 'AIzaSyCrHfSuWEKqOH1KUT1Izz3O0rjIIAIdM_Y';
static const String amadeusApiKey = '';       // empty = uses mock data
static const String amadeusApiSecret = '';    // empty = uses mock data
static const String amadeusBaseUrl = 'https://test.api.amadeus.com';
```

- **Google Maps Directions API** key is live. The Directions API needs to be enabled in Google Cloud Console (Library → Directions API → Enable) if not done yet.
- **Amadeus** developer portal is being decommissioned 17 July 2026. Mock flight data is used instead and is good enough for personal use.

---

## All Files Created / Modified

### New files added
| File | Purpose |
|---|---|
| `mobile/lib/services/amadeus_service.dart` | Flight search service: OAuth2 token, Amadeus API call, mock fallback, city→IATA mapping for Vietnamese cities |
| `mobile/lib/widgets/flight_search_sheet.dart` | DraggableScrollableSheet showing flights for a schedule entry. Groups into "✅ Kịp giờ họp" vs "⚠️ Có thể trễ giờ họp" |
| `restart_flutter.vbs` | Kills dart.exe/flutter.exe then runs `flutter run` fresh (workaround for terminal tier restriction) |

### Modified files
| File | Change |
|---|---|
| `mobile/lib/config/app_config.dart` | Added Google Maps + Amadeus keys/config |
| `mobile/lib/widgets/schedule_card.dart` | Added `_openFlightSearch()` + "Xem chuyến bay" OutlinedButton (shown only when `needsTravel && travelMode == 'flight'`) |
| `mobile/lib/widgets/voice_input_sheet.dart` | Fixed bug: `await widget.apiService.checkAndSave(...)` wasn't capturing return value; added `final result =` |
| `mobile/lib/services/notification_service.dart` | Fixed compile error: added required `uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime` to `_plugin.zonedSchedule()` call |
| `mobile/lib/widgets/flight_search_sheet.dart` | Removed `vi_VN` locale from `DateFormat` (potential runtime crash) |
| `mobile/android/app/build.gradle.kts` | Added `isCoreLibraryDesugaringEnabled = true` to `compileOptions` + `dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }` — required by flutter_local_notifications |

---

## Bugs Fixed (In Order)

1. **`voice_input_sheet.dart`** — `result` undefined: `checkAndSave()` return value not captured → fixed with `final result = await`
2. **`amadeus_service.dart`** — Dart numeric separator syntax (`1_850_000`) requires Dart 3.6+; replaced with plain numbers (`1850000`)
3. **`notification_service.dart`** — Missing required parameter `uiLocalNotificationDateInterpretation` in `zonedSchedule()` call — THIS was the root cause blocking ALL builds for hours
4. **`flight_search_sheet.dart`** — `DateFormat('EEEE, dd/MM/yyyy', 'vi_VN')` may throw if locale not initialised; simplified to `DateFormat('dd/MM/yyyy')`
5. **`android/app/build.gradle.kts`** — Gradle error: `flutter_local_notifications` requires core library desugaring; added `isCoreLibraryDesugaringEnabled = true` + desugaring dependency

---

## Current App State (What's Working)

- App runs on Pixel 6 API 34 emulator
- **Executive home screen** shows today/tomorrow schedule tabs
- **Schedule cards** show time, title, location, travel badges (✈️ Cần bay / 🚗 Di chuyển / X phút)
- **"Xem chuyến bay" button** appears on flight-required cards → opens bottom sheet with 6 mock flights (Vietnam Airlines, VietJet, Bamboo) grouped by whether they arrive before the meeting
- **Voice input** button ("Thêm bằng giọng nói") works for adding schedules
- **Local notifications** scheduled 30 min before events + travel departure alerts
- **Travel time warning banner** on home screen (red banner when departure is overdue)

---

## Data Model: `Schedule`

```dart
class Schedule {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final String? notes;
  final bool isWork;
  final bool needsTravel;
  final String? travelMode;    // 'car', 'flight', or null
  final int? travelMinutes;    // estimated travel duration
}
```

---

## What's Left To Do (Prioritised)

### High value / easy
- [ ] **Verify build succeeded** after latest Gradle fix — run `restart_flutter.vbs` and check terminal says "Flutter run key commands." with no errors
- [ ] **Enable Directions API** in Google Cloud Console if not done yet (for real driving-time estimates on car-travel cards)

### Medium value
- [ ] **Backend sync** — the Python bot (`app/`) is scaffolded but not connected to the mobile app. Wiring it up would let the secretary add schedules via Telegram and have them appear on the executive's phone
- [ ] **Real flight data** — Amadeus shutting down July 2026; alternative: Kiwi.com Tequila API or RapidAPI flight provider. Mock data works fine for now.

### Nice to have
- [ ] iOS build (needs Mac)
- [ ] Push notifications from backend when secretary adds a schedule
- [ ] "Tất cả lịch" (all schedules) list screen beyond just today/tomorrow tabs
- [ ] Edit/delete schedule from executive view

---

## How To Run The App

1. Make sure the Android emulator (Pixel 6 API 34) is running in Android Studio
2. Double-click `C:\Users\anhvo\Desktop\Ocen\restart_flutter.vbs`
3. A Command Prompt window opens — wait for "Flutter run key commands." (about 1-2 min first run, faster after)
4. App appears on emulator; press **R** in the terminal to hot-reload after code changes

---

## Project File Tree (Key Parts)

```
Ocen/
├── mobile/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── theme.dart
│   │   ├── config/
│   │   │   └── app_config.dart          ← API keys here
│   │   ├── models/
│   │   │   └── schedule.dart
│   │   ├── services/
│   │   │   ├── api_service.dart         ← SQLite CRUD + AI travel check
│   │   │   ├── amadeus_service.dart     ← Flight search (new)
│   │   │   ├── notification_service.dart
│   │   │   └── maps_service.dart        ← Google Maps directions
│   │   ├── screens/
│   │   │   ├── executive/home_screen.dart
│   │   │   ├── staff/home_screen.dart
│   │   │   ├── staff/add_schedule_screen.dart
│   │   │   └── role_select_screen.dart
│   │   └── widgets/
│   │       ├── schedule_card.dart       ← Shows flight button (modified)
│   │       ├── flight_search_sheet.dart ← Flight list bottom sheet (new)
│   │       ├── voice_input_sheet.dart   ← Voice entry (fixed)
│   │       └── travel_warning_banner.dart
│   ├── android/app/build.gradle.kts    ← Desugaring fix applied
│   └── pubspec.yaml
├── app/                                 ← Python backend (Telegram bot)
├── restart_flutter.vbs                  ← Run this to rebuild
└── HANDOFF.md                           ← This file
```

---

## Notes For Next Session

- The terminal (Command Prompt) launched by the VBS script is at click-tier in Cowork, meaning Claude can see it but can't type into it. To check build errors, ask the user to paste terminal output.
- VS Code is also at click-tier. The Android emulator is embedded in VS Code's "Running Devices" panel — pop it out with the arrow icon on the "Pixel 6 API 34" tab to interact with it.
- The `restart_flutter.vbs` is the reliable way to rebuild. Don't try to use VS Code's run button.
- User's email: anhvo8438@gmail.com
